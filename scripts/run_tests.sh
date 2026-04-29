#!/usr/bin/env bash
# scripts/run_tests.sh
# Unified test runner: discovers and runs all tests/test_*.sh files.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/../tests"

TOTAL_PASS=0
TOTAL_FAIL=0
ANY_FAILED=0

discover_tests() {
  local PATTERN="$TEST_DIR"/test_*.sh
  local FILES=()
  for F in $PATTERN; do
    if [[ -f "$F" ]]; then
      FILES+=("$F")
    fi
  done
  if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "Warning: no test files found matching $PATTERN" >&2
    return 1
  fi
  printf '%s\n' "${FILES[@]}" | sort
}

run_single() {
  local FILE="$1"
  local BASENAME
  BASENAME="$(basename "$FILE")"
  bash "$FILE"
  local RC=$?
  if [[ "$RC" -eq 0 ]]; then
    echo "PASS $BASENAME"
    TOTAL_PASS=$((TOTAL_PASS + 1))
  else
    echo "FAIL $BASENAME"
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
    ANY_FAILED=1
  fi
}

main() {
  local TEST_FILES
  TEST_FILES="$(discover_tests)" || exit 1

  while IFS= read -r FILE; do
    [[ -n "$FILE" ]] || continue
    run_single "$FILE"
  done <<< "$TEST_FILES"

  echo ""
  echo "Results: $TOTAL_PASS passed, $TOTAL_FAIL failed"

  if [[ "$ANY_FAILED" -eq 1 ]]; then
    exit 1
  fi
}

main "$@"
