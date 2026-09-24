#!/usr/bin/env bash
# scripts/workflows/confirm.sh
# Confirm workflow: rebase draft branch onto target, fast-forward merge, delete draft.
# Exec'd directly by agent-sandbox.sh (dispatch); main() runs only when not
# sourced, so test suites may source this file for its functions.
# Sources draft_state.sh for draft-state helpers and guards.sh for git guard functions.

set -euo pipefail

# Derive repo root from own path when exec'd.
_confirm_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SANDBOX_REPO="${AGENT_SANDBOX_REPO:-$(cd "$_confirm_self/../.." && pwd)}"

source "$AGENT_SANDBOX_REPO/src/libs/draft_state.sh"
source "$AGENT_SANDBOX_REPO/src/libs/cli.sh"
source "$AGENT_SANDBOX_REPO/scripts/guards.sh"

# =============================================================================
# confirm_run  --  rebase, fast-forward merge, delete draft branch
# =============================================================================

# _confirm_into_new_branch PROJECT_DIR NEW_BRANCH DRAFT_BRANCH SOURCE_BRANCH SAVEPOINT
#   Creates NEW_BRANCH at the draft tip (after .draft-state was dropped),
#   deletes the draft, and prints the operator-run direction that moves
#   SOURCE_BRANCH onto the new series. The existing target is left untouched,
#   so no merge or rebase runs. Returns 1 on failure with a savepoint rollback.
_confirm_into_new_branch() {
  local PROJECT_DIR="$1"
  local NEW_BRANCH="$2"
  local DRAFT_BRANCH="$3"
  local SOURCE_BRANCH="$4"
  local SAVEPOINT_COMMIT="$5"

  echo "Creating new branch '$NEW_BRANCH' at the draft tip..."
  if ! git -C "$PROJECT_DIR" switch -c "$NEW_BRANCH" >/dev/null 2>&1; then
    echo "Rolling back to savepoint..." >&2
    git -C "$PROJECT_DIR" reset --hard "$SAVEPOINT_COMMIT"
    echo "Error: failed to create branch $NEW_BRANCH" >&2
    return 1
  fi

  echo "Deleting draft branch: $DRAFT_BRANCH"
  git -C "$PROJECT_DIR" branch -D "$DRAFT_BRANCH" >/dev/null 2>&1 || true

  echo ""
  echo "Done. New branch created: $NEW_BRANCH"
  echo "Branch '$SOURCE_BRANCH' is untouched. To move it onto the rebased series, run:"
  echo "  git switch $SOURCE_BRANCH"
  echo "  git reset --soft $NEW_BRANCH"
}

confirm_run() {
  local PROJECT_DIR="$1"
  local SANDBOX_DIR="$2"
  local TARGET_BRANCH="$3"
  local NEW_MODE="${4:-false}"

  validate_project_dir "$PROJECT_DIR" || return 1
  draft_clear_stale_lock "$PROJECT_DIR" || return 1

  # Validate draft branch and read .draft-state into local scope
  local DRAFT_VALIDATION
  DRAFT_VALIDATION=$(draft_validate_branch "$PROJECT_DIR") || return 1
  eval "$DRAFT_VALIDATION"

  local MERGE_TARGET=""
  if [[ "$NEW_MODE" == true ]]; then
    # New-branch mode: TARGET_BRANCH names a branch that must not exist yet.
    if [[ -z "$TARGET_BRANCH" ]]; then
      echo "Error: NEW=1 requires TARGET_BRANCH=<new-branch>." >&2
      return 1
    fi
    if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
      echo "Error: branch already exists: $TARGET_BRANCH" >&2
      echo "  NEW=1 creates a new branch; choose a name that does not exist." >&2
      return 1
    fi
  else
    MERGE_TARGET="${TARGET_BRANCH:-$source_branch}"
    if ! git -C "$PROJECT_DIR" rev-parse --verify "$MERGE_TARGET" >/dev/null 2>&1; then
      echo "Error: target branch does not exist: $MERGE_TARGET" >&2
      echo "  Specify a different target: make confirm TARGET_BRANCH=<branch>" >&2
      return 1
    fi
  fi

  # 1. Rollback savepoint, held in a local variable (not a git tag) so the
  #    restore target is scoped to this run. A fixed-name git tag could either
  #    be missing (no .draft-state commit -> hard abort under set -e) or stale
  #    (an interrupted prior run) and reset the branch to the wrong commit.
  local SAVEPOINT_COMMIT
  SAVEPOINT_COMMIT=$(git -C "$PROJECT_DIR" rev-parse HEAD)

  # 2. Drop .draft-state commit (if found)
  if [[ -n "${DRAFT_STATE_COMMIT:-}" ]]; then
    echo "Dropping .draft-state commit..."
    if ! git -C "$PROJECT_DIR" rebase --onto "${DRAFT_STATE_COMMIT}^" "$DRAFT_STATE_COMMIT" "$CURRENT_BRANCH"; then
      echo "Rolling back to savepoint..." >&2
      git -C "$PROJECT_DIR" rebase --abort 2>/dev/null || true
      git -C "$PROJECT_DIR" reset --hard "$SAVEPOINT_COMMIT"
      echo "Error: failed to drop .draft-state commit" >&2
      return 1
    fi
  else
    echo ".draft-state commit not found  --  skipping drop step."
  fi

  if [[ "$NEW_MODE" == true ]]; then
    _confirm_into_new_branch "$PROJECT_DIR" "$TARGET_BRANCH" "$CURRENT_BRANCH" \
      "$source_branch" "$SAVEPOINT_COMMIT"
    return $?
  fi

  # 3. Rebase draft onto target
  echo "Rebasing $CURRENT_BRANCH onto $MERGE_TARGET..."
  if ! git -C "$PROJECT_DIR" rebase "$MERGE_TARGET" "$CURRENT_BRANCH"; then
    echo "" >&2
    echo "Conflict rebasing $CURRENT_BRANCH onto $MERGE_TARGET." >&2
    echo "Rebase failed; the draft branch is restored to the savepoint (unchanged)." >&2
    echo "Resolve the divergence on the draft branch, then run 'make confirm' again." >&2
    echo "To discard the draft branch: 'make reject'." >&2
    echo "" >&2
    echo "Rolling back to savepoint..." >&2
    git -C "$PROJECT_DIR" rebase --abort 2>/dev/null || true
    git -C "$PROJECT_DIR" reset --hard "$SAVEPOINT_COMMIT"
    return 1
  fi

  # 4. Fast-forward merge
  echo "Fast-forward merging $CURRENT_BRANCH into $MERGE_TARGET..."
  git -C "$PROJECT_DIR" switch "$MERGE_TARGET"
  git -C "$PROJECT_DIR" merge --ff-only "$CURRENT_BRANCH"

  # 5. Delete draft branch
  echo "Deleting draft branch: $CURRENT_BRANCH"
  git -C "$PROJECT_DIR" branch -D "$CURRENT_BRANCH"

  echo ""
  echo "Done. Changes merged into $MERGE_TARGET."
}

# =============================================================================
# usage  --  print help text
# =============================================================================

usage() {
  cat <<EOF
Usage: agent-sandbox confirm --project=<path> --sandbox=<path> [options]

Rebases the current draft branch onto its target and fast-forward merges.
With --new, creates TARGET_BRANCH at the draft tip instead, leaving the
source branch untouched and printing the follow-up commands that move it.

or, from a sandbox Makefile: make confirm [TARGET_BRANCH=<branch>] [NEW=1]

Required:
  --project=<path>    Path to the git repository
  --sandbox=<path>    Path to the sandbox directory

Options:
  --target=<branch>   Target branch to merge into (default: source branch from .draft-state)
  --new               Create TARGET_BRANCH at the draft tip; TARGET_BRANCH must not exist
EOF
}

# =============================================================================
# main  --  entry point when exec'd by agent-sandbox confirm
# =============================================================================

# Parses flags forwarded from agent-sandbox.sh dispatch and calls confirm_run.
# Expected flags: --project=<dir> --sandbox=<dir> [--target=<branch>] [--new]
main() {
  parse_args usage \
    --project=PROJECT_DIR \
    --sandbox=SANDBOX_DIR \
    --target=TARGET_BRANCH \
    --new \
    -- "$@"
  local rc=$?
  if [[ $rc -eq 2 ]]; then exit 0; fi
  [[ $rc -eq 0 ]] || exit 1

  if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
    usage >&2
    exit 1
  fi

  confirm_run "$PROJECT_DIR" "$SANDBOX_DIR" "$TARGET_BRANCH" "$NEW"
}

# Guard: only run main() when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
