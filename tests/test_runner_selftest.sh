#!/usr/bin/env bash
# TEST_DEADLINE: 10
#   Budget rationale: this file spawns the runner once per case, so its
#   honest runtime is about 7s; the declaration states that budget instead
#   of raising the default deadline for every file.
# tests/test_runner_selftest.sh
#
# Pins cite: code-owner -- tests/libs/test_common.sh run_test unit-marker
# contract; scripts/run_tests.sh (runner grep).

# Self-test of scripts/run_tests.sh  --  the runner is load-bearing
# infrastructure (every other suite's green/red signal passes through it),
# so its counting and reporting contract is locked here. Each pinned
# contract lives next to its code under a numbered `# Case` banner; the
# banners are the index, so no separate enumeration is kept here.
#
# Uses RUN_TESTS_DIR to point the runner at synthetic files and
# RUN_TESTS_SELFTEST to skip the registration liveness gate (the gate scans
# the real suite on every run; the fixtures are not part of the registration
# contract). Each case runs in its own isolated test with its own fixture
# directory.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

RUNNER="$REPO_ROOT/scripts/run_tests.sh"

# run_runner DIR  --  executes the runner against DIR; sets OUT and RC.
run_runner() {
  OUT=$(RUN_TESTS_SELFTEST=1 RUN_TESTS_DIR="$1" bash "$RUNNER" 2>&1)
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
  assert_contains "$OUT" "2 tests across 1 files, 1 passed, 0 failed, 1 skipped" \
    "runner: skip counted in the aggregate total"
  assert_contains "$OUT" "WARN test_skippy.sh (1 skipped)" "runner: skip surfaces the per-file WARN"
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
  OUTRC=$(PREREQ_STUB="/nonexistent/docker-stub" RUN_TESTS_SELFTEST=1 RUN_TESTS_DIR="$FIXTURE_DIR/prereq_dir" bash "$RUNNER" 2>&1)
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
  OUTRC=$(PREREQ_STUB="$FIXTURE_DIR/good_stub" RUN_TESTS_SELFTEST=1 RUN_TESTS_DIR="$FIXTURE_DIR/good_stub_dir" bash "$RUNNER" 2>&1)
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
  OUTRC=$(TEST_PARALLEL=4 TEST_TIMEOUT=1 RUN_TESTS_SELFTEST=1 RUN_TESTS_DIR="$dir" bash "$RUNNER" 2>&1)
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

# ---------------------------------------------------------------
# Case 15: a file that declares its own deadline in its header uses it, both
# when the declaration is shorter than TEST_TIMEOUT and when it is longer (the
# reason the declaration exists: a heavy harness file).
# ---------------------------------------------------------------
test_runner_per_file_deadline_declaration() {
  local dir="$FIXTURE_DIR/deadline_short_dir"
  mkdir -p "$dir"
  write_test "$dir/test_declared_hang.sh" '#!/usr/bin/env bash
# TEST_DEADLINE: 1
sleep 30'
  local OUTRC
  OUTRC=$(TEST_PARALLEL=4 TEST_TIMEOUT=9 RUN_TESTS_SELFTEST=1 RUN_TESTS_DIR="$dir" bash "$RUNNER" 2>&1)
  local rc=$?
  assert_ne "0" "$rc" "runner: a file beating its declared deadline fails"
  assert_contains "$OUTRC" "TIMEOUT test_declared_hang.sh (exceeded 1s deadline)" \
    "runner: the declared deadline, not the global one, is named on expiry"

  dir="$FIXTURE_DIR/deadline_long_dir"
  mkdir -p "$dir"
  write_test "$dir/test_declared_slow.sh" '#!/usr/bin/env bash
# TEST_DEADLINE: 3
sleep 1.5
printf "UNIT: pass=1 fail=0 skip=0\n"'
  OUTRC=$(TEST_PARALLEL=4 TEST_TIMEOUT=1 RUN_TESTS_SELFTEST=1 RUN_TESTS_DIR="$dir" bash "$RUNNER" 2>&1)
  rc=$?
  assert_rc 0 "$rc" "runner: a declaration longer than the global deadline lets a slow file pass"
}

# ---------------------------------------------------------------
# Case 16: an explicit file argument runs exactly that file. A missing file
# is a named error. Repeated paths run once (a selection is an order, not
# a set). RUN_TESTS_DIR is present in the first runs so a regression that
# drops the arguments fails fast on the fixtures instead of discovering
# the real suite.
# ---------------------------------------------------------------
test_runner_file_argument_selects_one_file() {
  local dir="$FIXTURE_DIR/file_arg_dir"
  mkdir -p "$dir"
  write_test "$dir/test_a.sh" '#!/usr/bin/env bash
printf "UNIT: pass=1 fail=0 skip=0\n"'
  write_test "$dir/test_b.sh" '#!/usr/bin/env bash
printf "UNIT: pass=1 fail=0 skip=0\n"'
  local OUT RC
  OUT=$(RUN_TESTS_SELFTEST=1 RUN_TESTS_DIR="$dir" bash "$RUNNER" "$dir/test_a.sh" 2>&1)
  RC=$?
  assert_rc 0 "$RC" "runner: a single file argument runs green"
  assert_contains "$OUT" "1 tests across 1 files, 1 passed, 0 failed, 0 skipped" \
    "runner: a single file argument runs exactly that file"

  OUT=$(RUN_TESTS_SELFTEST=1 RUN_TESTS_DIR="$dir" bash "$RUNNER" "$dir/test_a.sh" "$dir/test_a.sh" 2>&1)
  RC=$?
  assert_rc 0 "$RC" "runner: repeated file arguments run green"
  assert_contains "$OUT" "1 tests across 1 files, 1 passed, 0 failed, 0 skipped" \
    "runner: repeated paths run once"

  OUT=$(RUN_TESTS_SELFTEST=1 bash "$RUNNER" "$dir/missing.sh" 2>&1)
  RC=$?
  assert_ne "0" "$RC" "runner: a missing file argument exits non-zero"
  assert_contains "$OUT" "ERROR: no such test file: $dir/missing.sh" \
    "runner: a missing file argument is a named error"
}

# ---------------------------------------------------------------
# Case 17: a directory argument runs its test_*.sh files and ignores every
# other file in the directory.
# ---------------------------------------------------------------
test_runner_directory_argument() {
  local dir="$FIXTURE_DIR/dir_arg_dir"
  mkdir -p "$dir"
  write_test "$dir/test_a.sh" '#!/usr/bin/env bash
printf "UNIT: pass=1 fail=0 skip=0\n"'
  write_test "$dir/test_b.sh" '#!/usr/bin/env bash
printf "UNIT: pass=1 fail=0 skip=0\n"'
  # A non-test_ file in the same directory must not be picked up: without a
  # UNIT: report it would fail the run if it were.
  write_test "$dir/helper.sh" 'echo "not a test file"'
  local OUT RC
  OUT=$(RUN_TESTS_SELFTEST=1 bash "$RUNNER" "$dir" 2>&1)
  RC=$?
  assert_rc 0 "$RC" "runner: a directory argument runs green"
  assert_contains "$OUT" "2 tests across 2 files, 2 passed, 0 failed, 0 skipped" \
    "runner: a directory argument runs its test_*.sh files only"
}

# ---------------------------------------------------------------
# Case 18: the TEST_FILES environment variable selects the named files when
# no file or directory arguments are given. A third file in the same
# directory stays out of the run.
# ---------------------------------------------------------------
test_runner_test_files_env() {
  local dir="$FIXTURE_DIR/testfiles_dir"
  mkdir -p "$dir"
  write_test "$dir/test_x.sh" '#!/usr/bin/env bash
printf "UNIT: pass=1 fail=0 skip=0\n"'
  write_test "$dir/test_y.sh" '#!/usr/bin/env bash
printf "UNIT: pass=1 fail=0 skip=0\n"'
  write_test "$dir/test_z.sh" '#!/usr/bin/env bash
printf "UNIT: pass=1 fail=0 skip=0\n"'
  local OUT RC
  OUT=$(RUN_TESTS_SELFTEST=1 RUN_TESTS_DIR="$dir" TEST_FILES="$dir/test_x.sh $dir/test_y.sh" bash "$RUNNER" 2>&1)
  RC=$?
  assert_rc 0 "$RC" "runner: a TEST_FILES selection runs green"
  assert_contains "$OUT" "2 tests across 2 files, 2 passed, 0 failed, 0 skipped" \
    "runner: TEST_FILES runs exactly the named files"
}

# ---------------------------------------------------------------
# Case 19: --help and -h print the usage block and exit 0; an unknown
# option still names itself, hints at --help, and exits non-zero.
# ---------------------------------------------------------------
test_runner_help_and_unknown_option() {
  local OUT RC
  OUT=$(RUN_TESTS_SELFTEST=1 bash "$RUNNER" --help 2>&1)
  RC=$?
  assert_rc 0 "$RC" "runner: --help exits 0"
  assert_contains "$OUT" "Usage" "runner: --help prints the usage block"
  assert_contains "$OUT" "TEST_FILES" "runner: --help names the TEST_FILES selector"

  OUT=$(RUN_TESTS_SELFTEST=1 bash "$RUNNER" -h 2>&1)
  RC=$?
  assert_rc 0 "$RC" "runner: -h exits 0"

  OUT=$(RUN_TESTS_SELFTEST=1 bash "$RUNNER" --bogus 2>&1)
  RC=$?
  assert_ne "0" "$RC" "runner: an unknown option exits non-zero"
  assert_contains "$OUT" "Unknown option: --bogus" "runner: an unknown option names itself"
}

# ---------------------------------------------------------------
# Case 20: the registration liveness gate runs on every run, selected or
# not; only RUN_TESTS_SELFTEST=1 skips it. The gate stub records the
# directory it was asked to scan instead of scanning anything, so the marker
# exists only when the runner points the gate at the real suite.
# ---------------------------------------------------------------
test_runner_gate_attribution() {
  local dir="$FIXTURE_DIR/attr_dir"
  mkdir -p "$dir"
  write_test "$dir/test_a.sh" '#!/usr/bin/env bash
printf "UNIT: pass=1 fail=0 skip=0\n"'
  local marker="$FIXTURE_DIR/gate_ran.marker"
  local gate="$FIXTURE_DIR/marker_gate.sh"
  printf '#!/usr/bin/env bash\n[[ "$1" == "%s" ]] && touch "%s"\nexit 0\n' \
    "$REPO_ROOT/tests" "$marker" > "$gate"
  chmod +x "$gate"

  local OUT RC
  rm -f "$marker"
  # A subset run (a file argument, with the discovery override present too)
  # still gates the whole suite: the marker must appear.
  OUT=$(LIVENESS_GATE="$gate" RUN_TESTS_DIR="$dir" bash "$RUNNER" "$dir/test_a.sh" 2>&1)
  RC=$?
  assert_rc 0 "$RC" "runner: a selected run with the gate passes"
  assert_file_exists "$marker" "runner: the whole-suite gate ran under a subset selection"
  assert_contains "$OUT" "1 tests across 1 files, 1 passed, 0 failed, 0 skipped" \
    "runner: the file argument defined the run"

  rm -f "$marker"
  OUT=$(RUN_TESTS_SELFTEST=1 LIVENESS_GATE="$gate" bash "$RUNNER" "$dir/test_a.sh" 2>&1)
  RC=$?
  assert_rc 0 "$RC" "runner: a self-test run passes"
  if [[ -e "$marker" ]]; then
    fail "runner: the gate ran despite RUN_TESTS_SELFTEST=1"
  else
    pass "runner: only RUN_TESTS_SELFTEST=1 skips the gate"
  fi
  assert_contains "$OUT" "NOTE: registration liveness gate skipped (RUN_TESTS_SELFTEST=1)" \
    "runner: the self-test skip is announced on stderr"
}

# ---------------------------------------------------------------
# Case 21: positional file arguments beat the TEST_FILES environment
# variable: both given, the arguments define the run.
# ---------------------------------------------------------------
test_runner_arguments_override_test_files() {
  local dir="$FIXTURE_DIR/override_dir"
  mkdir -p "$dir"
  write_test "$dir/test_a.sh" '#!/usr/bin/env bash
printf "UNIT: pass=1 fail=0 skip=0\n"'
  write_test "$dir/test_b.sh" '#!/usr/bin/env bash
printf "UNIT: pass=1 fail=0 skip=0\n"'
  write_test "$dir/test_c.sh" '#!/usr/bin/env bash
printf "UNIT: pass=1 fail=0 skip=0\n"'
  local OUT RC
  OUT=$(RUN_TESTS_SELFTEST=1 RUN_TESTS_DIR="$dir" TEST_FILES="$dir/test_c.sh" bash "$RUNNER" "$dir/test_a.sh" "$dir/test_b.sh" 2>&1)
  RC=$?
  assert_rc 0 "$RC" "runner: arguments and TEST_FILES together run green"
  assert_contains "$OUT" "2 tests across 2 files, 2 passed, 0 failed, 0 skipped" \
    "runner: positional arguments beat TEST_FILES"
}

# -- shared helper contracts ---------------------------------------------------

# -- assert_run --

_exit_zero() { exit 0; }
_exit_three() { exit 3; }

# Given: a command that exits 0
# When:  assert_run 0 runs
# Then:  it passes
# Asserts: the harness assert_run pass side (test_common.sh helper; finding 4).
test_subshell_rc_matches_expected() {
  assert_run 0 _exit_zero "assert_run passes on matching rc"
}

# Given: a command that exits 3
# When:  assert_run 0 runs in a bash -c probe
# Then:  it fails with the expected-rc marker and increments the counter
# Asserts: the harness assert_run fail side, proven out-of-process (test_common.sh helper; finding 4).
test_subshell_rc_mismatch_fails() {
  # The probe's fail() emits a detail marker and increments the counter;
  # run the probe in a bash -c subprocess so its fail-fast exit does not
  # abort this test, then assert on the accumulated counter and marker.
  local OUT
  OUT=$(bash -c "
    source '$REPO_ROOT/tests/libs/test_common.sh'
    _exit_three() { exit 3; }
    assert_run 0 _exit_three probe
    echo \"count=\$FAIL\"
  ")
  if [[ "$OUT" == *"count=1"* && "$OUT" == *"FAIL: probe (expected rc=0"* ]]; then
    pass "assert_run fails on rc mismatch (marker + counter)"
  else
    fail "assert_run did not fail on rc mismatch"
  fi
}

# -- source_function_from --

# Given: a source file with a named function
# When:  source_function_from extracts it
# Then:  the function is invocable
# Asserts: function extraction works (test_common.sh helper; finding 4).
test_source_function_from_extracts_and_defines() {
  local FIXTURE="$FIXTURE_DIR/extract_src.sh"
  printf 'unrelated() { :; }\nextracted_fn() { EXTRACTED_MARK=works; }\ntrailing() { :; }\n' > "$FIXTURE"
  source_function_from "$FIXTURE" extracted_fn
  extracted_fn
  if [[ "${EXTRACTED_MARK:-}" == "works" ]]; then
    pass "source_function_from defines an invocable function"
  else
    fail "source_function_from did not define an invocable function"
  fi
}

# Given: a source file without the named function
# When:  source_function_from runs
# Then:  it fails
# Asserts: extraction fails loudly on a miss (test_common.sh helper; finding 4).
test_source_function_from_fails_when_pattern_missing() {
  local FIXTURE="$FIXTURE_DIR/extract_missing.sh"
  printf 'other() { :; }\n' > "$FIXTURE"
  if source_function_from "$FIXTURE" absent_fn 2>/dev/null; then
    fail "source_function_from should fail when the function is not extractable"
  else
    pass "source_function_from fails with named error when pattern missing"
  fi
}

# Given: a fixture unit that calls skip
# When:  the fixture runs
# Then:  it exits 0, emits the SKIP marker, and counts one skipped
# Asserts: a skip is a warning, not a failure (test_common.sh helper; finding 4).
test_skip_counts_as_skipped_unit() {
  # skip() goes through the real _run_one in a fresh script, so the shared
  # counters here are unaffected and the suite keeps a committed skip count of
  # zero. The fixture asserts the third unit outcome: skipped, not passed.
  local fixture="$FIXTURE_DIR/skip_me.sh"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    "source '$REPO_ROOT/tests/libs/test_common.sh'" \
    'test_pending() { skip "operation not yet stubbed"; }' \
    'run_test test_pending' \
    'test_done' > "$fixture"
  local out rc
  out="$(bash "$fixture" 2>&1)"; rc=$?
  assert_rc 0 "$rc" "a skipped file exits 0 (warning, not failure)"
  assert_contains "$out" "  SKIP: test_pending" "skip unit emits the SKIP marker"
  assert_contains "$out" "0 failed, 1 skipped" "the skipped unit is counted, not failed"
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
run_test test_runner_per_file_deadline_declaration
run_test test_runner_file_argument_selects_one_file
run_test test_runner_directory_argument
run_test test_runner_test_files_env
run_test test_runner_help_and_unknown_option
run_test test_runner_gate_attribution
run_test test_runner_arguments_override_test_files

run_test test_subshell_rc_matches_expected
run_test test_subshell_rc_mismatch_fails
run_test test_source_function_from_extracts_and_defines
run_test test_source_function_from_fails_when_pattern_missing
run_test test_skip_counts_as_skipped_unit

test_done test_runner_selftest.sh