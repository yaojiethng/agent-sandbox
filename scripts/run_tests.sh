#!/usr/bin/env bash
# scripts/run_tests.sh
# Unified test runner: discovers and runs all tests/test_*.sh files.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../tests" && pwd)"
# RUN_TESTS_DIR overrides discovery for the runner self-test
# (tests/test_runner_selftest.sh feeds it synthetic files).
TEST_DIR="${RUN_TESTS_DIR:-$TEST_DIR}"

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
  local FILES=()
  for F in "$TEST_DIR"/test_*.sh; do
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

  # stdin from /dev/null: the runner iterates test files via a `<<<` here-string
  # (shared temp-file FD); a test subprocess that reads stdin would advance that
  # FD offset and cause `read` in the discovery loop to skip trailing files.
  bash "$FILE" > "$TMPFILE" 2>&1 < /dev/null
  local RC=$?

  local FILE_PASS FILE_FAIL FILE_SKIP
  FILE_PASS=$(grep -c "^  PASS:" "$TMPFILE" 2>/dev/null) || true
  FILE_FAIL=$(grep -c "^  FAIL:" "$TMPFILE" 2>/dev/null) || true
  FILE_SKIP=$(grep -c "^  SKIP:" "$TMPFILE" 2>/dev/null) || true

  TOTAL_PASS=$((TOTAL_PASS + FILE_PASS))
  TOTAL_FAIL=$((TOTAL_FAIL + FILE_FAIL))
  TOTAL_SKIP=$((TOTAL_SKIP + FILE_SKIP))

  if [[ "$RC" -ne 0 || "$FILE_FAIL" -gt 0 || "$FILE_SKIP" -gt 0 ]]; then
    ANY_FAILED=1
  fi

  if [[ "$RC" -eq 0 && "$FILE_PASS" -eq 0 && "$FILE_FAIL" -eq 0 && "$FILE_SKIP" -eq 0 ]]; then
    echo "WARN $BASENAME (0 tests executed  --  file may be missing run_test calls)" >&2
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

  if [[ "$TOTAL_SKIP" -gt 0 ]]; then
    echo "ERROR: make test must have zero skips (expected deterministic unit/integration suite)." >&2
    echo "       $TOTAL_SKIP skipped. Move non-deterministic/utility-gated tests to tests/integration/." >&2
    ANY_FAILED=1
  fi

  if [[ "$ANY_FAILED" -eq 1 ]]; then
    exit 1
  fi
}

main "$@"
