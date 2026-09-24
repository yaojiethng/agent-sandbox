#!/usr/bin/env bash
# tests/test_runner_selftest.sh
#
# Pins cite: code-owner -- tests/libs/test_common.sh run_test unit-marker
# contract; scripts/run_tests.sh (runner grep).

# Self-test of scripts/run_tests.sh  --  the runner is load-bearing
# infrastructure (every other suite's green/red signal passes through it),
# so its counting contract is locked here under the per-test-unit accounting
# model:
#
#   1. A file whose tests all pass                 -> counted, RC 0
#   2. A file with a failing unit                  -> FAIL marker counted, RC non-zero
#   3. A file that exits non-zero without a UNIT: report (crash / silent
#      zombie)                                          -> flagged as failed
#   4. A file emitting a SKIP: marker              -> reported as a warning; the
#                                                  run still exits 0 (a temporary
#                                                  skip is not a failure)
#   5. Aggregate line reflects per-file unit counts
#   6. run_test without assertions fails; test_done emits no spurious FAIL marker
#   7. The zombie patterns: `cmd && pass` (fails at end-of-file) and an
#      undefined function (exit 127)
#   8. Multiple FAIL unit markers are counted exactly
#   9. A fail count with RC 0 still counts as failure (the fail count rides
#      the UNIT: report, not the exit code)
#   10. Empty discovery warns and exits non-zero without an unbound crash
#   11. A broken prerequisite is reported once, by name
#   12. run_test registered after test_done is dead code; the liveness gate
#      flags it
#
# Uses RUN_TESTS_DIR to point the runner at synthetic files. Each case runs
# in its own isolated test with its own fixture directory.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

RUNNER="$REPO_ROOT/scripts/run_tests.sh"

# run_runner DIR  --  executes the runner against DIR; sets OUT and RC.
run_runner() {
  OUT=$(RUN_TESTS_DIR="$1" bash "$RUNNER" 2>&1)
  RC=$?
}

# write_test FILE BODY  --  convenience for synthetic test files
write_test() {
  printf '%s\n' "$2" > "$1"
}

# ---------------------------------------------------------------
# Case 1: passing file -> counted, rc 0
# ---------------------------------------------------------------
test_runner_passing_file() {
  local dir="$FIXTURE_DIR/pass_dir"
  mkdir -p "$dir"
  write_test "$dir/test_ok.sh" '#!/usr/bin/env bash
printf "UNIT: pass=1 fail=0 skip=0\n"'
  run_runner "$dir"
  assert_rc 0 "$RC" "runner: all-pass directory exits 0"
  assert_contains "$OUT" "1 passed" "runner: passing test counted"
}

# ---------------------------------------------------------------
# Case 2: failing unit -> FAIL marker counted, rc non-zero
# ---------------------------------------------------------------
test_runner_failing_file() {
  local dir="$FIXTURE_DIR/fail_dir"
  mkdir -p "$dir"
  write_test "$dir/test_bad.sh" '#!/usr/bin/env bash
printf "UNIT: pass=0 fail=1 skip=0\n"
exit 1'
  run_runner "$dir"
  assert_ne "0" "$RC" "runner: failing file gives non-zero exit"
  assert_contains "$OUT" "1 failed" "runner: failing test counted once"
}

# ---------------------------------------------------------------
# Case 3: non-zero exit without markers -> failure detected
# (the silent-zombie class: crash before any assertion)
# ---------------------------------------------------------------
test_runner_crash_no_markers() {
  local dir="$FIXTURE_DIR/crash_dir"
  mkdir -p "$dir"
  write_test "$dir/test_crash.sh" '#!/usr/bin/env bash
echo "starting work..."
exit 3'
  run_runner "$dir"
  assert_ne "0" "$RC" "runner: marker-less crash exits non-zero"
  assert_contains "$OUT" "FAIL test_crash.sh" "runner: crashed file reported by name"
  assert_contains "$OUT" "no UNIT: report" "runner: crash carries an accompanying reason"
}

# ---------------------------------------------------------------
# Case 3b: a file that exits 0 with no UNIT: report (the silent-green class)
# is a failure -- a unit-test file must produce a report.
# ---------------------------------------------------------------
test_runner_missing_report_rc0() {
  local dir="$FIXTURE_DIR/noreport_dir"
  mkdir -p "$dir"
  write_test "$dir/test_noreport.sh" '#!/usr/bin/env bash
echo "no report emitted"
exit 0'
  run_runner "$dir"
  assert_ne "0" "$RC" "runner: rc 0 with no UNIT report is a failure"
  assert_contains "$OUT" "no UNIT: report" "runner: missing report named as the cause"
}

# ---------------------------------------------------------------
# Case 4: SKIP -> reported as a warning, not a failure
# ---------------------------------------------------------------
test_runner_skip_is_warning() {
  local dir="$FIXTURE_DIR/skip_dir"
  mkdir -p "$dir"
  write_test "$dir/test_skippy.sh" '#!/usr/bin/env bash
printf "UNIT: pass=1 fail=0 skip=1\n"'
  run_runner "$dir"
  assert_rc 0 "$RC" "runner: skip is a warning, not a failure"
  assert_contains "$OUT" "1 passed, 0 failed, 1 skipped" "runner: skip counted in the aggregate"
  assert_contains "$OUT" "WARN" "runner: skip surfaces a WARN"
}

# ---------------------------------------------------------------
# Case 5: aggregate line reflects per-file unit counts
# ---------------------------------------------------------------
test_runner_aggregate_sums() {
  local dir="$FIXTURE_DIR/mixed_dir"
  mkdir -p "$dir"
  write_test "$dir/test_a.sh" '#!/usr/bin/env bash
printf "UNIT: pass=2 fail=0 skip=0\n"'
  write_test "$dir/test_b.sh" '#!/usr/bin/env bash
printf "UNIT: pass=1 fail=0 skip=0\n"'
  run_runner "$dir"
  assert_contains "$OUT" "3 tests across 2 files, 3 passed, 0 failed, 0 skipped" \
    "runner: aggregate line sums across files"
}

# ---------------------------------------------------------------
# Case 6: run_test without assertions fails (silent test proves nothing)
# ---------------------------------------------------------------
test_runner_no_assertion() {
  local dir="$FIXTURE_DIR/noassert_dir"
  mkdir -p "$dir"
  write_test "$dir/test_noassert.sh" "#!/usr/bin/env bash
source '$REPO_ROOT/tests/libs/test_common.sh'
t_noop() { :; }
run_test t_noop
test_done"
  run_runner "$dir"
  assert_ne "0" "$RC" "runner: assertion-less run_test fails the file"
  assert_contains "$OUT" "1 failed" "runner: NO-ASSERTION failure counted via run_test unit marker"
}

# ---------------------------------------------------------------
# Case 7: the recorded zombie patterns.
# (a) `cmd && pass`: cmd fails, the && list is the last command, so the
#     file exits with its failure status and no PASS is emitted  --
#     a silent green that proves nothing unless the runner catches it.
# (b) undefined function: exit 127 with no markers.
# ---------------------------------------------------------------
test_runner_zombie_command_and_pass() {
  local dir="$FIXTURE_DIR/zombie_dir"
  mkdir -p "$dir"
  write_test "$dir/test_zombie_and_pass.sh" '#!/usr/bin/env bash
false && echo "  PASS: never reaches here"'
  run_runner "$dir"
  assert_ne "0" "$RC" "runner: cmd&&pass zombie exits non-zero"
  assert_contains "$OUT" "FAIL test_zombie_and_pass.sh" "runner: cmd&&pass zombie reported by name"
}

test_runner_zombie_undefined_fn() {
  local dir="$FIXTURE_DIR/zombie_dir"
  mkdir -p "$dir"
  write_test "$dir/test_zombie_undef_fn.sh" '#!/usr/bin/env bash
nonexistent_helper_fn'
  run_runner "$dir"
  assert_ne "0" "$RC" "runner: undefined-function zombie exits non-zero"
  assert_contains "$OUT" "FAIL test_zombie_undef_fn.sh" "runner: undefined-function zombie reported by name"
}

# ---------------------------------------------------------------
# Case 8: multiple FAIL markers are counted exactly
# ---------------------------------------------------------------
test_runner_multiple_fails() {
  local dir="$FIXTURE_DIR/multifail_dir"
  mkdir -p "$dir"
  write_test "$dir/test_multi.sh" '#!/usr/bin/env bash
printf "UNIT: pass=0 fail=2 skip=0\n"
exit 2'
  run_runner "$dir"
  assert_ne "0" "$RC" "runner: multi-fail file exits non-zero"
  assert_contains "$OUT" "2 tests across 1 files, 0 passed, 2 failed, 0 skipped" \
    "runner: each failing unit counted"
}

# ---------------------------------------------------------------
# Case 9: a FAIL marker with RC 0 still counts as failure
# (markers trump exit code  --  the counting contract the suite's
# green/red signal rests on)
# ---------------------------------------------------------------
test_runner_fail_marker_trumps_rc0() {
  local dir="$FIXTURE_DIR/marker_rc0_dir"
  mkdir -p "$dir"
  write_test "$dir/test_marker_rc0.sh" '#!/usr/bin/env bash
printf "UNIT: pass=0 fail=1 skip=0\n"
exit 0'
  run_runner "$dir"
  assert_ne "0" "$RC" "runner: FAIL report with rc 0 fails the run"
  assert_contains "$OUT" "1 failed" "runner: fail count honored despite rc 0"
}

# ---------------------------------------------------------------
# Case 10: empty discovery  --  the runner warns and exits non-zero
# without crashing on its own unset variables
# ---------------------------------------------------------------
test_runner_empty_discovery() {
  mkdir -p "$FIXTURE_DIR/empty_dir"
  run_runner "$FIXTURE_DIR/empty_dir"
  assert_ne "0" "$RC" "runner: empty discovery exits non-zero"
  assert_contains "$OUT" "Warning: no test files found" "runner: empty discovery warns"
  assert_not_contains "$OUT" "unbound variable" "runner: warning path does not crash under set -u"
}

# ---------------------------------------------------------------
# Case 11: a broken prerequisite (missing/non-executable docker stub)
# is reported once, by name, before any test runs.
# ---------------------------------------------------------------
test_runner_broken_prerequisite() {
  mkdir -p "$FIXTURE_DIR/prereq_dir"
  local OUTRC
  OUTRC=$(PREREQ_STUB="/nonexistent/docker-stub" RUN_TESTS_DIR="$FIXTURE_DIR/prereq_dir" bash "$RUNNER" 2>&1)
  local rc=$?
  assert_ne "0" "$rc" "runner: broken prerequisite exits non-zero"
  assert_contains "$OUTRC" "prerequisite missing or not executable" "runner: prerequisite error names the cause"
  assert_not_contains "$OUTRC" "no test files found" "runner: prerequisite check fires before discovery"
}

# A present, executable stub passes the prerequisite gate and proceeds to
# normal discovery (this directory has no tests -> the discovery warning).
test_runner_satisfied_prerequisite() {
  mkdir -p "$FIXTURE_DIR/good_stub_dir"
  printf '#!/bin/sh\nexit 0\n' > "$FIXTURE_DIR/good_stub"
  chmod +x "$FIXTURE_DIR/good_stub"
  local OUTRC
  OUTRC=$(PREREQ_STUB="$FIXTURE_DIR/good_stub" RUN_TESTS_DIR="$FIXTURE_DIR/good_stub_dir" bash "$RUNNER" 2>&1)
  assert_contains "$OUTRC" "Warning: no test files found" "runner: satisfied prerequisite proceeds to discovery"
  assert_not_contains "$OUTRC" "prerequisite missing" "runner: satisfied prerequisite emits no error"
}

# ---------------------------------------------------------------
# Case 12: run_test registered after test_done is dead code --
# test_done exits the process, so the runner scans the file
# statically and flags the file. The scan fires only on registrations
# that target a test_ function; payload words below are printed, not
# typed at column 0, so this file's own body stays scan-clean.
# ---------------------------------------------------------------
test_runner_dead_registration() {
  local dir="$FIXTURE_DIR/deadreg_dir"
  mkdir -p "$dir"
  local DEAD_BODY
  DEAD_BODY=$(printf '%b\n' \
    '#!/usr/bin/env bash' \
    "source '$REPO_ROOT/tests/libs/test_common.sh'" \
    'test_ok() { assert_eq a a; }' \
    'run_test test_ok' \
    'test_done' \
    'run_test test_dead')
  write_test "$dir/test_dead_reg.sh" "$DEAD_BODY"
  # The registration contract is owned by check_test_liveness.sh; point it at
  # the fixture and assert it flags the dead registration.
  local OUTRC rc
  OUTRC=$(bash "$REPO_ROOT/scripts/check_test_liveness.sh" "$dir" 2>&1)
  rc=$?
  assert_ne "0" "$rc" "liveness gate: dead registration after test_done fails the gate"
  assert_contains "$OUTRC" "DEAD-REGISTRATION" "liveness gate: dead registration reported"
  assert_contains "$OUTRC" "test_dead_reg.sh" "liveness gate: dead registration reported by file name"
}

# ---------------------------------------------------------------
# Case 13: a file that beats the deadline is reported and fails the
# run (the pure-bash per-file timeout). TEST_TIMEOUT is the contract.
# ---------------------------------------------------------------
test_runner_deadline_expiry() {
  local dir="$FIXTURE_DIR/timeout_dir"
  mkdir -p "$dir"
  write_test "$dir/test_hang.sh" \
    '#!/usr/bin/env bash
sleep 30'
  local OUTRC
  OUTRC=$(TEST_PARALLEL=4 TEST_TIMEOUT=1 RUN_TESTS_DIR="$dir" bash "$RUNNER" 2>&1)
  local rc=$?
  assert_ne "0" "$rc" "runner: a deadline-beating file fails the run"
  assert_contains "$OUTRC" "TIMEOUT test_hang.sh" "runner: deadline expiry reported by name"
}

# ---------------------------------------------------------------
# Case 14: many files under parallel dispatch are all counted exactly
# (no file lost to the worker scheduling) and the suite still exits 0.
# ---------------------------------------------------------------
test_runner_parallel_dispatch_integrity() {
  local dir="$FIXTURE_DIR/par_dir"
  mkdir -p "$dir"
  local i
  for i in $(seq 1 6); do
    write_test "$dir/test_p${i}.sh" '#!/usr/bin/env bash
printf "UNIT: pass=1 fail=0 skip=0\n"'
  done
  run_runner "$dir"
  assert_rc 0 "$RC" "runner: parallel all-pass directory exits 0"
  assert_contains "$OUT" "6 tests across 6 files, 6 passed, 0 failed, 0 skipped" \
    "runner: parallel dispatch counts every file exactly"
}

run_test test_runner_passing_file
run_test test_runner_failing_file
run_test test_runner_crash_no_markers
run_test test_runner_missing_report_rc0
run_test test_runner_skip_is_warning
run_test test_runner_aggregate_sums
run_test test_runner_no_assertion
run_test test_runner_zombie_command_and_pass
run_test test_runner_zombie_undefined_fn
run_test test_runner_multiple_fails
run_test test_runner_fail_marker_trumps_rc0
run_test test_runner_empty_discovery
run_test test_runner_broken_prerequisite
run_test test_runner_satisfied_prerequisite
run_test test_runner_dead_registration
run_test test_runner_deadline_expiry
run_test test_runner_parallel_dispatch_integrity

test_done test_runner_selftest.sh