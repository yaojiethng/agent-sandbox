#!/usr/bin/env bash
# libs/diff_workflow.sh
#
# Diff application workflow: apply a diff file to the project working tree.
# Sourced by agent-sandbox.sh — not executed standalone.
#
# Depends on: libs/session.sh, git, standard shell utilities.

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/session.sh"

# apply_run PROJECT_DIR DIFF_FILE APPLY_BRANCH FORCE
#   Applies a single diff file to the project working tree.
#   Does not create commits — leaves changes unstaged for operator review.
#   The caller is responsible for resolving the diff file path.
apply_run() {
  local PROJECT_DIR="$1"
  local DIFF_FILE="$2"
  local APPLY_BRANCH="$3"
  local FORCE="$4"

  validate_project_dir "$PROJECT_DIR" || return 1

  if [[ -z "$DIFF_FILE" ]]; then
    echo "Error: no diff file specified" >&2
    return 1
  fi

  if [[ ! -f "$DIFF_FILE" ]]; then
    echo "Error: diff file not found: $DIFF_FILE" >&2
    return 1
  fi

  local SESSION_DIR
  SESSION_DIR=$(dirname "$DIFF_FILE")

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

  echo "Applying $DIFF_FILE to $(git -C "$PROJECT_DIR" branch --show-current)..."

  if [[ "$FORCE" == true ]]; then
    echo "Force mode enabled: applying with --reject; .rej files will be created for conflicts."
    if ! git -C "$PROJECT_DIR" apply --reject < <(grep -v '^index ' "$DIFF_FILE"); then
      echo "" >&2
      echo "Warning: some hunks failed to apply." >&2
      echo "Review .rej files and resolve manually." >&2
    fi
  else
    if ! git -C "$PROJECT_DIR" apply < <(grep -v '^index ' "$DIFF_FILE"); then
      echo "Error: git apply failed." >&2
      echo "  Diff file: $DIFF_FILE" >&2
      echo "  Target branch: $(git -C "$PROJECT_DIR" branch --show-current)" >&2
      echo "" >&2
      echo "Hint: use --force to apply with --reject and create .rej files for conflicts." >&2
      return 1
    fi
  fi

  # Count changed files from the diff
  local FILES_CHANGED
  FILES_CHANGED=$(grep -c "^diff --git" "$DIFF_FILE" || echo "0")

  echo ""
  echo "Done. Files changed: $FILES_CHANGED"
  if [[ "$FORCE" == true ]]; then
    echo "Force mode: check for .rej files and resolve any failed hunks."
  else
    echo "Review changes and commit manually."
  fi
  echo "Session artefacts retained at: $SESSION_DIR"
}
