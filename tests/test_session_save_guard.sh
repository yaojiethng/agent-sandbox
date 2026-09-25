#!/usr/bin/env bash
# tests/test_session_save_guard.sh
# Unit tests for the session save / autosave no-op guard in
# src/libs/session_save_policy.sh (session_save_needed, save_decision,
# _save_baseline). The module is reached through diff_export.sh, which sources
# it; the SESSION_STATE reader and the .export-status reader are exercised
# through their own libraries.
#
# Covers:
#   session_save_needed  --  the skip decision (dirty tree always saves; clean
#                            tree saves only when HEAD moved past the baseline)
#   _save_baseline       --  resolves the comparison point (last .export-status
#                            HEAD, else init_sha)
#   _write_export_status --  stamps HEAD into .export-status so the next save
#                            has a level-2 baseline
#
# The rule under test: a save runs iff the working tree is dirty (any
# uncommitted/untracked change) OR HEAD differs from BASELINE. It is skipped
# only when the tree is completely clean AND HEAD equals BASELINE.

set -uo pipefail
unset WORKSPACE_DIR_NAME SANDBOX_DIR_NAME CHANGES_DIR_NAME INPUT_DIR_NAME OUTPUT_DIR_NAME

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/git_fixtures.sh"

# source the module under test (git_fixtures is independent)
source "${REPO_ROOT}/src/libs/diff_export.sh"

# -- session_save_needed -----------------------------------------------------

# Given: a sandbox with an uncommitted or untracked change
# When:  session_save_needed runs
# Then:  rc 0 (save)
# Asserts: a dirty tree always saves, whatever the baseline.
test_dirty_tree_always_saves() {
  local fix
  fix=$(get_fixture_dir)
  make_committed_repo "$fix"
  write_session_state "$fix"
  local baseline
  baseline=$(get_init_sha "$fix")

  echo "uncommitted" >> "$fix/file.txt"
  if session_save_needed "$fix" "$baseline"; then
    pass "dirty tree saves (one uncommitted change)"
  else
    fail "dirty tree should always save"
  fi

  echo "more" >> "$fix/file.txt"
  if session_save_needed "$fix" "$baseline"; then
    pass "dirty tree saves regardless of change count (two changes)"
  else
    fail "two uncommitted changes must still save"
  fi

  touch "$fix/untracked.txt"
  if session_save_needed "$fix" "$baseline"; then
    pass "untracked file alone forces a save"
  else
    fail "untracked file must force a save"
  fi

}

# Given: a clean tree at the baseline
# When:  session_save_needed runs
# Then:  rc 1 (skip)
# Asserts: no work since the last save.
test_clean_tree_at_baseline_skips() {
  local fix
  fix=$(get_fixture_dir)
  make_committed_repo "$fix"
  write_session_state "$fix"
  local baseline
  baseline=$(get_init_sha "$fix")   # HEAD == init_sha, tree clean

  local rc=0
  session_save_needed "$fix" "$baseline" || rc=$?
  assert_eq "$rc" "1" "clean tree at baseline reports skip (1), not undeterminable"
}

# Given: a clean tree whose HEAD is past the baseline
# When:  session_save_needed runs
# Then:  rc 0 (save)
# Asserts: new commits force a save even on a clean tree.
test_clean_tree_past_baseline_saves() {
  local fix
  fix=$(get_fixture_dir)
  make_committed_repo "$fix"
  write_session_state "$fix"
  local baseline
  baseline=$(get_init_sha "$fix")

  commit_change "$fix" "second commit"
  # now clean but HEAD != init_sha -- must save (captures the new commit once)
  if session_save_needed "$fix" "$baseline"; then
    pass "clean tree with commits past baseline saves"
  else
    fail "clean tree past baseline must save"
  fi

  # at HEAD (== the new commit) it skips again -- level 2: nothing new
  local new_head rc=0
  new_head=$(git -C "$fix" rev-parse HEAD)
  session_save_needed "$fix" "$new_head" || rc=$?
  assert_eq "$rc" "1" "clean tree at last-saved HEAD reports skip (level 2)"
}

# -- save_decision (the caller-facing dispatch) ------------------------------

# Given: a clean tree at the baseline
# When:  save_decision runs
# Then:  rc 1 and the "nothing to save" diagnostic
# Asserts: the operator-facing skip arm.
test_save_decision_skip_reports_and_returns_1() {
  local fix
  fix=$(get_fixture_dir)
  make_committed_repo "$fix"
  write_session_state "$fix"
  # No prior export dir: the baseline resolves to init_sha, so a clean tree at
  # HEAD means nothing to save.
  local out rc=0
  out=$(save_decision "$fix" "$fix/no-prior-export" "session-export" 2>&1) || rc=$?
  assert_eq "$rc" "1" "save_decision: skip maps to 1"
  assert_contains "$out" "session-export: nothing to save" "save_decision: skip prints the label"
}

# Given: an unreadable repository
# When:  save_decision runs
# Then:  rc 0 and the cannot-read warning
# Asserts: the undeterminable arm saves loudly rather than skipping.
test_save_decision_undeterminable_saves_and_warns() {
  # The defect this guards: a sandbox whose .git cannot be read must not be
  # reported as "nothing to save". save_decision returns 0 (proceed) and says
  # why.
  local fix
  fix=$(get_fixture_dir)
  local out rc=0
  out=$(save_decision "$fix" "$fix/no-prior-export" "session-export" 2>&1) || rc=$?
  assert_eq "$rc" "0" "save_decision: undeterminable maps to 0 (save anyway)"
  assert_contains "$out" "cannot read the sandbox repository" \
      "save_decision: undeterminable says why"
  if [[ "$out" == *"nothing to save"* ]]; then
    fail "save_decision must not report nothing-to-save when git is unreadable"
  else
    pass "save_decision: undeterminable is not reported as nothing to save"
  fi
}

# -- _save_baseline ----------------------------------------------------------

# Given: no successful export in the export directory
# When:  _save_baseline runs
# Then:  the recorded init_sha is the baseline
# Asserts: the first-save level.
test_baseline_falls_back_to_init_sha() {
  local fix
  fix=$(get_fixture_dir)
  make_committed_repo "$fix"
  write_session_state "$fix"
  local expect
  expect=$(get_init_sha "$fix")

  local out
  out=$(_save_baseline "$fix" "$fix/nonexistent-dir")
  assert_eq "$out" "$expect" "_save_baseline falls back to init_sha when no prior export"
}

# Given: a successful export whose record carries a HEAD line
# When:  _save_baseline runs
# Then:  that HEAD is the baseline
# Asserts: the last-saved level.
test_baseline_reads_last_export_head() {
  local fix
  fix=$(get_fixture_dir)
  make_committed_repo "$fix"
  write_session_state "$fix"

  local exp_dir="$fix/prior"
  mkdir -p "$exp_dir"
  # a previous successful export recorded a HEAD that is not init_sha
  _write_export_status "$exp_dir" "SUCCESS" "20260622-120000" "0" "$(get_init_sha "$fix")" "deadbeefcafe"

  local out
  out=$(_save_baseline "$fix" "$exp_dir")
  assert_eq "$out" "deadbeefcafe" "_save_baseline uses last saved HEAD over init_sha"
}

# Given: a failed export that nevertheless carries a HEAD line
# When:  _save_baseline runs
# Then:  the baseline falls back to init_sha
# Asserts: only a successful export moves the baseline.
test_baseline_ignores_failed_export() {
  local fix
  fix=$(get_fixture_dir)
  make_committed_repo "$fix"
  write_session_state "$fix"
  local expect
  expect=$(get_init_sha "$fix")

  local exp_dir="$fix/prior"
  mkdir -p "$exp_dir"
  _write_export_status "$exp_dir" "FAIL" "20260622-120000" "1" "$(get_init_sha "$fix")" "deadbeefcafe"

  local out
  out=$(_save_baseline "$fix" "$exp_dir")
  assert_eq "$out" "$expect" "_save_baseline falls back to init_sha when prior export FAILed"
}

# -- _write_export_status stamps HEAD ----------------------------------------

# Given: an export with INIT_SHA and HEAD
# When:  _write_export_status runs
# Then:  the file has HEAD and INIT_SHA
# Asserts: the next save's comparison point is stamped.
test_export_status_stamps_head() {
  local _tmpdir
  _tmpdir=$(get_fixture_dir)
  _write_export_status "$_tmpdir" "SUCCESS" "20260622-120000" "0" "init1234" "head5678"
  local _content
  _content=$(cat "$_tmpdir/.export-status")
  assert_contains "$_content" "HEAD=head5678" "_write_export_status stamps HEAD given as 6th arg"
  assert_contains "$_content" "INIT_SHA=init1234" "_write_export_status keeps INIT_SHA"
}

# Given: an export with no HEAD
# When:  _write_export_status runs
# Then:  the file has no HEAD line
# Asserts: an absent HEAD is omitted.
test_export_status_no_head_when_empty() {
  local _tmpdir
  _tmpdir=$(get_fixture_dir)
  _write_export_status "$_tmpdir" "SUCCESS" "20260622-120000" "0" "init1234"
  local _content
  _content=$(cat "$_tmpdir/.export-status")
  if [[ "$_content" == *"HEAD="* ]]; then
    fail "_write_export_status should omit empty HEAD"
  else
    pass "_write_export_status omits HEAD when absent"
  fi
}

# Given: a repository git cannot read
# When:  session_save_needed runs
# Then:  rc 2 (undeterminable), never the skip code
# Asserts: a broken sandbox is not reported as nothing to save.
test_unreadable_repository_is_undeterminable() {
  # A sandbox whose .git cannot be read must not look like "nothing to save".
  # Returns 2 (undeterminable) so the caller saves or fails loudly instead of
  # reporting a clean tree.
  local fix
  fix=$(get_fixture_dir)
  local rc=0
  session_save_needed "$fix" "whatever" || rc=$?
  assert_eq "$rc" "2" "non-repository path: undeterminable, not skip"

  # Corrupt .git: present but not a valid repository.
  mkdir -p "$fix/.git"
  rc=0
  session_save_needed "$fix" "whatever" || rc=$?
  assert_eq "$rc" "2" "corrupt .git: undeterminable, not skip"
}

# -- export_status_read / export_status_is_success ---------------------------

# Given: a written .export-status
# When:  export_status_read is called per key
# Then:  STATUS/HEAD/TIMESTAMP return, and an absent key or file return empty
# Asserts: the single reader for the file format.
test_export_status_read_fields() {
  local fix
  fix=$(get_fixture_dir)
  _write_export_status "$fix" "SUCCESS" "20260622-120000" "0" "initsha" "headsha"
  assert_eq "$(export_status_read "$fix" STATUS)" "SUCCESS" "reader returns the STATUS field"
  assert_eq "$(export_status_read "$fix" HEAD)" "headsha" "reader returns the HEAD field"
  assert_eq "$(export_status_read "$fix" TIMESTAMP)" "20260622-120000" "reader returns the TIMESTAMP field"
  assert_empty "$(export_status_read "$fix" NOPE)" "reader returns empty for an absent key"
  assert_eq "$(export_status_read "$fix/nonexistent" STATUS)" "" "reader returns empty for an absent file"
}

# Given: a SUCCESS record, then a FAIL record, then an absent file
# When:  export_status_is_success runs
# Then:  true, then false, then false
# Asserts: success is exactly STATUS=SUCCESS.
test_export_status_is_success() {
  local fix
  fix=$(get_fixture_dir)
  _write_export_status "$fix" "SUCCESS" "20260622-120000" "0" "initsha" "headsha"
  if export_status_is_success "$fix"; then
    pass "is_success: true for a SUCCESS record"
  else
    fail "is_success must be true for SUCCESS"
  fi
  _write_export_status "$fix" "FAIL" "20260622-120001" "1" "initsha"
  if export_status_is_success "$fix"; then
    fail "is_success must be false for FAIL"
  else
    pass "is_success: false for a FAIL record"
  fi
  if export_status_is_success "$fix/nonexistent"; then
    fail "is_success must be false for an absent file"
  else
    pass "is_success: false when the file is absent"
  fi
}

# Given: a dirty tree
# When:  save_decision runs
# Then:  rc 0 and no diagnostic
# Asserts: the save arm is silent.
test_save_decision_save_arm_is_silent_and_returns_0() {
  local fix
  fix=$(get_fixture_dir)
  make_committed_repo "$fix"
  write_session_state "$fix"
  echo "dirty" >> "$fix/file.txt"
  local out rc=0
  out=$(save_decision "$fix" "$fix/no-prior-export" "session-export" 2>&1) || rc=$?
  assert_eq "$rc" "0" "save_decision: dirty tree maps to 0 (save)"
  assert_empty "$out" "save_decision: the save arm prints nothing"
}

# -- require_clean_working_tree ---------------------------------------------

# Given: a directory with no repository, a clean committed repository, and that repository made dirty
# When:  require_clean_working_tree runs for each
# Then:  it returns 2 for the unreadable tree, 0 for the clean one, and 1 for the dirty one, and prints nothing
# Asserts: the three-valued verdict callers must not collapse, and the caller owns the message.
test_clean_tree_guard_is_three_valued() {
  source "$REPO_ROOT/scripts/guards.sh"
  local fix
  fix=$(get_fixture_dir)

  # Unreadable: no repository at all.
  local rc=0
  require_clean_working_tree "$fix" || rc=$?
  assert_eq "$rc" "2" "guard: an unreadable tree reports undeterminable (2)"

  make_committed_repo "$fix"
  rc=0
  require_clean_working_tree "$fix" || rc=$?
  assert_eq "$rc" "0" "guard: a clean tree reports clean (0)"

  echo "dirty" >> "$fix/file.txt"
  rc=0
  require_clean_working_tree "$fix" || rc=$?
  assert_eq "$rc" "1" "guard: a dirty tree reports dirty (1)"
}

# -- session_export_needed (exit-time durable-record decision) --------------

# Given: work since the branch point, committed or uncommitted
# When:  session_export_needed runs
# Then:  rc 0 (run)
# Asserts: an ephemeral autosave never suppresses the durable exit export.
test_session_export_runs_with_work_despite_committed_or_uncommitted() {
  local fix
  fix=$(get_fixture_dir)
  make_committed_repo "$fix"
  write_session_state "$fix"

  # one committed change past the branch point
  commit_change "$fix" "second commit"
  local rc=0
  session_export_needed "$fix" || rc=$?
  assert_eq "$rc" "0" "session export runs after a committed change"

  # one uncommitted change
  echo dirty >> "$fix/file.txt"
  rc=0
  session_export_needed "$fix" || rc=$?
  assert_eq "$rc" "0" "session export runs with an uncommitted change"

  # a current autosave dir must not suppress it (the reported defect)
  mkdir -p "$fix/changes/autosave/s-x"
  rc=0
  session_export_needed "$fix" || rc=$?
  assert_eq "$rc" "0" "session export runs when an autosave already captured the state"
}

# Given: a clean tree at the branch point
# When:  session_export_needed runs
# Then:  rc 1 (skip)
# Asserts: no work at all means no exit export.
test_session_export_skips_clean_tree_at_branch_point() {
  local fix
  fix=$(get_fixture_dir)
  make_committed_repo "$fix"
  write_session_state "$fix"

  local rc=99
  session_export_needed "$fix" || rc=$?
  assert_eq "$rc" "1" "session export skips a clean tree at the branch point"
}

# -- run ---------------------------------------------------------------------

run_test test_dirty_tree_always_saves
run_test test_clean_tree_at_baseline_skips
run_test test_clean_tree_past_baseline_saves
run_test test_unreadable_repository_is_undeterminable
run_test test_save_decision_skip_reports_and_returns_1
run_test test_save_decision_undeterminable_saves_and_warns
run_test test_baseline_falls_back_to_init_sha
run_test test_baseline_reads_last_export_head
run_test test_baseline_ignores_failed_export
run_test test_export_status_read_fields
run_test test_export_status_is_success
run_test test_export_status_stamps_head
run_test test_save_decision_save_arm_is_silent_and_returns_0
run_test test_clean_tree_guard_is_three_valued
run_test test_export_status_no_head_when_empty
run_test test_session_export_runs_with_work_despite_committed_or_uncommitted
run_test test_session_export_skips_clean_tree_at_branch_point

test_done