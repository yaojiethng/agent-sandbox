#!/usr/bin/env bash
# scripts/workflows/reject.sh
# Reject workflow: checkout source branch, delete draft branch.
# Sourced by agent-sandbox.sh — not executed standalone.
# Sources draft_state.sh for draft-state helpers and guards.sh for git guard functions.

set -euo pipefail

# Derive repo root from own path when exec'd.
_reject_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SANDBOX_REPO="${AGENT_SANDBOX_REPO:-$(cd "$_reject_self/../.." && pwd)}"

source "$AGENT_SANDBOX_REPO/src/libs/draft_state.sh"
source "$AGENT_SANDBOX_REPO/scripts/guards.sh"

# =============================================================================
# reject_run — checkout source branch, delete draft branch
# =============================================================================

reject_run() {
  local PROJECT_DIR="$1"
  local SANDBOX_DIR="$2"

  validate_project_dir "$PROJECT_DIR" || return 1
  draft_clear_stale_lock "$PROJECT_DIR" || return 1

  # Validate draft branch and read .draft-state into local scope
  local DRAFT_VALIDATION
  DRAFT_VALIDATION=$(draft_validate_branch "$PROJECT_DIR") || return 1
  eval "$DRAFT_VALIDATION"

  echo "Rejecting draft. Returning to $source_branch..."
  git -C "$PROJECT_DIR" checkout "$source_branch"

  if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$CURRENT_BRANCH" 2>/dev/null; then
    git -C "$PROJECT_DIR" branch -D "$CURRENT_BRANCH"
    echo "Deleted draft branch: $CURRENT_BRANCH"
  fi

  echo "Draft rejected. PROJECT_DIR restored to $source_branch."
}

# =============================================================================
# main — entry point when exec'd by agent-sandbox reject
# =============================================================================

# Parses flags forwarded from agent-sandbox.sh dispatch and calls reject_run.
# Expected flags: --project=<dir> --sandbox=<dir>
main() {
  local PROJECT_DIR=""
  local SANDBOX_DIR=""

  for ARG in "$@"; do
    case "$ARG" in
      --project=*) PROJECT_DIR="${ARG#--project=}" ;;
      --sandbox=*) SANDBOX_DIR="${ARG#--sandbox=}" ;;
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

  reject_run "$PROJECT_DIR" "$SANDBOX_DIR"
}

# Guard: only run main() when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
