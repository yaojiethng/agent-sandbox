#!/usr/bin/env bash
# Tests for libs/diff_export.sh  --  reliability features
#
# Covers:
#   _write_export_error_log  --  creates timestamped error log files with all fields
#   wait_git_lockfile        --  polls for git index.lock, full timeout budget
#   diff_export failure      --  error log + .export-status on package_branch failure
#   diff_export success      --  rc 0 and the SUCCESS status record

set -uo pipefail

# Ensure env overrides don't leak from outside the test suite
unset WORKSPACE_DIR_NAME
unset SANDBOX_DIR_NAME
unset CHANGES_DIR_NAME INPUT_DIR_NAME OUTPUT_DIR_NAME

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

# Source the module under test
source "${REPO_ROOT}/src/libs/diff_export.sh"
source "$TEST_DIR/libs/git_fixtures.sh"

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# _write_export_error_log
# ---------------------------------------------------------------------------

# Given: an output directory and a timestamp
# When:  _write_export_error_log runs
# Then:  the log file exists in that directory
# Asserts: the writer creates its file.
test_export_error_log_creates_file() {
  local _tmpdir
  _tmpdir=$(get_fixture_dir)

  _write_export_error_log "$_tmpdir" "20260622-120000" "" "1" "" "package_branch failed"

  # Should create 20260622-120000-EXPORT-ERROR.log
  local _files
  _files=$(ls "$_tmpdir" 2>/dev/null) || true

  assert_contains "$_files" "20260622-120000-EXPORT-ERROR.log" "_write_export_error_log creates correctly named file"
}

# Given: a session id
# When:  _write_export_error_log runs
# Then:  the filename carries `-<SESSION_ID>` before `-EXPORT-ERROR.log`
# Asserts: the filename contract that ties a failed export to its container.
test_export_error_log_includes_session_id() {
  local _tmpdir
  _tmpdir=$(get_fixture_dir)

  _write_export_error_log "$_tmpdir" "20260622-120000" "abc123" "2" "" "test error"

  local _files
  _files=$(ls "$_tmpdir" 2>/dev/null) || true

  assert_contains "$_files" "20260622-120000-abc123-EXPORT-ERROR.log" "_write_export_error_log embeds SESSION_ID in filename"
}

# Given: an exit code, a session id, and a captured stderr dump
# When:  _write_export_error_log runs
# Then:  the log carries EXIT_CODE, SESSION_ID, and a STDERR section
# Asserts: the log's content contract. The SUMMARY line has no assertion (finding 71).
test_export_error_log_contains_error_details() {
  local _tmpdir
  _tmpdir=$(get_fixture_dir)

  _write_export_error_log "$_tmpdir" "20260622-120000" "abc123" "2" "stderr line 1" "test error"

  local _content
  _content=$(cat "$_tmpdir/20260622-120000-abc123-EXPORT-ERROR.log")

  if [[ "$_content" == *"EXIT_CODE=2"* ]] && [[ "$_content" == *"SESSION_ID=abc123"* ]] && [[ "$_content" == *"stderr line 1"* ]]; then
    pass "_write_export_error_log contains exit code, run id, and stderr"
  else
    fail "_write_export_error_log: missing expected fields, got: $_content"
  fi
}

# Given: an exit code and a summary
# When:  _write_export_error_log runs
# Then:  the log carries the SUMMARY line with its text
# Asserts: the summary field that carries the operator-facing cause.
test_export_error_log_includes_summary() {
  local _tmpdir
  _tmpdir=$(get_fixture_dir)

  _write_export_error_log "$_tmpdir" "20260622-120000" "abc123" "2" "stderr line 1" "package_branch returned exit 2"

  local _content
  _content=$(cat "$_tmpdir/20260622-120000-abc123-EXPORT-ERROR.log")

  assert_contains "$_content" "SUMMARY=package_branch returned exit 2" "_write_export_error_log writes the SUMMARY line"
}

# ---------------------------------------------------------------------------
# wait_git_lockfile
# ---------------------------------------------------------------------------

# Given: no .git/index.lock
# When:  wait_git_lockfile runs
# Then:  rc 0, immediately
# Asserts: the no-contention path.
test_wait_git_lockfile_no_lockfile() {
  local _tmpdir
  _tmpdir=$(get_fixture_dir)
  mkdir -p "$_tmpdir/.git"

  if wait_git_lockfile "$_tmpdir"; then
    pass "wait_git_lockfile returns 0 when no lockfile present"
  else
    fail "wait_git_lockfile: expected 0 with no lockfile"
  fi
}

# Given: a lockfile that a background writer releases within the timeout
# When:  wait_git_lockfile runs
# Then:  rc 0 once the file is gone
# Asserts: the poll loop observes the release.
test_wait_git_lockfile_lockfile_appears_and_disappears() {
  local _tmpdir
  _tmpdir=$(get_fixture_dir)
  mkdir -p "$_tmpdir/.git"

  # Create lockfile, then remove it after a short delay (simulating
  # a concurrent git operation completing)
  local _lockfile="$_tmpdir/.git/index.lock"
  touch "$_lockfile"
  (
    sleep 0.3
    rm -f "$_lockfile"
  ) &

  if wait_git_lockfile "$_tmpdir" "3"; then
    pass "wait_git_lockfile returns 0 when lockfile is released within timeout"
  else
    fail "wait_git_lockfile: expected 0 when lockfile is released"
  fi
}

# Given: a lockfile that never clears
# When:  wait_git_lockfile runs with a short timeout
# Then:  rc 1
# Asserts: the timeout verdict, but not the wall-clock budget (finding 70).
test_wait_git_lockfile_timeout() {
  local _tmpdir
  _tmpdir=$(get_fixture_dir)
  mkdir -p "$_tmpdir/.git"

  # Create lockfile that never disappears
  touch "$_tmpdir/.git/index.lock"

  if wait_git_lockfile "$_tmpdir" "1"; then
    fail "wait_git_lockfile: expected 1 on timeout"
  else
    pass "wait_git_lockfile returns 1 on timeout"
  fi
}

# Given: a lockfile that never clears
# When:  wait_git_lockfile runs
# Then:  the timeout diagnostic names the timeout and says it proceeds anyway
# Asserts: the operator-facing wording of the give-up path.
test_wait_git_lockfile_timeout_message() {
  local _tmpdir
  _tmpdir=$(get_fixture_dir)
  mkdir -p "$_tmpdir/.git"

  touch "$_tmpdir/.git/index.lock"

  local _output
  _output=$(wait_git_lockfile "$_tmpdir" "1" 2>&1) || true


  assert_contains "$_output" "lockfile persisted" "wait_git_lockfile warns on timeout"
}

# Given: a persistent lockfile and a stubbed sleep
# When:  wait_git_lockfile runs with a timeout
# Then:  it polls once per 200ms tick for the whole timeout and returns 1
# Asserts: the poll budget, which the timeout verdict alone does not pin.
test_wait_git_lockfile_polls_for_the_full_timeout() {
  local _tmpdir
  _tmpdir=$(get_fixture_dir)
  mkdir -p "$_tmpdir/.git"
  touch "$_tmpdir/.git/index.lock"

  local _sleep_count=0
  sleep() { _sleep_count=$((_sleep_count + 1)); }
  local RC=0
  wait_git_lockfile "$_tmpdir" "3" >/dev/null 2>&1 || RC=$?

  if [[ $RC -eq 1 && "$_sleep_count" -eq 15 ]]; then
    pass "wait_git_lockfile polls five times per second for the requested timeout"
  else
    fail "wait_git_lockfile poll budget wrong: rc=$RC polls=$_sleep_count (want 15)"
  fi
}

# Given: a valid sandbox and an output directory
# When:  diff_export runs
# Then:  it returns 0 and stamps STATUS=SUCCESS in .export-status
# Asserts: the success path's own return value, which is the last status write.
test_diff_export_success_returns_zero() {
  local DIR="$FIXTURE_DIR/de_success"
  local OUT="$FIXTURE_DIR/de_success_out"
  mkdir -p "$OUT"
  make_sandbox_fixture "$DIR" >/dev/null
  commit_change "$DIR" "agent commit"

  local RC=0
  diff_export "$DIR" "$OUT" "" >/dev/null 2>&1 || RC=$?

  local _status="" _head_present=false
  if [[ -f "$OUT/.export-status" ]]; then
    _status=$(grep '^STATUS=' "$OUT/.export-status" | cut -d= -f2)
    grep -q '^HEAD=' "$OUT/.export-status" && _head_present=true
  fi
  if [[ $RC -eq 0 && "$_status" == "SUCCESS" && "$_head_present" == true ]]; then
    pass "diff_export returns 0 and records SUCCESS with the HEAD field"
  else
    fail "diff_export success path wrong: rc=$RC status='$_status' head=$_head_present"
  fi
}

# ---------------------------------------------------------------------------
# diff_export error path
# ---------------------------------------------------------------------------

# Test that diff_export writes .export-status on failure when package_branch
# cannot run (e.g., SANDBOX_DIR not a git repo, which is a common failure).
# Note: this tests the error handling in diff_export itself, not the
# package_branch internal logic (which is covered by test_package_branch.sh).
# Given: a package_branch that fails
# When:  diff_export runs
# Then:  .export-status records FAIL with the exit code, and the call returns that code
# Asserts: the failure record, which is the only machine-readable signal of a failed export.
# Note: a failure that happens inside a successful-looking package_branch is not covered (finding 68).
test_diff_export_failure_writes_export_status() {
  local _tmpdir
  _tmpdir=$(get_fixture_dir)
  local _outdir="$_tmpdir/out"
  mkdir -p "$_outdir"

  # SANDBOX_DIR without .git  --  package_branch will fail
  local _bad_sandbox="$_tmpdir/nogit"
  mkdir -p "$_bad_sandbox"

  if diff_export "$_bad_sandbox" "$_outdir" "test123"; then
    fail "diff_export: expected non-zero exit on bad sandbox"
    return
  fi

  if [[ ! -f "$_outdir/.export-status" ]]; then
    fail "diff_export: .export-status not created on failure"
    return
  fi

  local _content
  _content=$(cat "$_outdir/.export-status")

  assert_contains "$_content" "STATUS=FAIL" "diff_export failure writes FAIL export status"
}

# Given: a package_branch that fails, and an output directory that exists
# When:  diff_export runs
# Then:  a timestamped EXPORT-ERROR.log is written
# Asserts: the diagnostic artifact exists.
# Note: the unit's failure occurs before the callee wipes OUTPUT_DIR, so the log still carries the
#       captured stderr; a post-wipe failure does not (finding 69).
test_diff_export_failure_writes_error_log() {
  local _tmpdir
  _tmpdir=$(get_fixture_dir)
  local _outdir="$_tmpdir/out"
  mkdir -p "$_outdir"

  local _bad_sandbox="$_tmpdir/nogit"
  mkdir -p "$_bad_sandbox"

  diff_export "$_bad_sandbox" "$_outdir" "test123" || true

  # Should have an error log file with SESSION_ID
  local _files
  _files=$(ls "$_outdir" 2>/dev/null) || true

  assert_contains "$_files" "EXPORT-ERROR.log" "diff_export failure writes error log"
}

# ---------------------------------------------------------------------------

run_test test_export_error_log_creates_file
run_test test_export_error_log_includes_session_id
run_test test_export_error_log_contains_error_details
run_test test_export_error_log_includes_summary
run_test test_wait_git_lockfile_no_lockfile
run_test test_wait_git_lockfile_lockfile_appears_and_disappears
run_test test_wait_git_lockfile_timeout
run_test test_wait_git_lockfile_timeout_message
run_test test_wait_git_lockfile_polls_for_the_full_timeout
run_test test_diff_export_failure_writes_export_status
run_test test_diff_export_failure_writes_error_log
run_test test_diff_export_success_returns_zero

test_done

