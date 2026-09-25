#!/usr/bin/env bash
# tests/test_common_lib.sh
# Unit tests for libs/common.sh  --  shared flag parsing and validation.
#
# Covers:
#   parse_help_flag     --  detects --help and -h; passes through other args
#   sandbox_dir_canon   --  resolves a sandbox path spelling to its canonical form
#   check_base_flags    --  validates required flags, rejects empty/slash paths

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/common.sh"

# ---------------------------------------------------------------------------
# parse_help_flag
# ---------------------------------------------------------------------------

# Given: the argument --help
# When:  parse_help_flag runs
# Then:  usage is called
# Asserts: long help flag dispatch.
test_help_flag_detected() {
  # parse_help_flag calls usage() and exit  --  mock those to avoid aborting
  usage() { echo "usage called"; }
  local OUTPUT
  OUTPUT=$(parse_help_flag --help 2>&1)
  if echo "$OUTPUT" | grep -q "usage called"; then
    pass "parse_help_flag detects --help and calls usage"
  else
    fail "parse_help_flag should call usage on --help"
  fi
}

# Given: the argument -h
# When:  parse_help_flag runs
# Then:  usage is called
# Asserts: short help flag dispatch.
test_help_flag_short() {
  usage() { echo "usage called"; }
  local OUTPUT
  OUTPUT=$(parse_help_flag -h 2>&1)
  if echo "$OUTPUT" | grep -q "usage called"; then
    pass "parse_help_flag detects -h"
  else
    fail "parse_help_flag should detect -h"
  fi
}

# Given: ordinary flags, no --help/-h
# When:  parse_help_flag runs
# Then:  it produces no output
# Asserts: no false help trigger (the returned rc is not asserted).
test_help_flag_not_triggered() {
  # No --help or -h in args  --  should be a no-op
  usage() { echo "usage called"; }
  OUTPUT=$(parse_help_flag --name=test --sandbox=/tmp/s 2>&1)
  assert_empty "$OUTPUT" "parse_help_flag produces no output when no help flag present"
}

# ---------------------------------------------------------------------------
# sandbox_dir_canon
# ---------------------------------------------------------------------------

# Given: a sandbox path written with a leading ~
# When:  sandbox_dir_canon runs
# Then:  it prints the canonical path under HOME
# Asserts: the tilde expands before readlink resolves the path.
test_sandbox_dir_canon_expands_tilde() {
  local home="$FIXTURE_DIR/tilde_home"
  mkdir -p "$home/sub"
  local out expected tilde
  tilde='~'
  out="$(HOME="$home" sandbox_dir_canon "$tilde/sub")"
  expected="$(readlink -f "$home/sub")"
  assert_eq "$out" "$expected" "sandbox_dir_canon expands a leading ~"
}

# ---------------------------------------------------------------------------
# check_base_flags
# ---------------------------------------------------------------------------

# Given: PROJECT_NAME and SANDBOX_DIR set
# When:  check_base_flags runs
# Then:  it passes
# Asserts: the required pair passes.
test_check_base_flags_valid() {
  if ( PROJECT_NAME="test" SANDBOX_DIR="/tmp/valid" check_base_flags 2>/dev/null ); then
    pass "check_base_flags passes when both flags set"
  else
    fail "check_base_flags should pass with valid flags"
  fi
}

# check_base_flags calls exit(1) on failure (it's designed for CLI scripts),
# so these tests run in a subshell to avoid aborting the test runner.

# Given: an empty PROJECT_NAME
# When:  check_base_flags runs
# Then:  it fails
# Asserts: --name is required.
test_check_base_flags_missing_name() {
  if ( PROJECT_NAME="" SANDBOX_DIR="/tmp/valid" check_base_flags 2>/dev/null ); then
    fail "check_base_flags should fail with missing --name"
  else
    pass "check_base_flags fails when --name= is empty"
  fi
}

# Given: an empty SANDBOX_DIR
# When:  check_base_flags runs
# Then:  it fails
# Asserts: --sandbox is required.
test_check_base_flags_missing_sandbox() {
  if ( PROJECT_NAME="test" SANDBOX_DIR="" check_base_flags 2>/dev/null ); then
    fail "check_base_flags should fail with missing --sandbox"
  else
    pass "check_base_flags fails when --sandbox= is empty"
  fi
}

# Given: SANDBOX_DIR=/
# When:  check_base_flags runs
# Then:  it fails
# Asserts: root is rejected as a sandbox.
test_check_base_flags_rejects_root_sandbox() {
  if ( PROJECT_NAME="test" SANDBOX_DIR="/" check_base_flags 2>/dev/null ); then
    fail "check_base_flags should reject SANDBOX_DIR=/"
  else
    pass "check_base_flags rejects SANDBOX_DIR=/"
  fi
}

# Given: an empty SANDBOX_DIR and a set PROJECT_NAME
# When:  check_base_flags runs
# Then:  it fails
# Asserts: an empty sandbox is rejected.
test_check_base_flags_rejects_empty_sandbox() {
  if ( PROJECT_NAME="test" SANDBOX_DIR="" check_base_flags 2>/dev/null ); then
    fail "check_base_flags should reject empty SANDBOX_DIR"
  else
    pass "check_base_flags rejects empty SANDBOX_DIR"
  fi
}

# Given: common.sh sourced with no override
# When:  INTERACTIVE_MAX_ENTRIES is read
# Then:  it is 10
# Asserts: the single canonical picker cap.
test_interactive_max_entries_default() {
  if [[ "${INTERACTIVE_MAX_ENTRIES:-}" == "10" ]]; then
    pass "common.sh: INTERACTIVE_MAX_ENTRIES defaults to 10"
  else
    fail "common.sh: expected INTERACTIVE_MAX_ENTRIES=10, got '${INTERACTIVE_MAX_ENTRIES:-}'"
  fi
}


# ---------------------------------------------------------------------------
# Run all
# ---------------------------------------------------------------------------

run_test test_help_flag_detected
run_test test_help_flag_short
run_test test_help_flag_not_triggered
run_test test_sandbox_dir_canon_expands_tilde
run_test test_check_base_flags_valid
run_test test_check_base_flags_missing_name
run_test test_check_base_flags_missing_sandbox
run_test test_check_base_flags_rejects_root_sandbox
run_test test_check_base_flags_rejects_empty_sandbox
run_test test_interactive_max_entries_default

test_done
