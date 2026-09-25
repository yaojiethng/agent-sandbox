#!/usr/bin/env bash
# tests/test_runner_contract.sh
# Fault-reporting contract of scripts/run_tests.sh: the per-file deadline, the
# result-record validation, the output modes, and the diagnostic streams.
# tests/test_runner_selftest.sh owns discovery and per-unit accounting; this
# file owns what the runner does with a file that misbehaves.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

RUNNER="$REPO_ROOT/scripts/run_tests.sh"

write_test() {
  printf '%s\n' "$2" > "$1"
}

# ---------------------------------------------------------------
# Case 1: a file that ignores SIGTERM is killed at the deadline, and the
# summary counts it as a failure and names the timeout count.
# ---------------------------------------------------------------
test_timeout_of_term_ignoring_file() {
  local dir="$FIXTURE_DIR/timeout_dir"
  mkdir -p "$dir"
  write_test "$dir/test_ignore_term.sh" '#!/usr/bin/env bash
trap "" TERM
sleep 30'
  local OUT RC
  OUT=$(TEST_PARALLEL=4 TEST_TIMEOUT=1 RUN_TESTS_DIR="$dir" bash "$RUNNER" 2>&1)
  RC=$?
  assert_ne "0" "$RC" "runner: a TERM-ignoring file fails the run"
  assert_contains "$OUT" "TIMEOUT test_ignore_term.sh" "runner: deadline expiry reported by name"
  assert_contains "$OUT" "TIMEOUT: 1 file(s) exceeded" "runner: timeout count named in the summary"
  assert_contains "$OUT" "1 tests across 1 files, 0 passed, 1 failed, 0 skipped" \
    "runner: timed-out file counted as a failure in the aggregate"
}

# ---------------------------------------------------------------
# Case 2: a file that runs no test unit reports green-looking counts, so the
# runner must fail it by name.
# ---------------------------------------------------------------
test_zero_unit_report_fails() {
  local dir="$FIXTURE_DIR/zero_dir"
  mkdir -p "$dir"
  write_test "$dir/test_zero.sh" "#!/usr/bin/env bash
source '$REPO_ROOT/tests/libs/test_common.sh'
test_done"
  local OUT RC
  OUT=$(RUN_TESTS_DIR="$dir" bash "$RUNNER" 2>&1)
  RC=$?
  assert_ne "0" "$RC" "runner: a file with no test units fails the run"
  assert_contains "$OUT" "0 test units -- no run_test executed" \
    "runner: zero-unit report named as the failure cause"
}

# ---------------------------------------------------------------
# Case 3: the progress modes and the unknown-option refusal.
# ---------------------------------------------------------------
test_output_modes_and_unknown_option() {
  local dir="$FIXTURE_DIR/modes_dir"
  mkdir -p "$dir"
  write_test "$dir/test_ok.sh" '#!/usr/bin/env bash
printf "UNIT: pass=1 fail=0 skip=0\n"'
  local OUT RC

  OUT=$(RUN_TESTS_DIR="$dir" bash "$RUNNER" -v 2>&1)
  assert_contains "$OUT" "PASS test_ok.sh (1 passed, 0 skipped)" \
    "runner: -v prints the per-file pass line with counts"

  OUT=$(RUN_TESTS_DIR="$dir" bash "$RUNNER" -vv 2>&1)
  assert_contains "$OUT" "UNIT: pass=1 fail=0 skip=0" \
    "runner: -vv forwards the file's own report"
  assert_contains "$OUT" "PASS test_ok.sh" "runner: -vv prints the per-file verdict"

  OUT=$(bash "$RUNNER" --bogus 2>&1)
  RC=$?
  assert_ne "0" "$RC" "runner: an unknown option exits non-zero"
  assert_contains "$OUT" "Unknown option: --bogus" "runner: an unknown option names itself"
}

# ---------------------------------------------------------------
# Case 4: a file that exits non-zero with a clean UNIT report still fails.
# ---------------------------------------------------------------
test_nonzero_exit_with_clean_report() {
  local dir="$FIXTURE_DIR/rc_only_dir"
  mkdir -p "$dir"
  write_test "$dir/test_rc_only.sh" '#!/usr/bin/env bash
printf "UNIT: pass=1 fail=0 skip=0\n"
exit 1'
  local OUT RC
  OUT=$(RUN_TESTS_DIR="$dir" bash "$RUNNER" 2>&1)
  RC=$?
  assert_ne "0" "$RC" "runner: a clean report with a non-zero exit fails the run"
  assert_contains "$OUT" "1 passed, 1 failed, 0 skipped" \
    "runner: the rc-only failure is counted in the aggregate"
}

# ---------------------------------------------------------------
# Case 5: the record-validation branch. The results directory is injected so
# the unit can seed a record the worker would never write.
# ---------------------------------------------------------------
test_malformed_record_fails() {
  local dir="$FIXTURE_DIR/malformed_dir"
  local results="$FIXTURE_DIR/malformed_results"
  mkdir -p "$dir" "$results"
  write_test "$dir/test_x.sh" '#!/usr/bin/env bash
printf "UNIT: pass=1 fail=0 skip=0\n"'
  printf 'pass=1 fail=0\n' > "$results/test_x.sh.record"
  local OUT RC
  OUT=$(RUN_TESTS_DIR="$dir" RUN_TESTS_RESULTS_DIR="$results" bash "$RUNNER" 2>&1)
  RC=$?
  assert_ne "0" "$RC" "runner: a malformed record fails the run"
  assert_contains "$OUT" "malformed record" "runner: malformed record named as the failure cause"
}

# ---------------------------------------------------------------
# Case 6: the per-file diagnostic rides stderr; the summary rides stdout.
# ---------------------------------------------------------------
test_diagnostic_and_summary_streams() {
  local dir="$FIXTURE_DIR/streams_dir"
  mkdir -p "$dir"
  write_test "$dir/test_crash.sh" '#!/usr/bin/env bash
echo "starting work..."
exit 3'
  local OUT ERR
  OUT=$(RUN_TESTS_DIR="$dir" bash "$RUNNER" 2>/dev/null)
  ERR=$(RUN_TESTS_DIR="$dir" bash "$RUNNER" 2>&1 >/dev/null)
  assert_contains "$OUT" "tests across" "runner: the summary lands on stdout"
  assert_not_contains "$OUT" "no UNIT: report" "runner: the per-file diagnostic is not on stdout"
  assert_contains "$ERR" "no UNIT: report" "runner: the per-file diagnostic lands on stderr"
}

# ---------------------------------------------------------------
# Case 7: a failing liveness gate is reported, carried into the verdict, and
# does not suppress the run (one finding must not hide every result).
# ---------------------------------------------------------------
test_liveness_gate_failure_does_not_skip_suite() {
  local dir="$FIXTURE_DIR/gate_dir"
  mkdir -p "$dir"
  write_test "$dir/test_ok.sh" '#!/usr/bin/env bash
printf "UNIT: pass=1 fail=0 skip=0\n"'
  local gate="$FIXTURE_DIR/failing_gate.sh"
  printf '#!/usr/bin/env bash\necho "STUB GATE FINDING" >&2\nexit 1\n' > "$gate"
  chmod +x "$gate"
  local OUT RC
  OUT=$(RUN_TESTS_DIR="$dir" LIVENESS_GATE="$gate" bash "$RUNNER" 2>&1)
  RC=$?
  assert_ne "0" "$RC" "runner: a failing liveness gate fails the run"
  assert_contains "$OUT" "STUB GATE FINDING" "runner: gate findings reach the operator"
  assert_contains "$OUT" "1 passed" "runner: the suite still runs after the gate fails"
}

# ---------------------------------------------------------------
# Case 8: registration membership is exact and stable over many entries
# (a set test, not a pipe into a consumer that can exit early).
# ---------------------------------------------------------------
test_liveness_gate_membership_is_stable() {
  local dir="$FIXTURE_DIR/gate_fixture"
  mkdir -p "$dir"
  local f="$dir/test_many.sh" i
  {
    echo '#!/usr/bin/env bash'
    for i in $(seq 1 200); do echo "test_case_$i() { :; }"; done
    for i in $(seq 1 200); do echo "run_test test_case_$i"; done
  } > "$f"
  local run out rc
  for run in 1 2 3 4 5; do
    out=$(bash "$REPO_ROOT/scripts/check_test_liveness.sh" "$dir" 2>&1)
    rc=$?
    assert_rc 0 "$rc" "liveness gate: 200 registered cases pass (run $run)"
    assert_contains "$out" "0 finding(s)" "liveness gate: no false finding (run $run)"
  done
}

run_test test_timeout_of_term_ignoring_file
run_test test_zero_unit_report_fails
run_test test_output_modes_and_unknown_option
run_test test_nonzero_exit_with_clean_report
run_test test_malformed_record_fails
run_test test_diagnostic_and_summary_streams
run_test test_liveness_gate_failure_does_not_skip_suite
run_test test_liveness_gate_membership_is_stable

test_done "test_runner_contract"
