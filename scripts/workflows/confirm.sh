#!/usr/bin/env bash
# scripts/workflows/confirm.sh
# Confirm workflow: rebase draft branch onto target, fast-forward merge, delete draft.
# Sourced by agent-sandbox.sh — not executed standalone.
# Sources draft_state.sh for draft-state helpers and guards.sh for git guard functions.

set -euo pipefail

# Derive repo root from own path when exec'd.
_confirm_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SANDBOX_REPO="${AGENT_SANDBOX_REPO:-$(cd "$_confirm_self/../.." && pwd)}"

source "$AGENT_SANDBOX_REPO/src/libs/draft_state.sh"
source "$AGENT_SANDBOX_REPO/scripts/guards.sh"

# =============================================================================
# confirm_run — rebase, fast-forward merge, delete draft branch
# =============================================================================

confirm_run() {
  local PROJECT_DIR="$1"
  local SANDBOX_DIR="$2"
  local TARGET_BRANCH="$3"

  validate_project_dir "$PROJECT_DIR" || return 1
  draft_clear_stale_lock "$PROJECT_DIR" || return 1

  # Validate draft branch and read .draft-state into local scope
  local DRAFT_VALIDATION
  DRAFT_VALIDATION=$(draft_validate_branch "$PROJECT_DIR") || return 1
  eval "$DRAFT_VALIDATION"

  local MERGE_TARGET="${TARGET_BRANCH:-$source_branch}"

  if ! git -C "$PROJECT_DIR" rev-parse --verify "$MERGE_TARGET" >/dev/null 2>&1; then
    echo "Error: target branch does not exist: $MERGE_TARGET" >&2
    echo "  Specify a different target: make confirm TARGET=<branch>" >&2
    return 1
  fi

  # 1. Drop .draft-state commit (if found)
  if [[ -n "${DRAFT_STATE_COMMIT:-}" ]]; then
    echo "Dropping .draft-state commit..."
    if ! git -C "$PROJECT_DIR" rebase --onto "${DRAFT_STATE_COMMIT}^" "$DRAFT_STATE_COMMIT" "$CURRENT_BRANCH"; then
      echo "Error: failed to drop .draft-state commit" >&2
      return 1
    fi
  else
    echo ".draft-state commit not found — skipping drop step."
  fi

  # 2. Rebase draft onto target
  echo "Rebasing $CURRENT_BRANCH onto $MERGE_TARGET..."
  if ! git -C "$PROJECT_DIR" rebase "$MERGE_TARGET" "$CURRENT_BRANCH"; then
    echo ""
    echo "Conflict rebasing $CURRENT_BRANCH onto $MERGE_TARGET."
    echo "Resolve conflicts, then run 'git rebase --continue', then 'make confirm'."
    echo "To discard: 'git rebase --abort && make reject'."
    return 1
  fi

  # 3. Fast-forward merge
  echo "Fast-forward merging $CURRENT_BRANCH into $MERGE_TARGET..."
  git -C "$PROJECT_DIR" switch "$MERGE_TARGET"
  git -C "$PROJECT_DIR" merge --ff-only "$CURRENT_BRANCH"

  # 4. Delete draft branch
  echo "Deleting draft branch: $CURRENT_BRANCH"
  git -C "$PROJECT_DIR" branch -D "$CURRENT_BRANCH"

  echo ""
  echo "Done. Changes merged into $MERGE_TARGET."
}

# =============================================================================
# main — entry point when exec'd by agent-sandbox confirm
# =============================================================================

# Parses flags forwarded from agent-sandbox.sh dispatch and calls confirm_run.
# Expected flags: --project=<dir> --sandbox=<dir> [--target=<branch>]
main() {
  local PROJECT_DIR=""
  local SANDBOX_DIR=""
  local TARGET_BRANCH=""

  for ARG in "$@"; do
    case "$ARG" in
      --project=*) PROJECT_DIR="${ARG#--project=}" ;;
      --sandbox=*) SANDBOX_DIR="${ARG#--sandbox=}" ;;
      --target=*)  TARGET_BRANCH="${ARG#--target=}" ;;
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

  confirm_run "$PROJECT_DIR" "$SANDBOX_DIR" "$TARGET_BRANCH"
}

# Guard: only run main() when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
