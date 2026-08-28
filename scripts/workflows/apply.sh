#!/usr/bin/env bash
# scripts/workflows/apply.sh
#
# Diff application workflow: apply a diff file to the project working tree.
# Sourced by agent-sandbox.sh  --  not executed standalone.
#
# Depends on: AGENT_SANDBOX_REPO, src/libs/diff.sh, git, standard shell utilities.

set -euo pipefail

# Derive repo root from own path when exec'd (main() below uses this).
# When sourced (by agent-sandbox.sh), AGENT_SANDBOX_REPO is already set.
_apply_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SANDBOX_REPO="${AGENT_SANDBOX_REPO:-$(cd "$_apply_self/../.." && pwd)}"

source "$AGENT_SANDBOX_REPO/scripts/guards.sh"
source "$AGENT_SANDBOX_REPO/src/libs/session_state.sh"
source "$AGENT_SANDBOX_REPO/src/libs/diff.sh"

# =============================================================================
# apply_run  --  apply a diff file
# =============================================================================

# apply_run PROJECT_DIR DIFF_FILE APPLY_BRANCH FORCE
#
# Applies a diff file to the project working tree. Does not create commits  -- 
# leaves changes unstaged for operator review.
#
# Args:
#   PROJECT_DIR    --  absolute path to the target git repository
#   DIFF_FILE      --  absolute path to a diff file (uncommitted.diff or similar)
#   APPLY_BRANCH   --  optional branch to checkout/create before applying
#   FORCE          --  if true, apply with --reject; .rej files for conflicts
#                   to handle minor hunk-context drift (line reorders,
#                   whitespace shifts that don't affect the content delta)
#
# No internal path resolution  --  the caller (router in agent-sandbox.sh or
# explicit --diff=<path>) supplies the file path directly.
apply_run() {
  local PROJECT_DIR="$1"
  local DIFF_FILE="$2"
  local APPLY_BRANCH="${3:-}"
  local FORCE="${4:-false}"

  if [[ -z "$PROJECT_DIR" || -z "$DIFF_FILE" ]]; then
    echo "apply_run: PROJECT_DIR and DIFF_FILE are required" >&2
    return 1
  fi

  if [[ ! -f "$DIFF_FILE" ]]; then
    echo "Error: diff file not found: $DIFF_FILE" >&2
    return 1
  fi

  validate_project_dir "$PROJECT_DIR" || return 1
  draft_clear_stale_lock "$PROJECT_DIR" || return 1

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

  echo "Applying $(basename "$DIFF_FILE") to $(git -C "$PROJECT_DIR" branch --show-current)..."

  if [[ "$FORCE" == true ]]; then
    echo "Force mode enabled: applying with --reject; .rej files will be created for conflicts."
  fi

  # Empty diff: skip the patch step; the count below reports 0 and the
  # normal tail output follows.
  if diff_is_empty "$DIFF_FILE"; then
    echo "Warning: $(basename "$DIFF_FILE") is empty; nothing to apply." >&2
  else
    _apply_patch_file "$PROJECT_DIR" "$DIFF_FILE" "$FORCE" || return 1
  fi

  # Count changed files from the diff. grep -c self-reports zero on stdout
  # while exiting 1; `|| echo 0` here would double-emit ("0\n0").
  local FILES_CHANGED
  FILES_CHANGED=$(grep -c "^diff --git" "$DIFF_FILE" || true)
  FILES_CHANGED=${FILES_CHANGED:-0}

  echo ""
  echo "Done. Files changed: $FILES_CHANGED"
  if [[ "$FORCE" == true ]]; then
    echo "Force mode: check for .rej files and resolve any failed hunks."
  else
    echo "Review changes and commit manually."
  fi
  echo "Diff source: $DIFF_FILE"
}

# =============================================================================
# usage  --  print help text
# =============================================================================

usage() {
  cat <<EOF
Usage: agent-sandbox apply --project=<path> --sandbox=<path> --diff=<path> [options]

Applies a diff file to the project working tree. Does not commit.

Required:
  --project=<path>    Path to the git repository
  --sandbox=<path>    Path to the sandbox directory
  --diff=<path>       Path to the exact diff file to apply

Options:
  --branch=<name>     Check out or create a branch before applying
  --force             Apply with --reject for conflicts
  --permissive        Retry with --recount on failure
  --interactive       Preview the changes, then ask for confirmation
EOF
}

# =============================================================================
# apply_preview  --  print a git-oneline-style summary of an external diff file
# =============================================================================

# apply_preview DIFF_FILE
#
# Prints each file the diff touches (from 'diff --git' headers), then the
# total file count. The diff is external to the working tree, so the summary
# is read from the file rather than from git.
apply_preview() {
  local DIFF_FILE="$1"
  local has_changes=false
  local file
  while IFS= read -r line; do
    if [[ "$line" == diff\ --git* ]]; then
      has_changes=true
      file=${line#diff --git }
      file=${file#a/}
      file=${file%% *}
      printf '%s\n' "$file"
    fi
  done < "$DIFF_FILE"
  if [[ "$has_changes" == false ]]; then
    echo "No changes found in $DIFF_FILE"
    return 0
  fi
  printf 'Total files: %s\n' "$(grep -c '^diff --git' "$DIFF_FILE" || true)"
}

# =============================================================================
# main  --  entry point when exec'd by agent-sandbox apply
# =============================================================================

# Parses flags forwarded from agent-sandbox.sh dispatch and calls apply_run.
# Expected flags: --project=<dir> --sandbox=<dir> --diff=<path> [--branch=<n>] [--force] [--permissive] [--interactive]
main() {
  for ARG in "$@"; do
    case "$ARG" in
      --help|-h) usage; exit 0 ;;
    esac
  done

  local PROJECT_DIR=""
  local SANDBOX_DIR=""
  local DIFF_FILE=""
  local APPLY_BRANCH=""
  local FORCE=false
  local INTERACTIVE=false

  for ARG in "$@"; do
    case "$ARG" in
      --project=*)     PROJECT_DIR="${ARG#--project=}" ;;
      --sandbox=*)     SANDBOX_DIR="${ARG#--sandbox=}" ;;
      --diff=*)        DIFF_FILE="${ARG#--diff=}" ;;
      --branch=*)      APPLY_BRANCH="${ARG#--branch=}" ;;
      --force)         FORCE=true ;;
      --permissive)    true ;;  # no-op, kept for compatibility
      --interactive)   INTERACTIVE=true ;;
      *)
        echo "Unknown argument: $ARG" >&2
        usage >&2
        exit 1
        ;;
    esac
  done

  if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
    usage >&2
    exit 1
  fi

  if [[ -z "$DIFF_FILE" ]]; then
    echo "Error: --diff=<path> is required. apply applies an exact diff file; pass --diff=<full path>." >&2
    usage >&2
    exit 1
  fi

  # Interactive mode: preview the changes, then ask for confirmation
  if [[ "$INTERACTIVE" == true ]]; then
    source "$AGENT_SANDBOX_REPO/scripts/workflows/interactive.sh"
    echo "Preview of $(basename "$DIFF_FILE"):" >&2
    apply_preview "$DIFF_FILE" >&2
    interactive_confirm_or_abort "Apply:" "$DIFF_FILE" || exit 1
    echo "Running: make apply DIFF=${DIFF_FILE}"
    apply_run "$PROJECT_DIR" "$DIFF_FILE" "$APPLY_BRANCH" "$FORCE"
    exit $?
  fi

  apply_run "$PROJECT_DIR" "$DIFF_FILE" "$APPLY_BRANCH" "$FORCE"
}

# Guard: only run main() when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
