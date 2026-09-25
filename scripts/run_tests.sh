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
# LIVENESS_GATE overrides the registration-gate path for the runner self-test.
LIVENESS_GATE="${LIVENESS_GATE:-$REAL_TESTS_DIR/../scripts/check_test_liveness.sh}"

VERBOSE="${VERBOSE:-0}"
# TEST_PARALLEL controls the xargs job count (default 8; 1 for serial runs).
TEST_PARALLEL="${TEST_PARALLEL:-8}"
# TEST_TIMEOUT is the per-file deadline in seconds (default 5).
TEST_TIMEOUT="${TEST_TIMEOUT:-5}"

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0
TOTAL_TIMEOUT=0
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

# run_with_deadline DEADLINE OUT FILE
#   Runs the test file under a pure-bash wall-clock deadline. Backgrounds the
#   test and polls it at 0.1s, killing it on expiry and returning 124. No
#   external `timeout` binary: GNU and BSD `sleep` both accept fractional
#   seconds, `kill -0` and `wait` are builtins (bash-3.2-safe).
run_with_deadline() {
  local deadline_ticks=$(( ${1#-} * 10 ))
  local out="$2"; shift 2
  local pid ticks=0 grace=0
  # set -m puts the test file in its own process group, so the deadline can
  # signal the whole file (a test that spawns children, or that ignores TERM,
  # must not outlive its own run).
  set -m
  bash "$@" < /dev/null > "$out" 2>&1 &
  pid=$!
  set +m
  while (( ticks < deadline_ticks )); do
    if ! kill -0 "$pid" 2>/dev/null; then
      break
    fi
    sleep 0.1
    ticks=$((ticks + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -TERM -"$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
    while (( grace < 5 )) && kill -0 "$pid" 2>/dev/null; do
      sleep 0.1
      grace=$((grace + 1))
    done
    if kill -0 "$pid" 2>/dev/null; then
      kill -KILL -"$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null
    fi
    wait "$pid" 2>/dev/null
    return 124
  fi
  wait "$pid"
  return $?
}

# worker FILE
#   Runs one test file in a child shell under the deadline, reads its unit
#   report, writes the status record to $RESULTS_DIR, and prints the per-file
#   line. stdin from /dev/null: a test subprocess reading stdin must not
#   disturb the parent's xargs pipe (the FD-offset bug class). Always exits 0;
#   failures are carried in the record and the printed line.
#
#   Counts come from the test file's own UNIT: report (test_common's test_done,
#   e.g. "UNIT: pass=16 fail=0 skip=1"), not from re-parsing presentation
#   markers, so a format drift cannot silently zero the result. A file with no
#   report (crash, missing test_done) or a zero-unit report (no run_test
#   executed) is a failure by construction.
worker() {
  local FILE="$1"
  local BASENAME
  BASENAME="$(basename "$FILE")"
  local TMPFILE RECORD RC FILE_PASS FILE_FAIL FILE_SKIP UNIT special
  TMPFILE=$(mktemp)
  RECORD="$RESULTS_DIR/$BASENAME.record"

  run_with_deadline "$TEST_TIMEOUT" "$TMPFILE" "$FILE"
  RC=$?

  UNIT="$(grep '^UNIT: pass=' "$TMPFILE" 2>/dev/null | tail -1)"
  FILE_PASS=0; FILE_FAIL=0; FILE_SKIP=0
  special=""
  if [[ -n "$UNIT" ]] && [[ "$UNIT" =~ ^UNIT:[[:space:]]pass=([0-9]+)[[:space:]]fail=([0-9]+)[[:space:]]skip=([0-9]+)$ ]]; then
    FILE_PASS="${BASH_REMATCH[1]}"; FILE_FAIL="${BASH_REMATCH[2]}"; FILE_SKIP="${BASH_REMATCH[3]}"
    if (( FILE_PASS + FILE_FAIL + FILE_SKIP == 0 )); then
      FILE_FAIL=1
      special="FAIL $BASENAME (UNIT report but 0 test units -- no run_test executed)"
    fi
  elif [[ -n "$UNIT" ]]; then
    # A UNIT line present but malformed is a drifted shape, not a zero.
    FILE_FAIL=1
    special="FAIL $BASENAME (malformed UNIT: report -- $UNIT)"
  else
    FILE_FAIL=1
    special="FAIL $BASENAME (file exited $RC with no UNIT: report -- crash or missing test_done)"
  fi
  # A deadline expiry is a failure even when the file managed to print a
  # UNIT report before it hung; the timeout count is named in the summary.
  if [[ "$RC" -eq 124 ]]; then
    special="TIMEOUT $BASENAME (exceeded ${TEST_TIMEOUT}s deadline)"
    (( FILE_FAIL > 0 )) || FILE_FAIL=1
  fi

  # The worker-to-parent record is self-describing key=value; main() validates
  # it strictly, so a shape drift is a loud failure, not a silent misparse.
  printf 'pass=%s fail=%s skip=%s rc=%s\n' "$FILE_PASS" "$FILE_FAIL" "$FILE_SKIP" "$RC" > "$RECORD"

  if [[ -n "$special" ]]; then
    echo "$special" >&2
  elif [[ "$FILE_SKIP" -gt 0 ]]; then
    echo "WARN $BASENAME ($FILE_SKIP skipped)" >&2
  fi

  case "$VERBOSE" in
    0)
      if [[ -z "$special" && ( "$RC" -ne 0 && "$RC" -ne 124 || "$FILE_FAIL" -gt 0 ) ]]; then
        echo "FAIL $BASENAME"
        if [[ "$FILE_FAIL" -gt 0 ]]; then
          grep "^  FAIL:" "$TMPFILE" | sed 's/^  FAIL: /  - /' || true
        else
          echo "  - file exited $RC with no FAIL: marker (crash or uncaught non-zero command)"
        fi
      fi
      ;;
    1)
      if [[ -z "$special" ]]; then
        if [[ "$RC" -eq 0 && "$FILE_FAIL" -eq 0 ]]; then
          echo "PASS $BASENAME ($FILE_PASS passed, $FILE_SKIP skipped)"
        else
          echo "FAIL $BASENAME ($FILE_PASS passed, $FILE_FAIL failed, $FILE_SKIP skipped)"
          if [[ "$FILE_FAIL" -gt 0 ]]; then
            grep "^  FAIL:" "$TMPFILE" | sed 's/^  FAIL: /  - /' || true
          fi
        fi
      fi
      ;;
    2)
      cat "$TMPFILE"
      if [[ -z "$special" && "$RC" -eq 0 && "$FILE_FAIL" -eq 0 ]]; then
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

  # Registration liveness gate (mandatory, runs before any test): the gate
  # owns the registration contract -- unregistered tests, dangling
  # registrations, and a run_test after test_done. The gate scans the same
  # directory the runner discovered, so the RUN_TESTS_DIR override points it
  # at the self-test's fixtures. A gate failure is reported and carried into
  # the final verdict; the suite still runs, so one bad finding cannot hide
  # every result behind a single abort.
  local gate_tests_dir="${RUN_TESTS_DIR:-$REAL_TESTS_DIR}"
  if ! bash "$LIVENESS_GATE" "$gate_tests_dir"; then
    echo "ERROR: test liveness gate failed -- fix the findings above before trusting the suite." >&2
    ANY_FAILED=1
  fi

  local TEST_FILES
  TEST_FILES=$(discover_tests) || exit 1

  # Dispatch every file in parallel. Each worker is a child copy of this script
  # (`bash "$0" --worker`), inheriting VERBOSE / RESULTS_DIR / TEST_TIMEOUT by
  # environment; xargs reads the file list from the pipe and passes each path
  # as the worker's argument, so no shared stdin is advanced by the tests.
  # RUN_TESTS_RESULTS_DIR injects a pre-seeded results directory instead of
  # dispatching workers; the runner self-test uses it to exercise the
  # record-validation branch.
  local RESULTS_DIR
  RESULTS_DIR="${RUN_TESTS_RESULTS_DIR:-$(mktemp -d)}"
  export RESULTS_DIR VERBOSE TEST_TIMEOUT

  if [[ -z "${RUN_TESTS_RESULTS_DIR:-}" ]]; then
    printf '%s\n' "$TEST_FILES" \
      | xargs -P"$TEST_PARALLEL" -I{} bash "$0" --worker "{}"
  fi

  # Aggregate the workers' records. One record per dispatched file; a missing
  # record means the worker died, which is a failure.
  local RECORD BASENAME RECLINE
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
    # The record is self-describing key=value; validate it strictly. A
    # malformed record is a hard failure -- worker and parent are one file, so
    # a shape drift is an edit bug we make loud.
    IFS= read -r RECLINE < "$RECORD" || true
    if [[ "$RECLINE" =~ ^pass=([0-9]+)[[:space:]]fail=([0-9]+)[[:space:]]skip=([0-9]+)[[:space:]]rc=([0-9]+)$ ]]; then
      local R_PASS="${BASH_REMATCH[1]}" R_FAIL="${BASH_REMATCH[2]}" R_SKIP="${BASH_REMATCH[3]}" R_RC="${BASH_REMATCH[4]}"
      # A file that exits non-zero with no failing unit still failed; count it
      # so the summary never reports an all-clear over a red run.
      if [[ "$R_RC" -ne 0 && "$R_FAIL" -eq 0 ]]; then
        R_FAIL=1
      fi
      TOTAL_PASS=$((TOTAL_PASS + R_PASS))
      TOTAL_FAIL=$((TOTAL_FAIL + R_FAIL))
      TOTAL_SKIP=$((TOTAL_SKIP + R_SKIP))
      FILE_COUNT=$((FILE_COUNT + 1))
      if [[ "$R_RC" -eq 124 ]]; then
        TOTAL_TIMEOUT=$((TOTAL_TIMEOUT + 1))
      fi
      if [[ "$R_RC" -ne 0 || "$R_FAIL" -gt 0 ]]; then
        ANY_FAILED=1
      fi
    else
      echo "FAIL $BASENAME (worker wrote a malformed record)" >&2
      ANY_FAILED=1
      FILE_COUNT=$((FILE_COUNT + 1))
    fi
  done <<< "$TEST_FILES"

  rm -rf "$RESULTS_DIR"

  echo ""
  local TOTAL_TESTS=$((TOTAL_PASS + TOTAL_FAIL + TOTAL_SKIP))
  echo "$TOTAL_TESTS tests across $FILE_COUNT files, $TOTAL_PASS passed, $TOTAL_FAIL failed, $TOTAL_SKIP skipped (${SECONDS}s)"

  if [[ "$TOTAL_TIMEOUT" -gt 0 ]]; then
    echo "TIMEOUT: $TOTAL_TIMEOUT file(s) exceeded the ${TEST_TIMEOUT}s deadline and are counted as failed." >&2
  fi

  if [[ "$TOTAL_SKIP" -gt 0 ]]; then
    echo "WARN: $TOTAL_SKIP test(s) skipped -- a temporary absence (unstubbed or missing subject); resolve the cause so skips trend back to zero." >&2
  fi

  if [[ "$ANY_FAILED" -eq 1 ]]; then
    exit 1
  fi
}

main "$@"