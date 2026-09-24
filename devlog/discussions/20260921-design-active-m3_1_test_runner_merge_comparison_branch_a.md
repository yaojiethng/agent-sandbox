# Design: M3.1 test-runner merge comparison (branch A -- off-branch record)

**Date:** 2026-09-21
**Status:** active

## Context

M3.1 subsumes three tasks from the lint-and-tests-duration line: **Test suite duration**, **Individual per-test timeout**, and **Bash test-harness migration (accept/reject)**. The operator decided two parallel branches: branch A keeps the bespoke harness and adds dependency-free parallel plus a pure-bash deadline; branch B migrates the harness to bats-core. The operator merges whichever branch meets the shared invariants, giving an authoritative accept/reject decision on the bats migration. The operator holds the final call; this report is the working set for the session that runs the comparison.

The feature study holds the measurements and the framework matrix: [`20260921-study-active-lint_and_tests_duration.md`](20260921-study-active-lint_and_tests_duration.md). The study records the four harness-bug classes, the per-option axis matrix (bats-core / shunit2 / shellspec), and that bats-core alone solves the timeout class natively (`BATS_TEST_TIMEOUT`), while shellspec and shunit2 do not. The ~16.8k-line test tree is not absorbed by any framework; a migration converts it, it never deletes it.

## Resolved operator answers (no longer open)

From the study's four open questions, the operator has settled: run the tests in parallel (yes); add a per-test deadline (yes); default deadline ~5s. The framework acceptance is the open question this comparison decides.

## Comparison-methodology caveat

This comparison evaluates branch B at its minimal migration -- bespoke test bodies re-skinned as `@test` blocks with the `set +e; set +T` heads kept -- against branch A at the status-quo suite. The two suites are authored differently in kind, not just in harness: branch A runs tests in-process with a shared file-scoped `FIXTURE_DIR` and PASS-marker accounting; branch B runs each `@test` in an isolated subshell and counts test units. Judging the two harnesses while the suites are authored differently confounds the harness choice with the authoring model. This note corrects the comparison framing, not the measurements. The authoring equalization is owned by the unified test-harness improvement task (roadmap row **Test-harness improvement**): apply the harness-independent checklist to both suites, re-measure both, then compare on equal footing.

## Options Considered

Both branches fork from the shared base commit `56e33ff`. Branch A is built and verified; branch B does not yet exist. Build branch B from the same base `56e33ff`, alone on top of it, so the comparison is apples-to-apples and neither carries the other's changes.

### Option A - keep-current (branch A)

Branch `feat/M_3_1-backpressure-branch-A`. Changes `scripts/run_tests.sh` and the runner self-test. It keeps the bespoke harness and satisfies the two task drivers without any new dependency.

- Parallelity: `xargs -P8` dispatches one worker per test file (`TEST_PARALLEL`-overridable); the parent aggregates per-file records into one deterministic summary.
- Deadline: each worker runs its file under a pure-bash kill-on-expiry deadline; default 5s (`TEST_TIMEOUT`-overridable), 0.1s `kill -0` poll, `TERM` on expiry, reported as `TIMEOUT <file>` and counted a failure. No external `timeout` binary; GNU and BSD `sleep` accept fractional seconds; bash-3.2-safe.
- Invariants preserved: zero-skips-fails-the-run, verdict-exit, the FD-offset stdin fix, the registration-liveness gate, and the prerequisite check.
- Verified: suite 1046 tests across 58 files, 1046 passed, 0 failed, 0 skipped in ~9s wall (37s serial); runner self-test 32 assertions; lint and ShellCheck clean.

### Option B - bats-core (branch B, not built)

Migrate the test tree to bats-core v1.14, re-establish the docker-stub wiring and the zero-skip / verdict-exit contract in bats terms, and pin the dependency in the image, Dockerfile, and macOS bootstrap. Accepts the GNU-parallel (or rush) dependency that `--jobs` requires. The study expects this option to close the harness-bug classes by construction (static `@test` registration, own counters, `BATS_TEST_TIMEOUT`).

## Parity checklist for branch B

For a fair comparison, branch B must demonstrate every invariant branch A already meets. The merging agent verifies each as a pass/fail for branch B.

| Invariant | Branch A meets it via | Branch B must meet it via |
|---|---|---|
| Parallel execution | `xargs -P8` (`TEST_PARALLEL`) | `--jobs N` (GNU-parallel or rush) |
| Per-test deadline, kill counts as failure | pure-bash `TERM`, rc 124, `TIMEOUT` line | `BATS_TEST_TIMEOUT` |
| Zero skips fail the run | runner flags `TOTAL_SKIP>0`, exits 1 | keep the `make test` zero-skip invariant |
| Any failure fails the run (verdict exit) | parent aggregates records, exit 1 | bats non-zero exit contract on failure |
| Deterministic count summary | parent sums per-file records | a stable formatter (tap13/junit), not order-coupled lines |
| Docker-stub prerequisite + per-test stub wiring | prerequisite check + stubs | re-establish the same stub wiring |
| Registration-liveness guard | parent awk scan | static registration makes the class vanish; still verify coverage is not lost |
| Runner regressions locked | self-test, 32 assertions | an equivalent guard, or retire it with rationale |

## Harness-improvement items for branch A (list 2)

To reach a bar equivalent to branch B's intrinsic isolation and accounting, branch A must add harness machinery it does not currently have. These four items are one coupled redesign: the first two break the in-process `PASS`/`FAIL`/`FAILURES[]` model, and the last two rebuild how results cross the subprocess boundary.

1. **Fail-fast assertions** -- a failed assertion terminates the current test rather than incrementing a counter and continuing. Branch B's `fail()` already exits non-zero.
2. **Subshell-per-test isolation** -- each test runs in its own subshell, so variable, trap, cwd, and exported-env state cannot leak across the tests of one file. This is the intra-file half of isolation; branch A already has cross-file process isolation through the `xargs` workers. It is the real gap against bats.
3. **Unit-level accounting** -- "N tests" reports one count per test unit, not one per PASS-marker, so the suite's test count means tests. Branch B already counts test units.
4. **Counting-model rewire** -- to support items 1 and 2, pass/fail results must route out of each test's subshell (exit statuses or a per-test results file) and the parent must aggregate them, replacing the in-process counters and grepped markers.

Each item is real engineering on branch A, not a test-authoring change. The operator green-lights this redesign independently of the parity checklist; applying all four is how branch A reaches functional parity with branch B on isolation and accounting.

## Decision

The operator merges the branch that meets the checklist above and best satisfies the study's deciding axis: bug reduction of the four harness-bug classes, versus the migration cost. The lean tie-break is branch A: it is dependency-free, verified, and already measured (37s to ~9s). The merging agent accepts bats only if branch B shows a bug class it closes that branch A does not, at a cost the project accepts (the GNU-parallel dependency, the image/Dockerfile/macOS pin, and the one-time 16.8k-line test-tree conversion). If the checklist is not met to parity, keep branch A and reject the migration with the finding recorded.

## Consequences

- Whichever lands, close the two roadmap rows **Test suite duration** and **Individual per-test timeout**, and close the **Bash test-harness migration** row as accepted or rejected.
- A bats accept means branch B supersedes branch A; a keep-current accept means the bats option is rejected and branch A supplies the test-runner change.
- The losing branch is archived as the comparison record, not merged.
- With the two rows closed, M3.1 holds only closed rows and the sub-milestone folds back into M3 with its close ceremony.
- Record the decision as an ADR per the decision policy when the operator settles it.
