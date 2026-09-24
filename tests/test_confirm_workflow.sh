#!/usr/bin/env bash
# tests/test_confirm_workflow.sh
# Tests for libs/confirm_workflow.sh
# Pins cite: devlog/discussions/design_apply_draft_workflow.md (draft branch
# lifecycle: confirm_run rebases, merges, deletes the branch).

#
# Covers:
#   confirm_run   --  rebases, merges, deletes draft branch
#   savepoint rollback  --  no-savepoint-tag, stale-tag, drop-step failures
#
# Uses make_draft_fixture for synthetic session exports and the conflict
# fixture builders at the bottom of this file.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
export AGENT_SANDBOX_REPO="$REPO_ROOT"
source "$REPO_ROOT/scripts/workflows/draft.sh"
source "$REPO_ROOT/scripts/workflows/confirm.sh"
source "$REPO_ROOT/scripts/guards.sh"
source "$TEST_DIR/libs/git_fixtures.sh"
source "$TEST_DIR/libs/session_fixtures.sh"
source "$TEST_DIR/libs/draft_fixtures.sh"

test_confirm_deletes_draft_branch() {
  make_draft_fixture confirm_del 2

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1
  local DRAFT_BRANCH
  DRAFT_BRANCH=$(draft_branch "$P")

  confirm_run "$P" "$S" "" >/dev/null 2>&1

  if _branch_exists "$P" "$DRAFT_BRANCH"; then
    fail "confirm did not delete draft branch"
  else
    pass "confirm deletes draft branch"
  fi
}

test_confirm_merges_changes() {
  make_draft_fixture confirm_merge 2

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1
  confirm_run "$P" "$S" "" >/dev/null 2>&1

  local COUNT
  COUNT=$(git -C "$P" rev-list --count main)
  if [[ "$COUNT" -ge 3 ]]; then
    pass "confirm merges changes into source branch"
  else
    fail "expected at least 3 commits on main, got $COUNT"
  fi
}

test_confirm_target_branch() {
  local P="$FIXTURE_DIR/confirm_target_p"
  local S="$FIXTURE_DIR/confirm_target_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-test-branch"
  make_committed_repo "$P"
  git -C "$P" checkout -b feature-branch --quiet
  git -C "$P" checkout main --quiet
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT" 2

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1
  confirm_run "$P" "$S" "feature-branch" >/dev/null 2>&1

  local CURR
  CURR=$(_current_branch "$P")
  if [[ "$CURR" == "feature-branch" ]]; then
    local COUNT
    COUNT=$(git -C "$P" rev-list --count feature-branch)
    if [[ "$COUNT" -ge 3 ]]; then
      pass "confirm TARGET merges to specified branch"
    else
      fail "commits not on target: expected >=3, got $COUNT"
    fi
  else
    fail "not on feature-branch after confirm: $CURR"
  fi
}

test_confirm_rejects_non_draft_branch() {
  local P="$FIXTURE_DIR/confirm_nondraft_p"
  make_committed_repo "$P"
  local S="$FIXTURE_DIR/confirm_nondraft_s"

  local OUT
  OUT=$(confirm_run "$P" "$S" "" 2>&1) || true
  assert_contains "$OUT" "not on a draft branch" "confirm rejects when not on a draft branch"
}

test_confirm_after_draft_branch_advances() {
  make_draft_fixture confirm_advance 2

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1
  local DRAFT_BRANCH
  DRAFT_BRANCH=$(draft_branch "$P")

  # Advance the draft branch past the .draft-state commit (as a rebase or
  # continued work would)  --  the state commit is no longer the branch tip.
  # confirm_run runs FROM the draft branch (its own contract), so stay there.
  git -C "$P" checkout "$DRAFT_BRANCH" --quiet
  echo "post-draft work" > "$P/post-draft.txt"
  git -C "$P" add post-draft.txt
  git -C "$P" commit -m "post-draft work" --quiet

  confirm_run "$P" "$S" "" >/dev/null 2>&1 || fail "confirm_run returned non-zero"

  if _branch_exists "$P" "$DRAFT_BRANCH"; then
    fail "confirm did not delete advanced draft branch"
  else
    pass "confirm deletes draft branch whose tip moved past .draft-state"
  fi

  if [[ -f "$P/post-draft.txt" && $(git -C "$P" rev-list --count main) -ge 4 ]]; then
    pass "confirm merges post-draft commits along with relocated .draft-state"
  else
    fail "post-draft work lost or incomplete merge on main"
  fi
}

test_confirm_conflict_recovery() {
  make_draft_fixture confirm_conflict 1

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1
  local DRAFT_BRANCH
  DRAFT_BRANCH=$(draft_branch "$P")

  git -C "$P" checkout main --quiet
  echo "conflicting content" > "$P/file-1.txt"
  git -C "$P" add file-1.txt
  git -C "$P" commit -m "conflicting change" --quiet
  git -C "$P" checkout "$DRAFT_BRANCH" --quiet

  local OUT
  OUT=$(confirm_run "$P" "$S" "" 2>&1) || true

  git -C "$P" rebase --abort 2>/dev/null || true
  git -C "$P" checkout main --quiet 2>/dev/null || true
  git -C "$P" branch -D "$DRAFT_BRANCH" 2>/dev/null || true

  assert_contains "$OUT" "Conflict rebasing" "confirm reports rebase conflict with recovery hints"
}

_make_no_state_commit_conflict_draft() {
  local P="$1"
  local STALE="${2:-no}"
  make_committed_repo "$P"

  local BASE_SHA
  BASE_SHA=$(get_init_sha "$P")

  git -C "$P" checkout -qb draft/foo
  {
    printf 'source_branch: main\n'
    printf 'from_hash: %s\n' "$BASE_SHA"
    printf 'author: test@fixture\n'
    printf 'session_ts: 20260420-120000\n'
    printf 'host_branch: main\n'
    printf 'diff_count: 1\n'
    printf 'exported-at: 20260420-120001\n'
    printf 'drafted-at: 20260420-120001\n'
  } > "$P/.draft-state"
  echo "draft edit" > "$P/file.txt"
  echo "draft content" > "$P/work.txt"
  git -C "$P" add .draft-state file.txt work.txt
  git -C "$P" commit -m "work 1" --quiet

  git -C "$P" checkout main --quiet
  echo "main edit" > "$P/file.txt"
  git -C "$P" add file.txt
  git -C "$P" commit -m "main advance" --quiet
  git -C "$P" checkout draft/foo --quiet

  if [[ "$STALE" == yes ]]; then
    git -C "$P" tag confirm-savepoint "$BASE_SHA"
  fi
}

test_confirm_conflict_no_savepoint_tag_aborts_cleanly() {
  local P="$FIXTURE_DIR/confirm_nosave_p"
  local S="$FIXTURE_DIR/confirm_nosave_s"
  _make_no_state_commit_conflict_draft "$P" no
  local TIP_BEFORE
  TIP_BEFORE=$(git -C "$P" rev-parse HEAD)

  local OUT RC
  OUT=$(confirm_run "$P" "$S" "" 2>&1) || RC=$?
  RC="${RC:-0}"

  local STILL_NO_TAG
  STILL_NO_TAG=$(git -C "$P" tag -l confirm-savepoint)

  if [[ "$RC" -ne 0 \
        && "$OUT" != *"fatal: ambiguous argument"* \
        && "$(git -C "$P" rev-parse HEAD)" == "$TIP_BEFORE" \
        && -z "$STILL_NO_TAG" ]]; then
    pass "confirm conflict with no savepoint tag fails cleanly and restores draft"
  else
    fail "rc=$RC out=$OUT tip-preserved=$([[ "$(git -C "$P" rev-parse HEAD)" == "$TIP_BEFORE" ]] && echo yes || echo no)"
  fi
}

test_confirm_conflict_stale_savepoint_preserves_draft() {
  local P="$FIXTURE_DIR/confirm_stale_p"
  local S="$FIXTURE_DIR/confirm_stale_s"
  _make_no_state_commit_conflict_draft "$P" yes
  local TIP_BEFORE
  TIP_BEFORE=$(git -C "$P" rev-parse HEAD)

  local OUT RC
  OUT=$(confirm_run "$P" "$S" "" 2>&1) || RC=$?
  RC="${RC:-0}"

  local TAG_AFTER WORK_OK
  TAG_AFTER=$(git -C "$P" tag -l confirm-savepoint)
  WORK_OK=no
  git -C "$P" cat-file -e draft/foo:work.txt 2>/dev/null && WORK_OK=yes

  if [[ "$RC" -ne 0 \
        && "$(git -C "$P" rev-parse HEAD)" == "$TIP_BEFORE" \
        && "$WORK_OK" == yes \
        && -n "$TAG_AFTER" ]]; then
    pass "confirm ignores a stale savepoint tag (draft preserved, tag untouched)"
  else
    fail "rc=$RC tip-preserved=$([[ "$(git -C "$P" rev-parse HEAD)" == "$TIP_BEFORE" ]] && echo yes || echo no) work=$WORK_OK tag-kept=$([[ -n "$TAG_AFTER" ]] && echo yes || echo no)"
  fi
}

_make_state_commit_draft_with_dirty_tree() {
  local P="$1"
  make_committed_repo "$P"

  local BASE_SHA
  BASE_SHA=$(get_init_sha "$P")

  git -C "$P" checkout -qb draft/foo
  {
    printf 'source_branch: main\n'
    printf 'from_hash: %s\n' "$BASE_SHA"
    printf 'author: test@fixture\n'
    printf 'session_ts: 20260420-120000\n'
    printf 'host_branch: main\n'
    printf 'diff_count: 1\n'
    printf 'exported-at: 20260420-120001\n'
    printf 'drafted-at: 20260420-120001\n'
  } > "$P/.draft-state"
  git -C "$P" add .draft-state
  git -C "$P" commit -m ".draft-state" --quiet
  echo "draft content" > "$P/file.txt"
  git -C "$P" add file.txt
  git -C "$P" commit -m "work" --quiet

  # Uncommitted change forces `rebase --onto` to refuse, deterministically
  # triggering the drop-step failure rollback.
  echo "uncommitted edit" > "$P/file.txt"
}

test_confirm_drop_step_failure_restores_savepoint() {
  local P="$FIXTURE_DIR/confirm_dropstepp_p"
  local S="$FIXTURE_DIR/confirm_dropstepp_s"
  _make_state_commit_draft_with_dirty_tree "$P"
  local TIP_BEFORE
  TIP_BEFORE=$(git -C "$P" rev-parse HEAD)

  local OUT RC
  OUT=$(confirm_run "$P" "$S" "" 2>&1) || RC=$?
  RC="${RC:-0}"

  local REPO_CLEAN
  REPO_CLEAN="$(git -C "$P" status --porcelain | wc -l | tr -d ' ')"

  if [[ "$RC" -ne 0 \
        && "$OUT" != *"fatal:"* \
        && "$(git -C "$P" rev-parse HEAD)" == "$TIP_BEFORE" \
        && "$OUT" == *"failed to drop .draft-state commit"* \
        && "$REPO_CLEAN" == 0 ]]; then
    pass "confirm drop-step failure restores savepoint and fails cleanly"
  else
    fail "rc=$RC out=$OUT tip-restored=$([[ "$(git -C "$P" rev-parse HEAD)" == "$TIP_BEFORE" ]] && echo yes || echo no) tree-clean=$REPO_CLEAN"
  fi

  git -C "$P" rebase --abort 2>/dev/null || true
}

# =============================================================================
# Run all
# =============================================================================
run_test test_confirm_deletes_draft_branch
run_test test_confirm_merges_changes
run_test test_confirm_target_branch
run_test test_confirm_rejects_non_draft_branch
run_test test_confirm_after_draft_branch_advances
run_test test_confirm_conflict_recovery
run_test test_confirm_conflict_no_savepoint_tag_aborts_cleanly
run_test test_confirm_conflict_stale_savepoint_preserves_draft
run_test test_confirm_drop_step_failure_restores_savepoint

test_done
