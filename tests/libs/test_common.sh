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
run_test() { echo "[ $1 ]"; $1 || true; }

test_done() {
  local NAME="${1:-}"
  if [[ -n "$NAME" ]]; then
    echo "=== $NAME ==="
    echo
  fi
  echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
  if [[ ${#FAILURES[@]} -gt 0 ]]; then
    echo "Failed:"
    for f in "${FAILURES[@]}"; do echo "  - $f"; done
  fi
  if [[ ${#SKIPS[@]} -gt 0 ]]; then
    echo "Skipped:"
    for s in "${SKIPS[@]}"; do echo "  - $s"; done
  fi
  exit $FAIL
}
