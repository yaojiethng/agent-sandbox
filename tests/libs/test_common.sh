#!/usr/bin/env bash
# tests/libs/test_common.sh
# Shared test helpers. Source this file, do not execute directly.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: test_common.sh must be sourced, not executed." >&2
  exit 1
fi

: "${PASS:=0}"
: "${FAIL:=0}"
: "${SKIP:=0}"
FAILURES=()
SKIPS=()

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); FAILURES+=("$1"); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); SKIPS+=("$1"); }
# run_test NAME
#   Invokes a test function. A test that returns without calling pass/fail/skip
#   is counted as a failure: a silent test proves nothing.
run_test() {
  local _bp=$PASS _bf=$FAIL _bs=$SKIP
  echo "[ $1 ]"
  $1 || true
  if (( PASS + FAIL + SKIP == _bp + _bf + _bs )); then
    echo "  NO-ASSERTION: $1 completed without calling pass/fail/skip" >&2
    FAIL=$((FAIL + 1)); FAILURES+=("$1 (no assertion)")
  fi
}

# ---------------------------------------------------------------------------
# test_setup — call at file scope after source lines to get standard vars
# and automatic temp-dir cleanup.
#
# Sets: TEST_DIR, REPO_ROOT, FIXTURE_DIR (mktemp -d)
# Registers: trap 'rm -rf "$FIXTURE_DIR"' EXIT
# ---------------------------------------------------------------------------
# shellcheck disable=SC2034  # REPO_ROOT is consumed by test files after they call test_setup
test_setup() {
  if [[ -z "${BASH_SOURCE[1]:-}" ]]; then
    echo "Error: test_setup must be called from a sourced file, not interactively." >&2
    return 1
  fi
  TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"
  FIXTURE_DIR="$(mktemp -d /tmp/XXXXXX)"
  trap 'rm -rf "$FIXTURE_DIR"' EXIT
}

test_done() {
  local NAME="${1:-}"
  if [[ -n "$NAME" ]]; then
    echo "=== $NAME ==="
    echo
  fi
  echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
  if [[ ${#FAILURES[@]} -gt 0 ]]; then
    echo "Failed:"
    # FAIL: prefix — scripts/run_tests.sh counts failures by grepping this
    # exact marker from captured output.
    for f in "${FAILURES[@]}"; do echo "  FAIL: $f"; done
  fi
  if [[ ${#SKIPS[@]} -gt 0 ]]; then
    echo "Skipped:"
    for s in "${SKIPS[@]}"; do echo "  - $s"; done
  fi
  exit "$FAIL"
}

# ---------------------------------------------------------------------------
# Assertion helpers — the standard way to assert inside a test function.
# Each calls pass/fail itself, so a test body can be one to three lines and
# can never be assertion-less.
#
#   assert_eq ACTUAL EXPECTED [LABEL]      — string equality
#   assert_ne ACTUAL UNEXPECTED [LABEL]    — string inequality
#   assert_rc EXPECTED_RC ACTUAL_RC [LABEL] — exit-code comparison (integers)
#   assert_contains HAYSTACK NEEDLE [LABEL] — substring match (literal)
# ---------------------------------------------------------------------------
assert_eq() {
  local ACTUAL="$1" EXPECTED="$2" LABEL="${3:-values equal}"
  if [[ "$ACTUAL" == "$EXPECTED" ]]; then
    pass "$LABEL"
  else
    fail "$LABEL (expected '$EXPECTED', got '$ACTUAL')"
  fi
}

assert_ne() {
  local ACTUAL="$1" UNEXPECTED="$2" LABEL="${3:-values differ}"
  if [[ "$ACTUAL" != "$UNEXPECTED" ]]; then
    pass "$LABEL"
  else
    fail "$LABEL (both values are '$ACTUAL')"
  fi
}

assert_rc() {
  local EXPECTED_RC="$1" ACTUAL_RC="$2" LABEL="${3:-exit code}"
  if [[ "$ACTUAL_RC" == "$EXPECTED_RC" ]]; then
    pass "$LABEL (rc=$ACTUAL_RC)"
  else
    fail "$LABEL (expected rc=$EXPECTED_RC, got rc=$ACTUAL_RC)"
  fi
}

assert_contains() {
  local HAYSTACK="$1" NEEDLE="$2" LABEL="${3:-contains '$2'}"
  if [[ "$HAYSTACK" == *"$NEEDLE"* ]]; then
    pass "$LABEL"
  else
    fail "$LABEL ('$NEEDLE' not found in output)"
  fi
}
