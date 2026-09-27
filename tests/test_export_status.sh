#!/usr/bin/env bash
# tests/test_export_status.sh
# Unit tests for src/libs/export_status.sh  --  the .export-status record:
# the writer `_write_export_status` and the readers `export_status_read` and
# `export_status_is_success`. The diff-export suite and the session-save suite
# both consume the record, so their units for it lived in those files until
# this file existed.

set -uo pipefail

# Ensure env overrides do not leak from outside the test suite
unset WORKSPACE_DIR_NAME
unset SANDBOX_DIR_NAME
unset CHANGES_DIR_NAME INPUT_DIR_NAME OUTPUT_DIR_NAME

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "${REPO_ROOT}/src/libs/export_status.sh"

# _write_export_status
# ---------------------------------------------------------------------------

# Given: a SUCCESS export with a timestamp and exit code 0
# When:  _write_export_status runs
# Then:  the file contains STATUS=SUCCESS and the timestamp
# Asserts: the success content shape.
test_export_status_writes_success() {
  local _tmpdir
  _tmpdir=$(get_fixture_dir)

  _write_export_status "$_tmpdir" "SUCCESS" "20260622-120000" "0" "abc123"

  if [[ ! -f "$_tmpdir/.export-status" ]]; then
    fail ".export-status not created"
    return
  fi

  local _content
  _content=$(cat "$_tmpdir/.export-status")

  if [[ "$_content" == *"STATUS=SUCCESS"* ]] && [[ "$_content" == *"TIMESTAMP=20260622-120000"* ]]; then
    pass "_write_export_status writes SUCCESS with timestamp"
  else
    fail "_write_export_status: expected SUCCESS content, got: $_content"
  fi
}

# Given: a non-empty INIT_SHA
# When:  _write_export_status runs
# Then:  the file contains INIT_SHA
# Asserts: INIT_SHA is stamped when provided.
test_export_status_includes_init_sha() {
  local _tmpdir
  _tmpdir=$(get_fixture_dir)

  _write_export_status "$_tmpdir" "SUCCESS" "20260622-120000" "0" "abc123def456"

  local _content
  _content=$(cat "$_tmpdir/.export-status")

  assert_contains "$_content" "INIT_SHA=abc123def456" "_write_export_status includes INIT_SHA when provided"
}

# Given: an empty INIT_SHA
# When:  _write_export_status runs
# Then:  the file has no INIT_SHA line
# Asserts: an empty INIT_SHA is omitted.
test_export_status_omits_init_sha_when_empty() {
  local _tmpdir
  _tmpdir=$(get_fixture_dir)

  _write_export_status "$_tmpdir" "SUCCESS" "20260622-120000" "0" ""

  local _content
  _content=$(cat "$_tmpdir/.export-status")

  if [[ "$_content" != *"INIT_SHA"* ]]; then
    pass "_write_export_status omits INIT_SHA when empty"
  else
    fail "_write_export_status: should not include empty INIT_SHA"
  fi
}

# Given: a FAIL export with exit code 1
# When:  _write_export_status runs
# Then:  the file contains STATUS=FAIL and EXIT_CODE=1
# Asserts: a failure records its exit code.
test_export_status_writes_failure_with_exit_code() {
  local _tmpdir
  _tmpdir=$(get_fixture_dir)

  _write_export_status "$_tmpdir" "FAIL" "20260622-120001" "1"

  local _content
  _content=$(cat "$_tmpdir/.export-status")

  if [[ "$_content" == *"STATUS=FAIL"* ]] && [[ "$_content" == *"EXIT_CODE=1"* ]]; then
    pass "_write_export_status writes FAIL with exit code"
  else
    fail "_write_export_status: expected FAIL+EXIT_CODE, got: $_content"
  fi
}

# Given: a SUCCESS export with exit code 0
# When:  _write_export_status runs
# Then:  the file has no EXIT_CODE line
# Asserts: exit code 0 is omitted.
test_export_status_does_not_include_exit_code_on_success() {
  local _tmpdir
  _tmpdir=$(get_fixture_dir)

  _write_export_status "$_tmpdir" "SUCCESS" "20260622-120002" "0"

  local _content
  _content=$(cat "$_tmpdir/.export-status")

  if [[ "$_content" != *"EXIT_CODE"* ]]; then
    pass "_write_export_status omits EXIT_CODE for SUCCESS"
  else
    fail "_write_export_status: EXIT_CODE present in SUCCESS status"
  fi
}

# ---------------------------------------------------------------------------
# HEAD stamping
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# export_status_read / export_status_is_success
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Run all
# ---------------------------------------------------------------------------

run_test test_export_status_writes_success
run_test test_export_status_includes_init_sha
run_test test_export_status_omits_init_sha_when_empty
run_test test_export_status_writes_failure_with_exit_code
run_test test_export_status_does_not_include_exit_code_on_success
run_test test_export_status_stamps_head
run_test test_export_status_no_head_when_empty
run_test test_export_status_read_fields
run_test test_export_status_is_success

test_done test_export_status.sh
