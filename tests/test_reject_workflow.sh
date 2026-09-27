#!/usr/bin/env bash
# tests/test_reject_workflow.sh
# Tests for libs/reject_workflow.sh
# Pins cite: devlog/discussions/design_apply_draft_workflow.md (draft branch
# lifecycle: reject_run returns to source, deletes the branch).

#
# Covers:
#   reject_run   --  returns to source, deletes draft branch
#   reject_run guards  --  missing project, held index lock, absent-branch arm
#   working-tree residue discard  --  reject discards uncommitted draft changes
#   reject.sh entry point  --  identity-argument guard and reject_run forwarding
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

# lsof stub: a probe that exits 0 reports a live holder, so
# draft_clear_stale_lock refuses a planted lock deterministically.
mkdir -p "$FIXTURE_ROOT/stub_lsof_hold"
printf '#!/bin/sh\nexit 0\n' > "$FIXTURE_ROOT/stub_lsof_hold/lsof"
chmod +x "$FIXTURE_ROOT/stub_lsof_hold/lsof"

# Given: a draft branch whose working tree carries a tracked-file edit that blocks the source checkout
# When:  reject_run runs
# Then:  rc 0, the source branch is current, the draft branch is gone, and the discard warning is printed
# Asserts: the force-checkout fallback (bite R6); the untracked arm of the discard is not supplied, so `clean -fd` and the suppressed checkout stderr are unpinned (rows 253 and 249)
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

# Given: a draft branch with its work committed
# When:  reject_run runs
# Then:  the source branch is current
# Asserts: the branch switch, and the record it reads through `eval` (bite R4)
test_reject_returns_to_source() {
  make_draft_fixture reject_src 1

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1
  reject_run "$P" "$S" >/dev/null 2>&1

  local CURR
  CURR=$(_current_branch "$P")
  assert_eq "$CURR" "main" "reject returns to source branch"
}

# Given: a draft branch with its work committed
# When:  reject_run runs
# Then:  the draft branch no longer exists
# Asserts: the existence guard and the force delete (bites R8, R9)
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

# Given: a repository on a non-draft branch
# When:  reject_run runs
# Then:  it refuses at the branch validation and never evaluates the unset state
# Asserts: the caller honours draft_validate_branch's verdict - a caller that
#          continues reaches the unbound source_branch (bite R3)
test_reject_rejects_non_draft() {
  local P="$FIXTURE_DIR/reject_nondraft_p"
  make_committed_repo "$P"
  local S="$FIXTURE_DIR/reject_nondraft_s"

  local OUT RC=0
  OUT=$(reject_run "$P" "$S" 2>&1) || RC=$?
  if [[ "$RC" -ne 0 && "$OUT" == *"not on a draft branch"* \
     && "$OUT" != *"unbound variable"* ]]; then
    pass "reject rejects when not on a draft branch and stops at the verdict"
  else
    fail "reject continued past the draft-validation verdict: rc=$RC out=$OUT"
  fi
}

# Given: a PROJECT_DIR that does not exist
# When:  reject_run runs
# Then:  it refuses at the project guard and does not reach draft validation
# Asserts: validate_project_dir's verdict is honoured (bite R1)
test_reject_rejects_missing_project_dir() {
  local P="$FIXTURE_DIR/reject_missing_p"
  local S="$FIXTURE_DIR/reject_missing_s"

  local OUT RC=0
  OUT=$(reject_run "$P" "$S" 2>&1) || RC=$?

  if [[ "$RC" -ne 0 && "$OUT" == *"PROJECT_DIR does not exist"* \
     && "$OUT" != *"not in a git repository"* ]]; then
    pass "reject refuses a missing PROJECT_DIR before draft validation"
  else
    fail "reject should stop at the missing-project guard: rc=$RC out=$OUT"
  fi
}

# Given: a valid draft and a .git/index.lock the holder probe reports as held
# When:  reject_run runs
# Then:  it refuses at the stale-lock guard and does not start the rejection
# Asserts: draft_clear_stale_lock's verdict is honoured (bite R2)
test_reject_rejects_held_index_lock() {
  make_draft_fixture reject_heldlock 1
  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1
  local DRAFT_BRANCH
  DRAFT_BRANCH=$(draft_branch "$P")

  touch "$P/.git/index.lock"

  local OUT RC=0
  OUT=$(PATH="$FIXTURE_ROOT/stub_lsof_hold:$PATH" reject_run "$P" "$S" 2>&1) || RC=$?
  rm -f "$P/.git/index.lock"

  if [[ "$RC" -ne 0 && "$OUT" == *"index.lock is held"* \
     && "$OUT" != *"Rejecting draft"* && -n "$DRAFT_BRANCH" ]]; then
    pass "reject refuses a held index lock before the rejection"
  else
    fail "reject should stop at the held-lock guard: rc=$RC out=$OUT"
  fi
}

# Given: a draft whose .draft-state carries a CURRENT_BRANCH key naming another
#        branch (a key outside the field contract)
# When:  reject_run runs
# Then:  the key is ignored: the checked-out draft branch is deleted, the named
#        branch survives, and the caller returns to the source branch
# Asserts: the field allowlist - before it, a crafted key replaced the validated
#          branch and reject deleted a ref named by the record instead.
test_reject_ignores_unknown_state_key() {
  local P="$FIXTURE_DIR/reject_poisoned_p"
  local S="$FIXTURE_DIR/reject_poisoned_s"
  make_committed_repo "$P"
  local BASE
  BASE=$(get_init_sha "$P")

  # A bystander branch stands in for any ref a crafted key could name.
  git -C "$P" branch bystander

  git -C "$P" checkout -qb draft/foo
  {
    printf 'source_branch: main\n'
    printf 'from_hash: %s\n' "$BASE"
    printf 'CURRENT_BRANCH: bystander\n'
    printf 'author: test@fixture\n'
  } > "$P/.draft-state"
  git -C "$P" add .draft-state
  git -C "$P" commit -m ".draft-state" --quiet

  local OUT RC=0
  OUT=$(reject_run "$P" "$S" 2>&1) || RC=$?

  if [[ "$RC" -eq 0 && "$(_current_branch "$P")" == "main" ]] \
     && [[ "$OUT" == *"Deleted draft branch: draft/foo"* ]] \
     && [[ "$OUT" != *"bystander"* ]] \
     && _branch_exists "$P" "bystander" \
     && ! _branch_exists "$P" "draft/foo"; then
    pass "a crafted CURRENT_BRANCH key cannot redirect the deletion"
  else
    fail "poisoned key redirected reject: rc=$RC curr=$(_current_branch "$P") out=$OUT"
  fi
}

# Given: a valid draft and a script invocation that names only the project
# When:  reject.sh runs as a script
# Then:  it refuses and prints the usage, without calling reject_run
# Asserts: main's identity-argument guard (bite R13)
test_reject_script_entry_requires_identity() {
  local P="$FIXTURE_DIR/reject_entry_missing_p"
  make_committed_repo "$P"

  local OUT RC=0
  OUT=$(bash "$AGENT_SANDBOX_REPO/scripts/workflows/reject.sh" --project="$P" 2>&1) || RC=$?

  if [[ "$RC" -ne 0 && "$OUT" == *"Usage: agent-sandbox reject"* ]]; then
    pass "reject.sh entry point refuses to run without --sandbox"
  else
    fail "reject.sh entry point identity guard broken: rc=$RC out=$OUT"
  fi
}

# Given: a valid draft and a script invocation with both identity flags
# When:  reject.sh runs as a script
# Then:  the draft is discarded and the project returns to the source branch
# Asserts: main forwards to reject_run and carries its verdict
test_reject_script_entry_discards_draft() {
  make_draft_fixture reject_entry 1
  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1
  local DRAFT_BRANCH
  DRAFT_BRANCH=$(draft_branch "$P")

  local OUT RC=0
  OUT=$(bash "$AGENT_SANDBOX_REPO/scripts/workflows/reject.sh" \
    --project="$P" --sandbox="$S" 2>&1) || RC=$?

  local DRAFT_LEFT
  DRAFT_LEFT=$(draft_branch "$P")
  if [[ "$RC" -eq 0 && "$(_current_branch "$P")" == "main" && -z "$DRAFT_LEFT" ]] \
     && [[ "$OUT" == *"Draft rejected. PROJECT_DIR restored to main."* ]]; then
    pass "reject.sh entry point discards the draft through reject_run"
  else
    fail "reject.sh entry point broken: rc=$RC curr=$(_current_branch "$P") draft='$DRAFT_LEFT' out=$OUT"
  fi
}

# =============================================================================
# Run all
# =============================================================================
run_test test_reject_returns_to_source
run_test test_reject_deletes_draft_branch
run_test test_reject_discards_uncommitted_draft_residue
run_test test_reject_rejects_non_draft
run_test test_reject_rejects_missing_project_dir
run_test test_reject_rejects_held_index_lock
run_test test_reject_ignores_unknown_state_key
run_test test_reject_script_entry_requires_identity
run_test test_reject_script_entry_discards_draft

test_done
