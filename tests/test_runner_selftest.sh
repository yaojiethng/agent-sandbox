#!/usr/bin/env bash
# tests/test_runner_selftest.sh
#
# Self-test of scripts/run_tests.sh — the runner is load-bearing
# infrastructure (every other suite's green/red signal passes through it),
# so its counting contract is locked here:
#
#   1. A file whose tests all pass        → counted, RC 0
#   2. A file with a failing test         → FAIL marker counted, RC non-zero
#   3. A file that exits non-zero without markers (crash / silent zombie)
#                                         → flagged as failed
#   4. A file emitting a SKIP: marker     → treated as failure (policy)
#
# Uses RUN_TESTS_DIR to point the runner at synthetic files.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

RUNNER="$REPO_ROOT/scripts/run_tests.sh"

# run_runner DIR — executes the runner against DIR; sets OUT and RC.
run_runner() {
  OUT=$(RUN_TESTS_DIR="$1" bash "$RUNNER" 2>&1)
  RC=$?
}

# write_test FILE BODY — convenience for synthetic test files
write_test() {
  printf '%s\n' "$2" > "$1"
}

# ---------------------------------------------------------------
# Case 1: passing file → counted, rc 0
# ---------------------------------------------------------------
mkdir -p "$FIXTURE_DIR/pass_dir"
write_test "$FIXTURE_DIR/pass_dir/test_ok.sh" '#!/usr/bin/env bash
echo "  PASS: obvious truth"'
run_runner "$FIXTURE_DIR/pass_dir"
assert_rc 0 "$RC" "runner: all-pass directory exits 0"
assert_contains "$OUT" "1 passed" "runner: passing test counted"

# ---------------------------------------------------------------
# Case 2: failing test → FAIL marker counted, rc non-zero
# ---------------------------------------------------------------
mkdir -p "$FIXTURE_DIR/fail_dir"
write_test "$FIXTURE_DIR/fail_dir/test_bad.sh" '#!/usr/bin/env bash
echo "  PASS: setup step"
echo "  FAIL: broken assertion"'
run_runner "$FIXTURE_DIR/fail_dir"
assert_ne "0" "$RC" "runner: failing file gives non-zero exit"
assert_contains "$OUT" "1 failed" "runner: failing test counted once"

# ---------------------------------------------------------------
# Case 3: non-zero exit without markers → failure detected
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
# Case 4: SKIP marker → treated as failure (failed 0, skipped 0 policy)
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

# =============================================================================
# Run — note: this file drives the runner via run_runner(), so its own
# assertions live at file scope, not in run_test functions. Each block above
# asserts exactly the behaviour it sets up.
# =============================================================================

test_done
