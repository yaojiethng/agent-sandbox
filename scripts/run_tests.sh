#!/usr/bin/env bash
# scripts/run_tests.sh
# Unified test runner: discovers and runs all tests/test_*.sh files.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/../tests"

VERBOSE="${VERBOSE:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v)  VERBOSE=1; shift ;;
    -vv) VERBOSE=2; shift ;;
    *)   echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0
ANY_FAILED=0
FILE_COUNT=0

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
  local TMPFILE
  TMPFILE=$(mktemp)

  bash "$FILE" > "$TMPFILE" 2>&1
  local RC=$?

  local FILE_PASS FILE_FAIL FILE_SKIP
  FILE_PASS=$(grep -c "^  PASS:" "$TMPFILE" 2>/dev/null) || true
  FILE_FAIL=$(grep -c "^  FAIL:" "$TMPFILE" 2>/dev/null) || true
  FILE_SKIP=$(grep -c "^  SKIP:" "$TMPFILE" 2>/dev/null) || true

  TOTAL_PASS=$((TOTAL_PASS + FILE_PASS))
  TOTAL_FAIL=$((TOTAL_FAIL + FILE_FAIL))
  TOTAL_SKIP=$((TOTAL_SKIP + FILE_SKIP))

  if [[ "$RC" -ne 0 || "$FILE_FAIL" -gt 0 ]]; then
    ANY_FAILED=1
  fi

  case "$VERBOSE" in
    0)
      if [[ "$RC" -ne 0 || "$FILE_FAIL" -gt 0 ]]; then
        echo "FAIL $BASENAME"
        grep "^  FAIL:" "$TMPFILE" | sed 's/^  FAIL: /  - /' || true
      fi
      ;;
    1)
      if [[ "$RC" -eq 0 && "$FILE_FAIL" -eq 0 ]]; then
        echo "PASS $BASENAME ($FILE_PASS passed, $FILE_SKIP skipped)"
      else
        echo "FAIL $BASENAME ($FILE_PASS passed, $FILE_FAIL failed, $FILE_SKIP skipped)"
        grep "^  FAIL:" "$TMPFILE" | sed 's/^  FAIL: /  - /' || true
      fi
      ;;
    2)
      cat "$TMPFILE"
      if [[ "$RC" -eq 0 && "$FILE_FAIL" -eq 0 ]]; then
        echo "PASS $BASENAME"
      else
        echo "FAIL $BASENAME"
      fi
      ;;
  esac

  rm -f "$TMPFILE"
}

main() {
  local TEST_FILES
  TEST_FILES=$(discover_tests) || exit 1

  while IFS= read -r FILE; do
    [[ -n "$FILE" ]] || continue
    run_single "$FILE"
    FILE_COUNT=$((FILE_COUNT + 1))
  done <<< "$TEST_FILES"

  echo ""
  local TOTAL_TESTS=$((TOTAL_PASS + TOTAL_FAIL + TOTAL_SKIP))
  echo "$TOTAL_TESTS tests across $FILE_COUNT files, $TOTAL_PASS passed, $TOTAL_FAIL failed, $TOTAL_SKIP skipped"

  if [[ "$ANY_FAILED" -eq 1 ]]; then
    exit 1
  fi
}

main "$@"
