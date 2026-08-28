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
