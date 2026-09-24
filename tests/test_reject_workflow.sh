#!/usr/bin/env bash
# tests/test_reject_workflow.sh
# Tests for libs/reject_workflow.sh
# Pins cite: devlog/discussions/design_apply_draft_workflow.md (draft branch
# lifecycle: reject_run returns to source, deletes the branch).

#
# Covers:
#   reject_run   --  returns to source, deletes draft branch
#   working-tree residue discard  --  reject discards uncommitted draft changes
#
# Uses make_draft_fixture for synthetic session exports.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
export AGENT_SANDBOX_REPO="$REPO_ROOT"
source "$REPO_ROOT/scripts/workflows/draft.sh"
source "$REPO_ROOT/scripts/workflows/reject.sh"
source "$REPO_ROOT/scripts/guards.sh"
source "$TEST_DIR/libs/git_fixtures.sh"
source "$TEST_DIR/libs/session_fixtures.sh"
source "$TEST_DIR/libs/draft_fixtures.sh"

test_reject_discards_uncommitted_draft_residue() {
  make_draft_fixture reject_residue 1

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1
  local DRAFT_BRANCH
  DRAFT_BRANCH=$(draft_branch "$P")

  # Simulate post-draft working-tree residue that genuinely blocks the source
  # checkout: an unstaged edit to file-1.txt, which is tracked on the draft
  # branch but absent on main, so git refuses to carry the change across.
  echo "residue" >> "$P/file-1.txt"

  local OUT RC=0
  OUT=$(reject_run "$P" "$S" 2>&1) || RC=$?

  local CURR
  CURR=$(_current_branch "$P")
  local DRAFT_GONE=no
  _branch_exists "$P" "$DRAFT_BRANCH" || DRAFT_GONE=yes

  if [[ $RC -eq 0 \
     && "$CURR" == "main" \
     && "$DRAFT_GONE" == yes \
     && "$OUT" == *"discarding uncommitted draft changes"* ]]; then
    pass "reject returns to source and discards draft residue"
  else
    fail "expected clean reject-discard, rc=$RC curr=$CURR draft-gone=$DRAFT_GONE out='$OUT'"
  fi
}

test_reject_returns_to_source() {
  make_draft_fixture reject_src 1

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1
  reject_run "$P" "$S" >/dev/null 2>&1

  local CURR
  CURR=$(_current_branch "$P")
  assert_eq "$CURR" "main" "reject returns to source branch"
}

test_reject_deletes_draft_branch() {
  make_draft_fixture reject_del 1

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1
  local DRAFT_BRANCH
  DRAFT_BRANCH=$(draft_branch "$P")

  reject_run "$P" "$S" >/dev/null 2>&1

  if _branch_exists "$P" "$DRAFT_BRANCH"; then
    fail "reject did not delete draft branch"
  else
    pass "reject deletes draft branch"
  fi
}

test_reject_rejects_non_draft() {
  local P="$FIXTURE_DIR/reject_nondraft_p"
  make_committed_repo "$P"
  local S="$FIXTURE_DIR/reject_nondraft_s"

  local OUT
  OUT=$(reject_run "$P" "$S" 2>&1) || true
  assert_contains "$OUT" "not on a draft branch" "reject rejects when not on a draft branch"
}

# =============================================================================
# Run all
# =============================================================================
run_test test_reject_returns_to_source
run_test test_reject_deletes_draft_branch
run_test test_reject_discards_uncommitted_draft_residue
run_test test_reject_rejects_non_draft

test_done
