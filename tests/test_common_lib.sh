#!/usr/bin/env bash
# tests/test_common_lib.sh
# Unit tests for libs/common.sh  --  shared flag parsing and validation.
#
# Covers:
#   parse_help_flag     --  detects --help and -h; passes through other args
#   parse_base_flags    --  extracts --name and --sandbox from arg list
#   check_base_flags    --  validates required flags, rejects empty/slash paths

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/common.sh"

# ---------------------------------------------------------------------------
# parse_help_flag
# ---------------------------------------------------------------------------

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

test_help_flag_not_triggered() {
  # No --help or -h in args  --  should be a no-op
  usage() { echo "usage called"; }
  OUTPUT=$(parse_help_flag --name=test --sandbox=/tmp/s 2>&1)
  if [[ -z "$OUTPUT" ]]; then
    pass "parse_help_flag produces no output when no help flag present"
  else
    fail "parse_help_flag should be silent without help flags, got: $OUTPUT"
  fi
}

# ---------------------------------------------------------------------------
# parse_base_flags
# ---------------------------------------------------------------------------

test_parse_base_flags_sets_vars() {
  PROJECT_NAME="" SANDBOX_DIR=""
  parse_base_flags --name=my-project --sandbox=/tmp/mysandbox --unknown-flag

  if [[ "$PROJECT_NAME" == "my-project" ]]; then
    pass "parse_base_flags sets PROJECT_NAME from --name="
  else
    fail "parse_base_flags: expected PROJECT_NAME=my-project, got $PROJECT_NAME"
  fi
  if [[ "$SANDBOX_DIR" == "/tmp/mysandbox" ]]; then
    pass "parse_base_flags sets SANDBOX_DIR from --sandbox="
  else
    fail "parse_base_flags: expected SANDBOX_DIR=/tmp/mysandbox, got $SANDBOX_DIR"
  fi
}

test_parse_base_flags_defaults_empty() {
  PROJECT_NAME="x" SANDBOX_DIR="y"
  parse_base_flags --other-flag

  if [[ -z "$PROJECT_NAME" ]]; then
    pass "parse_base_flags leaves PROJECT_NAME empty when --name= absent"
  else
    fail "parse_base_flags should leave PROJECT_NAME empty, got $PROJECT_NAME"
  fi
  if [[ -z "$SANDBOX_DIR" ]]; then
    pass "parse_base_flags leaves SANDBOX_DIR empty when --sandbox= absent"
  else
    fail "parse_base_flags should leave SANDBOX_DIR empty, got $SANDBOX_DIR"
  fi
}

# ---------------------------------------------------------------------------
# check_base_flags
# ---------------------------------------------------------------------------

test_check_base_flags_valid() {
  PROJECT_NAME="test" SANDBOX_DIR="/tmp/valid"
  if check_base_flags 2>/dev/null; then
    pass "check_base_flags passes when both flags set"
  else
    fail "check_base_flags should pass with valid flags"
  fi
}

# check_base_flags calls exit(1) on failure (it's designed for CLI scripts),
# so these tests run in a subshell to avoid aborting the test runner.

test_check_base_flags_missing_name() {
  if ( PROJECT_NAME="" SANDBOX_DIR="/tmp/valid" check_base_flags 2>/dev/null ); then
    fail "check_base_flags should fail with missing --name"
  else
    pass "check_base_flags fails when --name= is empty"
  fi
}

test_check_base_flags_missing_sandbox() {
  if ( PROJECT_NAME="test" SANDBOX_DIR="" check_base_flags 2>/dev/null ); then
    fail "check_base_flags should fail with missing --sandbox"
  else
    pass "check_base_flags fails when --sandbox= is empty"
  fi
}

test_check_base_flags_rejects_root_sandbox() {
  if ( PROJECT_NAME="test" SANDBOX_DIR="/" check_base_flags 2>/dev/null ); then
    fail "check_base_flags should reject SANDBOX_DIR=/"
  else
    pass "check_base_flags rejects SANDBOX_DIR=/"
  fi
}

test_check_base_flags_rejects_empty_sandbox() {
  if ( PROJECT_NAME="test" SANDBOX_DIR="" check_base_flags 2>/dev/null ); then
    fail "check_base_flags should reject empty SANDBOX_DIR"
  else
    pass "check_base_flags rejects empty SANDBOX_DIR"
  fi
}

# ---------------------------------------------------------------------------
# Run all
# ---------------------------------------------------------------------------

run_test test_help_flag_detected
run_test test_help_flag_short
run_test test_help_flag_not_triggered
run_test test_parse_base_flags_sets_vars
run_test test_parse_base_flags_defaults_empty
run_test test_check_base_flags_valid
run_test test_check_base_flags_missing_name
run_test test_check_base_flags_missing_sandbox
run_test test_check_base_flags_rejects_root_sandbox
run_test test_check_base_flags_rejects_empty_sandbox
test_interactive_max_entries_default() {
  if [[ "${INTERACTIVE_MAX_ENTRIES:-}" == "10" ]]; then
    pass "common.sh: INTERACTIVE_MAX_ENTRIES defaults to 10"
  else
    fail "common.sh: expected INTERACTIVE_MAX_ENTRIES=10, got '${INTERACTIVE_MAX_ENTRIES:-}'"
  fi
}

run_test test_interactive_max_entries_default

test_done
