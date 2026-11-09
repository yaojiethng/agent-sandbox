#!/usr/bin/env bash
# tests/test_reject_workflow.sh
# Tests for libs/reject_workflow.sh
# Pins cite: devlog/discussions/archive/20260803-design-settled-apply_draft_workflow.md (draft branch
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
# Asserts: the branch switch and the record it reads from the branch config
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

  if git -C "$P" config --local --get "branch.${DRAFT_BRANCH}.agent-sandbox-source" >/dev/null 2>&1; then
    fail "reject left the draft record behind"
  else
    pass "reject removes the record with the branch"
  fi
}

# Given: a repository on a non-draft branch
# When:  reject_run runs
# Then:  it refuses at the branch validation and does not continue
# Asserts: the caller honours draft_validate_branch's verdict
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

# Given: a draft record carrying an unknown key naming another branch
# When:  reject_run runs
# Then:  the key is ignored: the checked-out draft branch is deleted, the named
#        branch survives, and the caller returns to the source branch
# Asserts: the reader reads only its two keys, so a crafted key cannot redirect
#          the branch deletion.
test_reject_ignores_unknown_record_key() {
  local P="$FIXTURE_DIR/reject_poisoned_p"
  local S="$FIXTURE_DIR/reject_poisoned_s"
  make_committed_repo "$P"
  local BASE
  BASE=$(get_init_sha "$P")

  # A bystander branch stands in for any ref a crafted key could name.
  git -C "$P" branch bystander

  git -C "$P" checkout -qb draft/foo
  draft_record_write "$P" "draft/foo" "main" "$BASE"
  git -C "$P" config --local branch.draft/foo.agent-sandbox-ghost "bystander"

  local OUT RC=0
  OUT=$(reject_run "$P" "$S" 2>&1) || RC=$?

  if [[ "$RC" -eq 0 && "$(_current_branch "$P")" == "main" ]] \
     && [[ "$OUT" == *"Deleted draft branch: draft/foo"* ]] \
     && [[ "$OUT" != *"bystander"* ]] \
     && _branch_exists "$P" "bystander" \
     && ! _branch_exists "$P" "draft/foo"; then
    pass "a crafted record key cannot redirect the deletion"
  else
    fail "poisoned key redirected reject: rc=$RC curr=$(_current_branch "$P") out=$OUT"
  fi
}

# Given: a draft whose recorded source branch no longer exists
# When:  reject_run runs
# Then:  it prints the manual return commands and leaves the draft intact
# Asserts: the missing-source arm does not guess or detach
test_reject_reports_missing_recorded_source() {
  local P="$FIXTURE_DIR/reject_missing_source_p"
  local S="$FIXTURE_DIR/reject_missing_source_s"
  make_committed_repo "$P"
  local BASE
  BASE=$(get_init_sha "$P")
  git -C "$P" checkout -qb draft/foo
  draft_record_write "$P" "draft/foo" "gone-branch" "$BASE"

  local OUT RC=0
  OUT=$(reject_run "$P" "$S" 2>&1) || RC=$?

  if [[ "$RC" -ne 0 && "$OUT" == *"recorded source branch 'gone-branch' no longer exists"* \
     && "$OUT" == *"git branch -D draft/foo"* \
     && "$(_current_branch "$P")" == "draft/foo" ]] \
     && _branch_exists "$P" "draft/foo"; then
    pass "reject reports a missing recorded source and leaves the draft intact"
  else
    fail "missing-source arm wrong: rc=$RC curr=$(_current_branch "$P") out=$OUT"
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

# Given: a script invocation with --help
# When:  reject.sh runs as a script
# Then:  it prints the usage and exits 0
# Asserts: main carries parse_args' help verdict
test_reject_script_entry_help() {
  local OUT RC=0
  OUT=$(bash "$AGENT_SANDBOX_REPO/scripts/workflows/reject.sh" --help 2>&1) || RC=$?
  if [[ "$RC" -eq 0 && "$OUT" == *"Usage: agent-sandbox reject"* ]]; then
    pass "reject.sh --help exits 0 and prints the usage"
  else
    fail "reject.sh --help broken: rc=$RC out=$OUT"
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
run_test test_reject_ignores_unknown_record_key
run_test test_reject_reports_missing_recorded_source
run_test test_reject_script_entry_requires_identity
run_test test_reject_script_entry_help
run_test test_reject_script_entry_discards_draft

test_done
