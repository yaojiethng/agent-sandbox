#!/usr/bin/env bash
# libs/diff_workflow.sh
#
# Diff application workflow: apply a diff file to the project working tree.
# Sourced by agent-sandbox.sh — not executed standalone.
#
# Depends on: AGENT_SANDBOX_REPO, git, standard shell utilities.

set -euo pipefail

# Derive repo root from own path when exec'd (main() below uses this).
# When sourced (by agent-sandbox.sh), AGENT_SANDBOX_REPO is already set.
_apply_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SANDBOX_REPO="${AGENT_SANDBOX_REPO:-$(cd "$_apply_self/../.." && pwd)}"

source "$AGENT_SANDBOX_REPO/scripts/guards.sh"
source "$AGENT_SANDBOX_REPO/src/libs/session_state.sh"
source "$AGENT_SANDBOX_REPO/src/libs/diff.sh"

# =============================================================================
# apply_run — apply a diff file
# =============================================================================

# apply_run PROJECT_DIR DIFF_FILE APPLY_BRANCH FORCE PERMISSIVE
#
# Applies a diff file to the project working tree. Does not create commits —
# leaves changes unstaged for operator review.
#
# Args:
#   PROJECT_DIR   — absolute path to the target git repository
#   DIFF_FILE     — absolute path to a diff file (uncommitted.diff or similar)
#   APPLY_BRANCH  — optional branch to checkout/create before applying
#   FORCE         — if true, apply with --reject; .rej files for conflicts
#   PERMISSIVE    — if true, on git apply failure retry with --recount
#                   to handle minor hunk-context drift (line reorders,
#                   whitespace shifts that don't affect the content delta)
#
# No internal path resolution — the caller (router in agent-sandbox.sh or
# explicit --diff=<path>) supplies the file path directly.
apply_run() {
  local PROJECT_DIR="$1"
  local DIFF_FILE="$2"
  local APPLY_BRANCH="${3:-}"
  local FORCE="${4:-false}"
  local PERMISSIVE="${5:-false}"

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
    if ! git -C "$PROJECT_DIR" apply --reject < <(strip_index_lines < "$DIFF_FILE"); then
      echo "" >&2
      echo "Warning: some hunks failed to apply." >&2
      echo "Review .rej files and resolve manually." >&2
    fi
  elif [[ "$PERMISSIVE" == true ]]; then
    # Permissive mode: try normal apply first, then retry with --recount
    # on failure. --recount relaxes hunk-context matching so minor context
    # shifts (line reorders, whitespace changes) don't cause rejection.
    if ! git -C "$PROJECT_DIR" apply --ignore-whitespace < <(strip_index_lines < "$DIFF_FILE"); then
      # Check if --recount might help
      if git -C "$PROJECT_DIR" apply --check --recount --ignore-whitespace < <(strip_index_lines < "$DIFF_FILE") 2>/dev/null; then
        echo "Normal apply failed; retrying with --recount (relaxed context matching)..." >&2
        git -C "$PROJECT_DIR" apply --recount --ignore-whitespace < <(strip_index_lines < "$DIFF_FILE")
      else
        echo "Error: git apply failed even with --recount." >&2
        echo "  Diff file: $DIFF_FILE" >&2
        echo "  Target branch: $(git -C "$PROJECT_DIR" branch --show-current)" >&2
        echo "" >&2
        echo "Hint: use --force to apply with --reject and create .rej files for conflicts." >&2
        return 1
      fi
    fi
  else
    if ! git -C "$PROJECT_DIR" apply --ignore-whitespace < <(strip_index_lines < "$DIFF_FILE"); then
      echo "Error: git apply failed." >&2
      echo "  Diff file: $DIFF_FILE" >&2
      echo "  Target branch: $(git -C "$PROJECT_DIR" branch --show-current)" >&2
      echo "" >&2
      echo "Hints:" >&2
      echo "  Use --force to apply with --reject (.rej files for conflicts)." >&2
      echo "  Use --permissive to retry with --recount (relaxed context matching)." >&2
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
  echo "Diff source: $DIFF_FILE"
}

# =============================================================================
# main — entry point when exec'd by agent-sandbox apply
# =============================================================================

# Parses flags forwarded from agent-sandbox.sh dispatch and calls apply_run.
# Expected flags: --project=<dir> --sandbox=<dir> [--diff=<path>] [--branch=<n>] [--force] [--permissive]
main() {
  local PROJECT_DIR=""
  local SANDBOX_DIR=""
  local DIFF_FILE=""
  local APPLY_BRANCH=""
  local FORCE=false
  local PERMISSIVE=false
  local CHANNEL=""
  local SESSION=""

  for ARG in "$@"; do
    case "$ARG" in
      --project=*)     PROJECT_DIR="${ARG#--project=}" ;;
      --sandbox=*)     SANDBOX_DIR="${ARG#--sandbox=}" ;;
      --diff=*)        DIFF_FILE="${ARG#--diff=}" ;;
      --branch=*)      APPLY_BRANCH="${ARG#--branch=}" ;;
      --force)         FORCE=true ;;
      --permissive)    PERMISSIVE=true ;;
      --channel=*)     CHANNEL="${ARG#--channel=}" ;;
      --session=*)     SESSION="${ARG#--session=}" ;;
      *)
        echo "Error: unknown flag: $ARG" >&2
        exit 1
        ;;
    esac
  done

  if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
    echo "Error: --project and --sandbox are required" >&2
    exit 1
  fi

  if [[ -n "$DIFF_FILE" ]]; then
    apply_run "$PROJECT_DIR" "$DIFF_FILE" "$APPLY_BRANCH" "$FORCE" "$PERMISSIVE"
  else
    source "$AGENT_SANDBOX_REPO/src/libs/routing.sh"
    local CHANNEL="${CHANNEL:-diffs}"
    local RESOLVED
    RESOLVED=$(resolve_diff_for_apply "$SANDBOX_DIR" "$CHANNEL" "$SESSION") || exit 1
    apply_run "$PROJECT_DIR" "$RESOLVED" "$APPLY_BRANCH" "$FORCE" "$PERMISSIVE"
  fi
}

# Guard: only run main() when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
