#!/usr/bin/env bash
# Tests for libs/diff_export.sh  --  reliability features
#
# Covers:
#   _write_export_status     --  writes correct SUCCESS/FAIL content atomically
#   _write_export_error_log  --  creates timestamped error log files
#   wait_git_lockfile        --  polls for git index.lock with timeout
#   diff_export failure      --  error log + .export-status on package_branch failure

set -uo pipefail

# Ensure env overrides don't leak from outside the test suite
unset WORKSPACE_DIR_NAME
unset SANDBOX_DIR_NAME
unset CHANGES_DIR_NAME INPUT_DIR_NAME OUTPUT_DIR_NAME

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

# Source the module under test
source "${REPO_ROOT}/src/libs/diff_export.sh"

# ---------------------------------------------------------------------------
# _write_export_status
# ---------------------------------------------------------------------------

test_export_status_writes_success() {
  local _tmpdir
  _tmpdir=$(mktemp -d) || { fail "mktemp failed"; return; }

  _write_export_status "$_tmpdir" "SUCCESS" "20260622-120000" "0" "abc123"

  if [[ ! -f "$_tmpdir/.export-status" ]]; then
    rm -rf "$_tmpdir"
    fail ".export-status not created"
    return
  fi

  local _content
  _content=$(cat "$_tmpdir/.export-status")
  rm -rf "$_tmpdir"

  if [[ "$_content" == *"STATUS=SUCCESS"* ]] && [[ "$_content" == *"TIMESTAMP=20260622-120000"* ]]; then
    pass "_write_export_status writes SUCCESS with timestamp"
  else
    fail "_write_export_status: expected SUCCESS content, got: $_content"
  fi
}

test_export_status_includes_init_sha() {
  local _tmpdir
  _tmpdir=$(mktemp -d) || { fail "mktemp failed"; return; }

  _write_export_status "$_tmpdir" "SUCCESS" "20260622-120000" "0" "abc123def456"

  local _content
  _content=$(cat "$_tmpdir/.export-status")
  rm -rf "$_tmpdir"

  if [[ "$_content" == *"INIT_SHA=abc123def456"* ]]; then
    pass "_write_export_status includes INIT_SHA when provided"
  else
    fail "_write_export_status: expected INIT_SHA, got: $_content"
  fi
}

test_export_status_omits_init_sha_when_empty() {
  local _tmpdir
  _tmpdir=$(mktemp -d) || { fail "mktemp failed"; return; }

  _write_export_status "$_tmpdir" "SUCCESS" "20260622-120000" "0" ""

  local _content
  _content=$(cat "$_tmpdir/.export-status")
  rm -rf "$_tmpdir"

  if [[ "$_content" != *"INIT_SHA"* ]]; then
    pass "_write_export_status omits INIT_SHA when empty"
  else
    fail "_write_export_status: should not include empty INIT_SHA"
  fi
}

test_export_status_writes_failure_with_exit_code() {
  local _tmpdir
  _tmpdir=$(mktemp -d) || { fail "mktemp failed"; return; }

  _write_export_status "$_tmpdir" "FAIL" "20260622-120001" "1"

  local _content
  _content=$(cat "$_tmpdir/.export-status")
  rm -rf "$_tmpdir"

  if [[ "$_content" == *"STATUS=FAIL"* ]] && [[ "$_content" == *"EXIT_CODE=1"* ]]; then
    pass "_write_export_status writes FAIL with exit code"
  else
    fail "_write_export_status: expected FAIL+EXIT_CODE, got: $_content"
  fi
}

test_export_status_does_not_include_exit_code_on_success() {
  local _tmpdir
  _tmpdir=$(mktemp -d) || { fail "mktemp failed"; return; }

  _write_export_status "$_tmpdir" "SUCCESS" "20260622-120002" "0"

  local _content
  _content=$(cat "$_tmpdir/.export-status")
  rm -rf "$_tmpdir"

  if [[ "$_content" != *"EXIT_CODE"* ]]; then
    pass "_write_export_status omits EXIT_CODE for SUCCESS"
  else
    fail "_write_export_status: EXIT_CODE present in SUCCESS status"
  fi
}

# ---------------------------------------------------------------------------
# _write_export_error_log
# ---------------------------------------------------------------------------

test_export_error_log_creates_file() {
  local _tmpdir
  _tmpdir=$(mktemp -d) || { fail "mktemp failed"; return; }

  _write_export_error_log "$_tmpdir" "20260622-120000" "" "1" "" "package_branch failed"

  # Should create 20260622-120000-EXPORT-ERROR.log
  local _files
  _files=$(ls "$_tmpdir" 2>/dev/null) || true
  rm -rf "$_tmpdir"

  if [[ "$_files" == *"20260622-120000-EXPORT-ERROR.log"* ]]; then
    pass "_write_export_error_log creates correctly named file"
  else
    fail "_write_export_error_log: expected 20260622-120000-EXPORT-ERROR.log, got: $_files"
  fi
}

test_export_error_log_includes_session_id() {
  local _tmpdir
  _tmpdir=$(mktemp -d) || { fail "mktemp failed"; return; }

  _write_export_error_log "$_tmpdir" "20260622-120000" "abc123" "2" "" "test error"

  local _files
  _files=$(ls "$_tmpdir" 2>/dev/null) || true
  rm -rf "$_tmpdir"

  if [[ "$_files" == *"20260622-120000-abc123-EXPORT-ERROR.log"* ]]; then
    pass "_write_export_error_log embeds SESSION_ID in filename"
  else
    fail "_write_export_error_log: expected SESSION_ID in filename, got: $_files"
  fi
}

test_export_error_log_contains_error_details() {
  local _tmpdir
  _tmpdir=$(mktemp -d) || { fail "mktemp failed"; return; }

  _write_export_error_log "$_tmpdir" "20260622-120000" "abc123" "2" "stderr line 1" "test error"

  local _content
  _content=$(cat "$_tmpdir/20260622-120000-abc123-EXPORT-ERROR.log")
  rm -rf "$_tmpdir"

  if [[ "$_content" == *"EXIT_CODE=2"* ]] && [[ "$_content" == *"SESSION_ID=abc123"* ]] && [[ "$_content" == *"stderr line 1"* ]]; then
    pass "_write_export_error_log contains exit code, run id, and stderr"
  else
    fail "_write_export_error_log: missing expected fields, got: $_content"
  fi
}

# ---------------------------------------------------------------------------
# wait_git_lockfile
# ---------------------------------------------------------------------------

test_wait_git_lockfile_no_lockfile() {
  local _tmpdir
  _tmpdir=$(mktemp -d) || { fail "mktemp failed"; return; }
  mkdir -p "$_tmpdir/.git"

  if wait_git_lockfile "$_tmpdir"; then
    pass "wait_git_lockfile returns 0 when no lockfile present"
  else
    fail "wait_git_lockfile: expected 0 with no lockfile"
  fi
  rm -rf "$_tmpdir"
}

test_wait_git_lockfile_lockfile_appears_and_disappears() {
  local _tmpdir
  _tmpdir=$(mktemp -d) || { fail "mktemp failed"; return; }
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
  rm -rf "$_tmpdir"
}

test_wait_git_lockfile_timeout() {
  local _tmpdir
  _tmpdir=$(mktemp -d) || { fail "mktemp failed"; return; }
  mkdir -p "$_tmpdir/.git"

  # Create lockfile that never disappears
  touch "$_tmpdir/.git/index.lock"

  if wait_git_lockfile "$_tmpdir" "1"; then
    rm -rf "$_tmpdir"
    fail "wait_git_lockfile: expected 1 on timeout"
  else
    pass "wait_git_lockfile returns 1 on timeout"
  fi
  rm -rf "$_tmpdir"
}

test_wait_git_lockfile_timeout_message() {
  local _tmpdir
  _tmpdir=$(mktemp -d) || { fail "mktemp failed"; return; }
  mkdir -p "$_tmpdir/.git"

  touch "$_tmpdir/.git/index.lock"

  local _output
  _output=$(wait_git_lockfile "$_tmpdir" "1" 2>&1) || true

  rm -rf "$_tmpdir"

  if [[ "$_output" == *"lockfile persisted"* ]]; then
    pass "wait_git_lockfile warns on timeout"
  else
    fail "wait_git_lockfile: expected warning on timeout, got: $_output"
  fi
}

# ---------------------------------------------------------------------------
# diff_export error path
# ---------------------------------------------------------------------------

# Test that diff_export writes .export-status on failure when package_branch
# cannot run (e.g., SANDBOX_DIR not a git repo, which is a common failure).
# Note: this tests the error handling in diff_export itself, not the
# package_branch internal logic (which is covered by test_package_branch.sh).
test_diff_export_failure_writes_export_status() {
  local _tmpdir
  _tmpdir=$(mktemp -d) || { fail "mktemp failed"; return; }
  local _outdir="$_tmpdir/out"
  mkdir -p "$_outdir"

  # SANDBOX_DIR without .git  --  package_branch will fail
  local _bad_sandbox="$_tmpdir/nogit"
  mkdir -p "$_bad_sandbox"

  if diff_export "$_bad_sandbox" "$_outdir" "test123"; then
    rm -rf "$_tmpdir"
    fail "diff_export: expected non-zero exit on bad sandbox"
    return
  fi

  if [[ ! -f "$_outdir/.export-status" ]]; then
    rm -rf "$_tmpdir"
    fail "diff_export: .export-status not created on failure"
    return
  fi

  local _content
  _content=$(cat "$_outdir/.export-status")
  rm -rf "$_tmpdir"

  if [[ "$_content" == *"STATUS=FAIL"* ]]; then
    pass "diff_export failure writes FAIL export status"
  else
    fail "diff_export failure: expected FAIL status, got: $_content"
  fi
}

test_diff_export_failure_writes_error_log() {
  local _tmpdir
  _tmpdir=$(mktemp -d) || { fail "mktemp failed"; return; }
  local _outdir="$_tmpdir/out"
  mkdir -p "$_outdir"

  local _bad_sandbox="$_tmpdir/nogit"
  mkdir -p "$_bad_sandbox"

  diff_export "$_bad_sandbox" "$_outdir" "test123" || true

  # Should have an error log file with SESSION_ID
  local _files
  _files=$(ls "$_outdir" 2>/dev/null) || true
  rm -rf "$_tmpdir"

  if [[ "$_files" == *"EXPORT-ERROR.log"* ]]; then
    pass "diff_export failure writes error log"
  else
    fail "diff_export failure: expected error log, got: $_files"
  fi
}

# ---------------------------------------------------------------------------

run_test test_export_status_writes_success
run_test test_export_status_writes_failure_with_exit_code
run_test test_export_status_does_not_include_exit_code_on_success
run_test test_export_status_includes_init_sha
run_test test_export_status_omits_init_sha_when_empty
run_test test_export_error_log_creates_file
run_test test_export_error_log_includes_session_id
run_test test_export_error_log_contains_error_details
run_test test_wait_git_lockfile_no_lockfile
run_test test_wait_git_lockfile_lockfile_appears_and_disappears
run_test test_wait_git_lockfile_timeout
run_test test_wait_git_lockfile_timeout_message
run_test test_diff_export_failure_writes_export_status
run_test test_diff_export_failure_writes_error_log

test_done
