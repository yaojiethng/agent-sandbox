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

# Given: a draft branch with its work committed
# When:  confirm_run runs
# Then:  the draft branch is gone
# Asserts: the final delete
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

# Given: a draft branch carrying changes, and the source branch it was cut from
# When:  confirm_run runs
# Then:  the changes are on the source branch and the closing message names it
# Asserts: the fast-forward outcome and its operator-facing closing message
test_confirm_merges_changes() {
  make_draft_fixture confirm_merge 2

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1
  local OUT
  OUT=$(confirm_run "$P" "$S" "" 2>&1)

  local COUNT
  COUNT=$(git -C "$P" rev-list --count main)
  if [[ "$COUNT" -ge 3 ]]; then
    pass "confirm merges changes into source branch"
  else
    fail "expected at least 3 commits on main, got $COUNT"
  fi
  if [[ "$OUT" == *"Done. Changes merged into main."* ]]; then
    pass "confirm prints the closing merge message naming the target"
  else
    fail "confirm closing message missing: $OUT"
  fi
}

# Given: --target naming another branch
# When:  confirm_run runs
# Then:  the changes land there
# Asserts: the target override - an unresolvable target has no unit (row 244)
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

# Given: HEAD is not on a draft/* branch
# When:  confirm_run runs
# Then:  the output says so
# Asserts: the message only - it comes from the sub-function, so the unit cannot tell whether confirm honoured the verdict (row 243)
test_confirm_rejects_non_draft_branch() {
  local P="$FIXTURE_DIR/confirm_nondraft_p"
  make_committed_repo "$P"
  local S="$FIXTURE_DIR/confirm_nondraft_s"

  local OUT
  OUT=$(confirm_run "$P" "$S" "" 2>&1) || true
  assert_contains "$OUT" "not on a draft branch" "confirm rejects when not on a draft branch"
}

# Given: commits added after the .draft-state commit, so the tip has moved past it
# When:  confirm_run runs
# Then:  the draft is deleted and the later commits merge with it
# Asserts: the drop step tolerates a .draft-state commit that is no longer first (two assertions)
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

# Given: a target branch that conflicts with the draft
# When:  confirm_run runs
# Then:  it fails, the draft is preserved at the savepoint, and the recovery direction is printed
# Asserts: the rebase-failure rollback and the recovery guidance it prints
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
  assert_contains "$OUT" "Resolve the divergence on the draft branch" "confirm prints the conflict recovery direction"
  assert_contains "$OUT" "make reject" "confirm names the discard path"
}

_make_no_state_commit_conflict_draft() {
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
  echo "draft edit" > "$P/file.txt"
  echo "draft content" > "$P/work.txt"
  git -C "$P" add .draft-state file.txt work.txt
  git -C "$P" commit -m "work 1" --quiet

  git -C "$P" checkout main --quiet
  echo "main edit" > "$P/file.txt"
  git -C "$P" add file.txt
  git -C "$P" commit -m "main advance" --quiet
  git -C "$P" checkout draft/foo --quiet
}

# Given: a draft that conflicts with its target and carries committed work
# When:  confirm_run runs
# Then:  it fails non-zero, names the savepoint restore, and leaves the draft at the savepoint with no rebase in progress
# Asserts: the rebase-failure rollback: the branch tip, the draft's committed work, and the repository state the caller is left in.
test_confirm_conflict_restores_the_draft_to_the_savepoint() {
  local P="$FIXTURE_DIR/confirm_restore_p"
  local S="$FIXTURE_DIR/confirm_restore_s"
  _make_no_state_commit_conflict_draft "$P"
  local TIP_BEFORE
  TIP_BEFORE=$(git -C "$P" rev-parse HEAD)

  local OUT RC
  OUT=$(confirm_run "$P" "$S" "" 2>&1) || RC=$?
  RC="${RC:-0}"

  local WORK_OK REBASE_LEFT
  WORK_OK=no
  git -C "$P" cat-file -e draft/foo:work.txt 2>/dev/null && WORK_OK=yes
  REBASE_LEFT=no
  if [[ -e "$P/.git/REBASE_HEAD" || -d "$P/.git/rebase-merge" || -d "$P/.git/rebase-apply" ]]; then
    REBASE_LEFT=yes
  fi

  if [[ "$RC" -ne 0 \
        && "$OUT" == *"the draft branch is restored to the savepoint"* \
        && "$(git -C "$P" rev-parse HEAD)" == "$TIP_BEFORE" \
        && "$WORK_OK" == yes \
        && "$REBASE_LEFT" == no ]]; then
    pass "confirm conflict restores the draft to the savepoint and leaves no rebase in progress"
  else
    fail "rc=$RC tip-preserved=$([[ "$(git -C "$P" rev-parse HEAD)" == "$TIP_BEFORE" ]] && echo yes || echo no) work=$WORK_OK rebase-left=$REBASE_LEFT"
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

# Given: a .draft-state commit whose drop step fails
# When:  confirm_run runs
# Then:  it fails and the draft tip is restored from the savepoint
# Asserts: the drop-failure rollback
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

# Given: NEW mode with a target name no branch uses
# When:  confirm_run runs
# Then:  the new branch holds the draft tip, the draft is gone, the source branch is untouched, and the reset direction is printed
# Asserts: the whole NEW contract in one unit
test_confirm_new_branch_creates_and_prints_hint() {
  make_draft_fixture confirm_new 2
  local MAIN_BEFORE
  MAIN_BEFORE=$(git -C "$P" rev-parse main)

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1
  local DRAFT_BRANCH
  DRAFT_BRANCH=$(draft_branch "$P")

  local OUT
  OUT=$(confirm_run "$P" "$S" "rebased-series" "true" 2>&1) || true

  local OK=true
  git -C "$P" show-ref --verify --quiet refs/heads/rebased-series || OK=false
  _branch_exists "$P" "$DRAFT_BRANCH" && OK=false
  [[ "$(git -C "$P" rev-parse main)" == "$MAIN_BEFORE" ]] || OK=false
  [[ "$OUT" == *"git reset --soft rebased-series"* ]] || OK=false
  [[ "$OUT" == *"git switch main"* ]] || OK=false

  if [[ "$OK" == true ]]; then
    pass "confirm NEW creates the branch at the draft tip, deletes the draft, leaves the target, and prints the reset direction"
  else
    fail "confirm NEW state wrong (out=$OUT)"
  fi
}

# Given: NEW mode and a target name that already exists
# When:  confirm_run runs
# Then:  it refuses and leaves the draft in place
# Asserts: the existence guard
test_confirm_new_branch_rejects_existing() {
  make_draft_fixture confirm_new_exists 2

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1
  local DRAFT_BRANCH
  DRAFT_BRANCH=$(draft_branch "$P")

  local OUT
  OUT=$(confirm_run "$P" "$S" "main" "true" 2>&1) || true

  if [[ "$OUT" == *"already exists"* ]] && _branch_exists "$P" "$DRAFT_BRANCH"; then
    pass "confirm NEW rejects an existing branch and leaves the draft in place"
  else
    fail "confirm NEW should reject an existing branch; out=$OUT"
  fi
}

# Given: NEW mode and no target name
# When:  confirm_run runs
# Then:  the output requires TARGET_BRANCH
# Asserts: the empty-target guard
test_confirm_new_branch_requires_target() {
  make_draft_fixture confirm_new_notarget 2

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  local OUT
  OUT=$(confirm_run "$P" "$S" "" "true" 2>&1) || true
  assert_contains "$OUT" "requires TARGET_BRANCH" "confirm NEW requires a target branch name"
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
run_test test_confirm_conflict_restores_the_draft_to_the_savepoint
run_test test_confirm_drop_step_failure_restores_savepoint
run_test test_confirm_new_branch_creates_and_prints_hint
run_test test_confirm_new_branch_rejects_existing
run_test test_confirm_new_branch_requires_target

test_done
