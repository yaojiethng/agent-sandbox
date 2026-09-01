#!/usr/bin/env bash
# tests/test_runner_selftest.sh
#
# Self-test of scripts/run_tests.sh  --  the runner is load-bearing
# infrastructure (every other suite's green/red signal passes through it),
# so its counting contract is locked here:
#
#   1. A file whose tests all pass        -> counted, RC 0
#   2. A file with a failing test         -> FAIL marker counted, RC non-zero
#   3. A file that exits non-zero without markers (crash / silent zombie)
#                                         -> flagged as failed
#   4. A file emitting a SKIP: marker     -> treated as failure (policy)
#   5. Aggregate line reflects per-file counts
#   6. run_test without assertions fails; test_done emits the exact
#      "  FAIL:" marker the runner greps
#   7. The zombie patterns: `cmd && pass` (fails at end-of-file under
#      set -e semantics) and an undefined function (exit 127)
#   8. Multiple FAIL markers are counted exactly
#   9. A FAIL marker with RC 0 still counts as failure (markers trump exit code)
#
# Uses RUN_TESTS_DIR to point the runner at synthetic files.

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
mkdir -p "$FIXTURE_DIR/pass_dir"
write_test "$FIXTURE_DIR/pass_dir/test_ok.sh" '#!/usr/bin/env bash
echo "  PASS: obvious truth"'
run_runner "$FIXTURE_DIR/pass_dir"
assert_rc 0 "$RC" "runner: all-pass directory exits 0"
assert_contains "$OUT" "1 passed" "runner: passing test counted"

# ---------------------------------------------------------------
# Case 2: failing test -> FAIL marker counted, rc non-zero
# ---------------------------------------------------------------
mkdir -p "$FIXTURE_DIR/fail_dir"
write_test "$FIXTURE_DIR/fail_dir/test_bad.sh" '#!/usr/bin/env bash
echo "  PASS: setup step"
echo "  FAIL: broken assertion"'
run_runner "$FIXTURE_DIR/fail_dir"
assert_ne "0" "$RC" "runner: failing file gives non-zero exit"
assert_contains "$OUT" "1 failed" "runner: failing test counted once"

# ---------------------------------------------------------------
# Case 3: non-zero exit without markers -> failure detected
# (the silent-zombie class: crash before any assertion)
# ---------------------------------------------------------------
mkdir -p "$FIXTURE_DIR/crash_dir"
write_test "$FIXTURE_DIR/crash_dir/test_crash.sh" '#!/usr/bin/env bash
echo "starting work..."
exit 3'
run_runner "$FIXTURE_DIR/crash_dir"
assert_ne "0" "$RC" "runner: marker-less crash exits non-zero"
assert_contains "$OUT" "FAIL test_crash.sh" "runner: crashed file reported by name"

# ---------------------------------------------------------------
# Case 4: SKIP marker -> treated as failure (failed 0, skipped 0 policy)
# ---------------------------------------------------------------
mkdir -p "$FIXTURE_DIR/skip_dir"
write_test "$FIXTURE_DIR/skip_dir/test_skippy.sh" '#!/usr/bin/env bash
echo "  PASS: works"
echo "  SKIP: optional seam missing"'
run_runner "$FIXTURE_DIR/skip_dir"
assert_ne "0" "$RC" "runner: skip counts as failure per make-test invariant"

# ---------------------------------------------------------------
# Case 5: aggregate line reflects per-file counts
# ---------------------------------------------------------------
mkdir -p "$FIXTURE_DIR/mixed_dir"
write_test "$FIXTURE_DIR/mixed_dir/test_a.sh" '#!/usr/bin/env bash
echo "  PASS: a1"
echo "  PASS: a2"'
write_test "$FIXTURE_DIR/mixed_dir/test_b.sh" '#!/usr/bin/env bash
echo "  PASS: b1"'
run_runner "$FIXTURE_DIR/mixed_dir"
assert_contains "$OUT" "3 tests across 2 files, 3 passed, 0 failed, 0 skipped" \
  "runner: aggregate line sums across files"

# ---------------------------------------------------------------
# Case 6: run_test without assertions fails; test_done emits the exact
# "  FAIL:" marker the runner greps. Locks both halves of the
# 20260821 mitigation for the silent-zombie class.
# ---------------------------------------------------------------
mkdir -p "$FIXTURE_DIR/noassert_dir"
write_test "$FIXTURE_DIR/noassert_dir/test_noassert.sh" "#!/usr/bin/env bash
source '$REPO_ROOT/tests/libs/test_common.sh'
t_noop() { :; }
run_test t_noop
test_done"
run_runner "$FIXTURE_DIR/noassert_dir"
assert_ne "0" "$RC" "runner: assertion-less run_test fails the file"
assert_contains "$OUT" "1 failed" "runner: NO-ASSERTION failure counted via test_done marker"

# ---------------------------------------------------------------
# Case 7: the recorded zombie patterns.
# (a) `cmd && pass`: cmd fails, the && list is the last command, so the
#     file exits with its failure status and no PASS is emitted  --
#     a silent green that proves nothing unless the runner catches it.
# (b) undefined function: exit 127 with no markers.
# ---------------------------------------------------------------
mkdir -p "$FIXTURE_DIR/zombie_dir"
write_test "$FIXTURE_DIR/zombie_dir/test_zombie_and_pass.sh" '#!/usr/bin/env bash
false && echo "  PASS: never reaches here"'
write_test "$FIXTURE_DIR/zombie_dir/test_zombie_undef_fn.sh" '#!/usr/bin/env bash
nonexistent_helper_fn'
run_runner "$FIXTURE_DIR/zombie_dir"
assert_ne "0" "$RC" "runner: zombie patterns (cmd&&pass, exit 127) exit non-zero"
assert_contains "$OUT" "FAIL test_zombie_and_pass.sh" "runner: cmd&&pass zombie reported by name"
assert_contains "$OUT" "FAIL test_zombie_undef_fn.sh" "runner: undefined-function zombie reported by name"

# ---------------------------------------------------------------
# Case 8: multiple FAIL markers are counted exactly
# ---------------------------------------------------------------
mkdir -p "$FIXTURE_DIR/multifail_dir"
write_test "$FIXTURE_DIR/multifail_dir/test_multi.sh" '#!/usr/bin/env bash
echo "  FAIL: first broken"
echo "  FAIL: second broken"'
run_runner "$FIXTURE_DIR/multifail_dir"
assert_ne "0" "$RC" "runner: multi-fail file exits non-zero"
assert_contains "$OUT" "2 tests across 1 files, 0 passed, 2 failed, 0 skipped" \
  "runner: each FAIL marker counted"

# ---------------------------------------------------------------
# Case 9: a FAIL marker with RC 0 still counts as failure
# (markers trump exit code  --  the counting contract the suite's
# green/red signal rests on)
# ---------------------------------------------------------------
mkdir -p "$FIXTURE_DIR/marker_rc0_dir"
write_test "$FIXTURE_DIR/marker_rc0_dir/test_marker_rc0.sh" '#!/usr/bin/env bash
echo "  FAIL: marker says broken"
exit 0'
run_runner "$FIXTURE_DIR/marker_rc0_dir"
assert_ne "0" "$RC" "runner: FAIL marker with rc 0 fails the run"
assert_contains "$OUT" "1 failed" "runner: FAIL marker counted despite rc 0"

# =============================================================================
# Run  --  note: this file drives the runner via run_runner(), so its own
# assertions live at file scope, not in run_test functions. Each block above
# asserts exactly the behaviour it sets up.
# =============================================================================

test_done
