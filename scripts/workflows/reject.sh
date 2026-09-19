#!/usr/bin/env bash
# scripts/workflows/reject.sh
# Reject workflow: checkout source branch, delete draft branch.
# Exec'd directly by agent-sandbox.sh (dispatch); main() runs only when not
# sourced, so test suites may source this file for its functions.
# Sources draft_state.sh for draft-state helpers and guards.sh for git guard functions.

set -euo pipefail

# Derive repo root from own path when exec'd.
_reject_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SANDBOX_REPO="${AGENT_SANDBOX_REPO:-$(cd "$_reject_self/../.." && pwd)}"

source "$AGENT_SANDBOX_REPO/src/libs/draft_state.sh"
source "$AGENT_SANDBOX_REPO/src/libs/cli.sh"
source "$AGENT_SANDBOX_REPO/scripts/guards.sh"

# =============================================================================
# reject_run  --  checkout source branch, delete draft branch
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
  if ! git -C "$PROJECT_DIR" checkout "$source_branch" 2>/dev/null; then
    # Draft residue (e.g. uncommitted.diff applied to the working tree) blocks
    # the checkout. Reject discards the draft entirely, so discard the residue
    # too -- the final working-tree changes carry no information once the draft
    # commits are dropped.
    echo "Warning: discarding uncommitted draft changes to return to $source_branch..." >&2
    git -C "$PROJECT_DIR" checkout -f "$source_branch"
    git -C "$PROJECT_DIR" clean -fd
  fi

  if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$CURRENT_BRANCH" 2>/dev/null; then
    git -C "$PROJECT_DIR" branch -D "$CURRENT_BRANCH"
    echo "Deleted draft branch: $CURRENT_BRANCH"
  fi

  echo "Draft rejected. PROJECT_DIR restored to $source_branch."
}

# =============================================================================
# usage  --  print help text
# =============================================================================

usage() {
  cat <<EOF
Usage: agent-sandbox reject --project=<path> --sandbox=<path>

Discards the current draft branch and returns to the source branch.

Required:
  --project=<path>    Path to the git repository
  --sandbox=<path>    Path to the sandbox directory
EOF
}

# =============================================================================
# main  --  entry point when exec'd by agent-sandbox reject
# =============================================================================

# Parses flags forwarded from agent-sandbox.sh dispatch and calls reject_run.
# Expected flags: --project=<dir> --sandbox=<dir>
main() {
  parse_args usage \
    --project=PROJECT_DIR \
    --sandbox=SANDBOX_DIR \
    -- "$@"
  local rc=$?
  if [[ $rc -eq 2 ]]; then exit 0; fi
  [[ $rc -eq 0 ]] || exit 1

  if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
    usage >&2
    exit 1
  fi

  reject_run "$PROJECT_DIR" "$SANDBOX_DIR"
}

# Guard: only run main() when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
