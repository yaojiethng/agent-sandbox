#!/usr/bin/env bash
# scripts/run_tests.sh
# Unified test runner: discovers and runs all tests/test_*.sh files.

set -uo pipefail

SECONDS=0

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../tests" && pwd)"
# RUN_TESTS_DIR overrides discovery for the runner self-test
# (tests/test_runner_selftest.sh feeds it synthetic files).
TEST_DIR="${RUN_TESTS_DIR:-$TEST_DIR}"

# Prerequisites live in the real tests dir (not the RUN_TESTS_DIR override).
REAL_TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../tests" && pwd)"

VERBOSE="${VERBOSE:-0}"
# TEST_PARALLEL controls the xargs job count (default 8; 1 for serial runs).
TEST_PARALLEL="${TEST_PARALLEL:-8}"
# TEST_TIMEOUT is the per-file deadline in seconds (default 5).
TEST_TIMEOUT="${TEST_TIMEOUT:-5}"

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0
ANY_FAILED=0
FILE_COUNT=0

# check_prerequisites
#   Verifies the suite's prerequisites before any test runs. A broken docker
#   stub would otherwise fail dozens of tests with unrelated 126/127 errors;
#   report it once, by name (testing_policy.md prerequisite rule).
#   PREREQ_STUB overrides the path for the runner self-test.
check_prerequisites() {
  local stub="${PREREQ_STUB:-$REAL_TESTS_DIR/stubs/docker}"
  if [[ ! -x "$stub" ]]; then
    echo "ERROR: prerequisite missing or not executable: $stub" >&2
    echo "       The docker stub must be present and executable." >&2
    echo "       Restore it with: chmod +x $stub" >&2
    return 1
  fi
}

discover_tests() {
  local FILES=()
  local F
  for F in "$TEST_DIR"/test_*.sh; do
    if [[ -f "$F" ]]; then
      FILES+=("$F")
    fi
  done
  if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "Warning: no test files found in $TEST_DIR" >&2
    return 1
  fi
  printf '%s\n' "${FILES[@]}" | sort
}

# check_liveness FILE
#   Static guard for the structural template (testing-conventions.md): a
#   run_test registration after test_done is dead code -- test_done exits the
#   process, so the test never runs and never fails. test_done cannot guard
#   this in-process (it exits), so the runner scans the file. The scan anchors
#   on the registration contract (run_test naming a test_ function, the same
#   shape check_test_liveness.sh greps): a registration-shaped word inside a
#   quoted payload is not flagged unless it sits at column 0.
check_liveness() {
  local FILE="$1" BASENAME
  BASENAME="$(basename "$FILE")"
  if ! awk '
    /^[[:space:]]*test_done([[:space:]]|$)/ { seen = 1 }
    /^[[:space:]]*run_test[[:space:]]+test_[A-Za-z0-9_]+([[:space:]]|$)/ { if (seen) exit 1 }
  ' "$FILE"; then
    echo "FATAL $BASENAME: run_test registered after test_done -- the registration is dead code (testing-conventions.md, Test Structure Template)" >&2
    ANY_FAILED=1
  fi
}

# run_with_deadline DEADLINE OUT FILE
#   Runs the test file under a pure-bash wall-clock deadline. Backgrounds the
#   test and polls it at 0.1s, killing it on expiry and returning 124. No
#   external `timeout` binary: GNU and BSD `sleep` both accept fractional
#   seconds, `kill -0` and `wait` are builtins (bash-3.2-safe).
run_with_deadline() {
  local deadline_ticks=$(( ${1#-} * 10 ))
  local out="$2"; shift 2
  local pid ticks=0
  bash "$@" < /dev/null > "$out" 2>&1 &
  pid=$!
  while (( ticks < deadline_ticks )); do
    if ! kill -0 "$pid" 2>/dev/null; then
      break
    fi
    sleep 0.1
    ticks=$((ticks + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    return 124
  fi
  wait "$pid"
  return $?
}

# worker FILE
#   Runs one test file in a child shell under the deadline, counts its markers,
#   writes the status record to $RESULTS_DIR, and prints the per-file line.
#   stdin from /dev/null: a test subprocess reading stdin must not disturb the
#   parent's xargs pipe (the FD-offset bug class). Always exits 0; failures are
#   carried in the record and the printed line.
worker() {
  local FILE="$1"
  local BASENAME
  BASENAME="$(basename "$FILE")"
  local TMPFILE RECORD RC FILE_PASS FILE_FAIL FILE_SKIP
  TMPFILE=$(mktemp)
  RECORD="$RESULTS_DIR/$BASENAME.record"

  run_with_deadline "$TEST_TIMEOUT" "$TMPFILE" "$FILE"
  RC=$?

  FILE_PASS=$(grep -c "^  PASS:" "$TMPFILE" 2>/dev/null) || true
  FILE_FAIL=$(grep -c "^  FAIL:" "$TMPFILE" 2>/dev/null) || true
  FILE_SKIP=$(grep -c "^  SKIP:" "$TMPFILE" 2>/dev/null) || true

  printf '%s %s %s %s\n' "$FILE_PASS" "$FILE_FAIL" "$FILE_SKIP" "$RC" > "$RECORD"

  if [[ "$RC" -eq 124 ]]; then
    echo "TIMEOUT $BASENAME (exceeded ${TEST_TIMEOUT}s deadline)"
  elif [[ "$RC" -eq 0 && "$FILE_PASS" -eq 0 && "$FILE_FAIL" -eq 0 && "$FILE_SKIP" -eq 0 ]]; then
    echo "WARN $BASENAME (0 tests executed  --  file may be missing run_test calls)" >&2
  fi

  case "$VERBOSE" in
    0)
      if [[ "$RC" -ne 0 && "$RC" -ne 124 || "$FILE_FAIL" -gt 0 ]]; then
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

# Worker entry point. The parent dispatches each test file to a child copy of
# this script with `--worker FILE` (see main). The worker runs the one file
# under a deadline, writes a status record for the parent to aggregate, prints
# the per-file PASS/FAIL/TIMEOUT line, and always exits 0 so xargs schedules
# every file regardless of any single failure. Placed after the worker()
# definition: bash executes top-level statements as it reads them, so the
# function must already be defined before this branch can call it.
if [[ "${1:-}" == "--worker" ]]; then
  shift
  worker "$1"
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v)  VERBOSE=1; shift ;;
    -vv) VERBOSE=2; shift ;;
    *)   echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

main() {
  check_prerequisites || exit 1

  # Registration liveness gate (mandatory, runs before any test): a test
  # function without a run_test registration never executes, so the suite can
  # report green while silently excluding coverage -- the gate makes that
  # loud instead. Skipped under the runner self-test's RUN_TESTS_DIR override
  # (synthetic fixture dir; the real suite's liveness is not the subject).
  if [[ -z "${RUN_TESTS_DIR:-}" ]]; then
    if ! bash "$REAL_TESTS_DIR/../scripts/check_test_liveness.sh"; then
      echo "ERROR: test liveness gate failed -- fix the findings above before running the suite." >&2
      exit 1
    fi
  fi

  local TEST_FILES
  TEST_FILES=$(discover_tests) || exit 1

  # Live registration scans run before dispatch (not in workers) so the
  # findings print once, deterministically, before any test output.
  local FILE
  while IFS= read -r FILE; do
    [[ -n "$FILE" ]] || continue
    check_liveness "$FILE"
  done <<< "$TEST_FILES"

  # Dispatch every file in parallel. Each worker is a child copy of this script
  # (`bash "$0" --worker`), inheriting VERBOSE / RESULTS_DIR / TEST_TIMEOUT by
  # environment; xargs reads the file list from the pipe and passes each path
  # as the worker's argument, so no shared stdin is advanced by the tests.
  local RESULTS_DIR
  RESULTS_DIR=$(mktemp -d)
  export RESULTS_DIR VERBOSE TEST_TIMEOUT

  printf '%s\n' "$TEST_FILES" \
    | xargs -P"$TEST_PARALLEL" -I{} bash "$0" --worker "{}"

  # Aggregate the workers' records. One record per dispatched file; a missing
  # record means the worker died, which is a failure.
  local RECORD BASENAME PASS FAIL SKIP RC
  while IFS= read -r FILE; do
    [[ -n "$FILE" ]] || continue
    BASENAME="$(basename "$FILE")"
    RECORD="$RESULTS_DIR/$BASENAME.record"
    if [[ ! -f "$RECORD" ]]; then
      echo "FAIL $BASENAME (worker produced no record)" >&2
      ANY_FAILED=1
      FILE_COUNT=$((FILE_COUNT + 1))
      continue
    fi
    read -r PASS FAIL SKIP RC < "$RECORD"
    TOTAL_PASS=$((TOTAL_PASS + PASS))
    TOTAL_FAIL=$((TOTAL_FAIL + FAIL))
    TOTAL_SKIP=$((TOTAL_SKIP + SKIP))
    FILE_COUNT=$((FILE_COUNT + 1))
    if [[ "$RC" -ne 0 || "$FAIL" -gt 0 || "$SKIP" -gt 0 ]]; then
      ANY_FAILED=1
    fi
  done <<< "$TEST_FILES"

  rm -rf "$RESULTS_DIR"

  echo ""
  local TOTAL_TESTS=$((TOTAL_PASS + TOTAL_FAIL + TOTAL_SKIP))
  echo "$TOTAL_TESTS tests across $FILE_COUNT files, $TOTAL_PASS passed, $TOTAL_FAIL failed, $TOTAL_SKIP skipped (${SECONDS}s)"

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