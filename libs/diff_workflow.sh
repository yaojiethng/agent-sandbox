#!/usr/bin/env bash
# libs/diff_workflow.sh
#
# Diff application workflow: apply changes.diff to project working tree.
# Sourced by agent-sandbox.sh — not executed standalone.
#
# Depends on: libs/session.sh, git, standard shell utilities.

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/session.sh"

# apply_run PROJECT_DIR SANDBOX_DIR SESSION_ARG DIFF_ARG APPLY_BRANCH FORCE
#   Applies changes.diff (or a specific diff file) to the project working tree.
#   Does not create commits — leaves changes unstaged for operator review.
apply_run() {
  local PROJECT_DIR="$1"
  local SANDBOX_DIR="$2"
  local SESSION_ARG="$3"
  local DIFF_ARG="$4"
  local APPLY_BRANCH="$5"
  local FORCE="$6"

  validate_project_dir "$PROJECT_DIR" || return 1

  local CHANGES_DIFF=""
  local SESSION_DIR=""

  if [[ -n "$DIFF_ARG" ]]; then
    # Explicit diff path provided — no session resolution needed
    CHANGES_DIFF="$DIFF_ARG"
    if [[ ! -f "$CHANGES_DIFF" ]]; then
      echo "Error: diff file not found: $CHANGES_DIFF" >&2
      return 1
    fi
    SESSION_DIR=$(dirname "$CHANGES_DIFF")
  else
    # Resolve session directory from OUTPUT_DIR/diffs/
    local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
    local OUTPUT_DIR="$WORKSPACE_DIR/output"
    local DIFFS_DIR="$OUTPUT_DIR/diffs"

    if [[ -n "$SESSION_ARG" ]]; then
      # Explicit session path — absolute used as-is; relative resolved under $DIFFS_DIR
      if [[ "$SESSION_ARG" == /* ]]; then
        SESSION_DIR="$SESSION_ARG"
        # Absolute paths do not require $DIFFS_DIR to exist
      else
        # Relative path — must have $DIFFS_DIR
        if [[ ! -d "$DIFFS_DIR" ]]; then
          echo "Error: diffs directory not found: $DIFFS_DIR" >&2
          echo "  No session artefacts have been produced yet." >&2
          return 1
        fi
        SESSION_DIR="$DIFFS_DIR/$SESSION_ARG"
      fi
      if [[ ! -d "$SESSION_DIR" ]]; then
        echo "Error: session directory not found: $SESSION_DIR" >&2
        if [[ "$SESSION_ARG" != /* ]]; then
          echo "  Relative paths resolve under: $DIFFS_DIR" >&2
        fi
        echo "  Specify a valid session name or use an absolute path." >&2
        return 1
      fi
    else
      # Auto-resolve: lexicographically last entry in DIFFS_DIR
      if [[ ! -d "$DIFFS_DIR" ]]; then
        echo "Error: diffs directory not found: $DIFFS_DIR" >&2
        echo "  Expected: $DIFFS_DIR/<session>/changes.diff" >&2
        echo "  No session artefacts have been produced yet." >&2
        return 1
      fi

      SESSION_DIR=$(find "$DIFFS_DIR" -mindepth 1 -maxdepth 1 -type d \
        | sort | tail -n 1)
      if [[ -z "$SESSION_DIR" ]]; then
        echo "Error: no session directories found in $DIFFS_DIR" >&2
        echo "  Run a session first, or specify SESSION=<name>." >&2
        return 1
      fi
    fi

    # Resolve changes.diff: try flat, then session/, then autosave/
    if [[ -f "$SESSION_DIR/changes.diff" ]]; then
      CHANGES_DIFF="$SESSION_DIR/changes.diff"
    elif [[ -f "$SESSION_DIR/session/changes.diff" ]]; then
      CHANGES_DIFF="$SESSION_DIR/session/changes.diff"
    elif [[ -f "$SESSION_DIR/autosave/changes.diff" ]]; then
      CHANGES_DIFF="$SESSION_DIR/autosave/changes.diff"
    else
      echo "Error: changes.diff not found in session directory: $SESSION_DIR" >&2
      echo "  Tried: $SESSION_DIR/changes.diff" >&2
      echo "        $SESSION_DIR/session/changes.diff" >&2
      echo "        $SESSION_DIR/autosave/changes.diff" >&2
      echo "  Session artefacts may be incomplete or from a different version." >&2
      return 1
    fi
  fi

  # Print migration guide path if present
  local MIGRATION_GUIDE="$SESSION_DIR/migration-guide.md"
  if [[ -f "$MIGRATION_GUIDE" ]]; then
    echo "Migration guide available: $MIGRATION_GUIDE"
    echo "  Review before proceeding."
    echo ""
  fi

  # Optionally check out branch
  if [[ -n "$APPLY_BRANCH" ]]; then
    if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$APPLY_BRANCH"; then
      echo "Checking out existing branch: $APPLY_BRANCH"
      git -C "$PROJECT_DIR" checkout "$APPLY_BRANCH"
    else
      echo "Creating and checking out new branch: $APPLY_BRANCH"
      git -C "$PROJECT_DIR" checkout -b "$APPLY_BRANCH"
    fi
  fi

  echo "Applying $CHANGES_DIFF to $(git -C "$PROJECT_DIR" branch --show-current)..."

  if [[ "$FORCE" == true ]]; then
    echo "Force mode enabled: applying with --reject; .rej files will be created for conflicts."
    if ! git -C "$PROJECT_DIR" apply --reject < <(grep -v '^index ' "$CHANGES_DIFF"); then
      echo "" >&2
      echo "Warning: some hunks failed to apply." >&2
      echo "Review .rej files and resolve manually." >&2
    fi
  else
    if ! git -C "$PROJECT_DIR" apply < <(grep -v '^index ' "$CHANGES_DIFF"); then
      echo "Error: git apply failed." >&2
      echo "  Diff file: $CHANGES_DIFF" >&2
      echo "  Target branch: $(git -C "$PROJECT_DIR" branch --show-current)" >&2
      echo "" >&2
      echo "Hint: use --force to apply with --reject and create .rej files for conflicts." >&2
      return 1
    fi
  fi

  # Count changed files from the diff
  local FILES_CHANGED
  FILES_CHANGED=$(grep -c "^diff --git" "$CHANGES_DIFF" || echo "0")

  echo ""
  echo "Done. Files changed: $FILES_CHANGED"
  if [[ "$FORCE" == true ]]; then
    echo "Force mode: check for .rej files and resolve any failed hunks."
  else
    echo "Review changes and commit manually."
  fi
  echo "Session artefacts retained at: $SESSION_DIR"
}
