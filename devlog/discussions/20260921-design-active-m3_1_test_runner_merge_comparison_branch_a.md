# Design: M3.1 test-runner merge comparison (branch A status and decision protocol)

**Date:** 2026-09-21 (rebased 2026-09-22)
**Status:** settled
**Branch:** `feat/M_3_1-backpressure-branch-A`
**Settled by:** [`20260922-design-settled-m3_1_test_harness_decision.md`](20260922-design-settled-m3_1_test_harness_decision.md) - keep-current merged; bats rejected; branch B archived.

## Context

M3.1 subsumes three tasks from the lint-and-tests-duration line: **Test suite duration**, **Individual per-test timeout**, and **Bash test-harness migration (accept/reject)**. The operator runs two branches: branch A keeps the bespoke harness and adds dependency-free parallel plus a pure-bash deadline; branch B migrates the harness to bats-core. The operator merges whichever branch meets the shared invariants. The operator holds the final call; this report is the working set for the session that runs the comparison.

The main line landed the **Test-harness improvement (unified plan)** task (roadmap row, U1-U7). It applies the harness-independent authoring checklist to the bespoke suite and supersedes the earlier two-branch parity framing. The roadmap flags the re-port mechanic (rebase or re-branch) as open. The harness decision and the two-branch comparison stay deferred pending the unified harness.

The feature study holds the measurements and the framework matrix: [`20260921-study-active-lint_and_tests_duration.md`](20260921-study-active-lint_and_tests_duration.md). It records the four harness-bug classes, the per-option axis matrix (bats-core / shunit2 / shellspec), and that bats-core alone solves the timeout class natively (`BATS_TEST_TIMEOUT`). The ~16.8k-line test tree is not absorbed by any framework.

## Rebase reconciliation

Branch A originally sat on the pre-harness base `56e33ff`. The main line moved forward through the unified harness U1-U7, absorbing the study rewrite, the doc-test and conventions fixes, and the roadmap updates. This report (branch A) was rebased onto `feat/M_3_1-backpressure` (`03e9cf2`):

- The superseded commit `56e33ff` (study, doc-test fix, Anti-Pattern 8, roadmap) was dropped; the main line already carries equivalent or newer content.
- The parallel + deadline rewrite (`scripts/run_tests.sh`, the two new self-test cases) was re-applied onto the unified harness.
- The branch-A-specific report was kept as a branch-local record (this file, renamed `-branch_A`).

The re-applied runner works against the new per-test-unit harness: suite green, order-independence gate green, lint green.

## Resolved operator answers (no longer open)

From the study's original open questions, the operator settled: run the tests in parallel (yes); add a per-test deadline (yes); default deadline ~5s. The framework acceptance is the open question the comparison decides.

## Options Considered

Both branches now fork from `feat/M_3_1-backpressure` (unified harness). Each re-ports its harness-specific half onto the same base, so the comparison is apples-to-apples and neither carries the other's changes.

### Option A - keep-current (branch A)

Branch `feat/M_3_1-backpressure-branch-A`. Changes `scripts/run_tests.sh` (parallel + deadline) on top of the unified harness; nothing else.

- Parallelity: `xargs -P8` dispatches one worker per test file (`TEST_PARALLEL`-overridable); the parent aggregates per-file records into one deterministic summary.
- Deadline: each worker runs its file under a pure-bash kill-on-expiry deadline; default 5s (`TEST_TIMEOUT`-overridable), 0.1s `kill -0` poll, `TERM` on expiry, reported as `TIMEOUT <file>` and counted a failure. No external `timeout` binary; bash-3.2-safe.
- Invariants preserved: zero-skips-fails-the-run, verdict-exit, the FD-offset stdin fix, the registration-liveness gate, the prerequisite check, and order independence.

Measured on the unified harness (2026-09-22):

| Run | Wall | Units | Result |
|---|---|---|---|
| Serial (`TEST_PARALLEL=1`) | 48s | 712 | 712 passed, 0 failed, 0 skipped |
| Parallel (default `P8`) | 10s | 712 | 712 passed, 0 failed, 0 skipped |

Parallel is ~4.8x the serial time. Lint is Clean; the order-independence gate reports 58/58 clean; the runner self-test is 16 units green (the two new units lock the parallel-dispatch and deadline contracts).

### Option B - bats-core (branch B)

Migrate the test tree to bats-core v1.14 on the same unified base, re-establish the docker-stub wiring and the zero-skip / verdict-exit contract in bats terms, and pin the dependency in the image, Dockerfile, and macOS bootstrap. Accepts the GNU-parallel (or rush) dependency that `--jobs` requires. The study expects this option to close the harness-bug classes by construction (static `@test` registration, own counters, `BATS_TEST_TIMEOUT`).

## Fair-comparison protocol

Re-measure both branches on equal footing, after the authoring checklist applies to both. For each branch record wall, unit count, and the pass/fail/skip verdict. Compare branch A's dependency-free parallel + deadline against branch B's bats parallel + timeout, on the shared unified harness.

For a fair comparison, branch B must demonstrate every invariant branch A already meets.

| Invariant | Branch A meets it via | Branch B must meet it via |
|---|---|---|
| Parallel execution | `xargs -P8` (`TEST_PARALLEL`) | `--jobs N` (GNU-parallel or rush) |
| Per-test deadline, kill counts as failure | pure-bash `TERM`, rc 124, `TIMEOUT` line | `BATS_TEST_TIMEOUT` |
| Zero skips fail the run | runner flags `TOTAL_SKIP>0`, exits 1 | keep the `make test` zero-skip invariant |
| Any failure fails the run (verdict exit) | parent aggregates records, exit 1 | bats non-zero exit contract on failure |
| Deterministic count summary | parent sums per-file records | a stable formatter (tap13/junit), not order-coupled lines |
| Docker-stub prerequisite + per-test stub wiring | prerequisite check + stubs | re-establish the same stub wiring |
| Registration-liveness guard | parent awk scan | static registration makes the class vanish; still verify coverage is not lost |
| Runner regressions locked | self-test, 16 units | an equivalent guard, or retire it with rationale |

## Decision

The operator merges the branch that meets the checklist and best satisfies the study's deciding axis: bug reduction of the four harness-bug classes, versus the migration cost. The lean tie-break is branch A: it is dependency-free, verified, and measured (48s to 10s; ~4.8x). The merging agent accepts bats only if branch B shows a bug class it closes that branch A does not, at a cost the project accepts (the GNU-parallel dependency, the image/Dockerfile/macOS pin, and the one-time 16.8k-line test-tree conversion). If the checklist is not met to parity, keep branch A and reject the migration with the finding recorded.

The default ~5s deadline carries a parity note: under parallel contention the wall of a heavy file rises, so the margin against 5s is thinner than in serial. The parallel run stayed green (no spurious TIMEOUT); flag any near-deadline file to the operator before raising the default.

## Consequences

- Whichever lands, close the two roadmap rows **Test suite duration** and **Individual per-test timeout**, and close the **Bash test-harness migration** row as accepted or rejected.
- A bats accept means branch B supersedes branch A; a keep-current accept means the bats option is rejected and branch A supplies the test-runner change.
- The losing branch is archived as the comparison record, not merged.
- With the rows closed, M3.1 holds only closed rows and the sub-milestone folds back into M3 with its close ceremony.
- Record the decision as an ADR per the decision policy when the operator settles it.
