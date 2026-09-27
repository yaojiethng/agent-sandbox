# Agent Handover

**Date:** 2026-09-22
**Milestone:** M3.1 - Backpressure
**Type:** Impl
**Status:** Closed

## Objective

Re-port Track A and Track B onto the finished test harness (U1-U7 on the main line), re-measure both on equal footing, and settle the harness decision. This handover is the note for that session: the branch name identifies the track, and the approach for each track is decided here.

## Track identification

The branch name suffix carries the track:

| Branch | Track | Harness | Approach |
|---|---|---|---|
| `feat/M_3_1-backpressure-branch-A` (worktree `/tmp/brA`) | Track A | keep-current: `xargs -P8` parallel + pure-bash deadline | rebase |
| `feat/M_3_1-backpressure-branch-B` (worktree `/tmp/brB`) | Track B | bats-core migration | reimplement |

A session on `*-branch-A` is Track A; a session on `*-branch-B` is Track B. The branches fork from the pre-rewrite `56e33ff` era; main's history was rewritten (squash + reconcile), so re-porting targets main's current HEAD, and the branch reports and records describe suites that no longer exist.

## Decided approach

Governing rule: the tests (content, authoring, accounting) come from main; the track contributes only its harness change. That is equal footing.

- **Track A: rebase.** Its delta vs main is runner-shaped (7 files, +317/-54): `scripts/run_tests.sh` (+138), the selftest (+30), a few docs and records. Main barely changed `run_tests.sh`, so the runner patch replays near-clean. Main rewrote the selftest in U1: take main's and re-apply A's parallel and deadline coverage. Drop A's stale record diffs; main has consolidated records.
- **Track B: reimplement, do not replay B's old commits.** B's delta rewrites every test file top to bottom (83 files, +1314/-2519) against old authorship and old bodies. Replaying it would conflict wholesale and regress the U1-U7 authoring. Do a fresh `@test` conversion of main's finished 58 files, preserving the new authoring; reuse B's recorded methodology (minimal re-skin, `set +e; set +T` heads, launcher, liveness removal), not its patches.

## Pass-down notes (not derivable from the records)

1. The counting contract changed: the suite is 710 units (696 test functions + 14 selftest), counted by exactly-two-space `PASS:`/`FAIL:` markers. The old marker-vs-unit asymmetry is gone; both tracks measure units. Re-measure wall time fresh on the same machine; do not reuse the study's numbers.
2. The strict unit rule has a sharp edge: a test subshell's exit is its verdict, and a trailing command's rc can flip a passing test to a failure. Main's tests manage this deliberately (masks on trailing cleanup, rc asserts on success-expected commands). Keep the keep-current `run_test` byte-identical; map the rule to `@test` semantics on bats.
3. `get_fixture_dir` journals to a file, not an array: it is called inside `$( )`, whose array writes vanish into a sub-subshell. A port that "simplifies" it back to an array silently breaks teardown.
4. The assertion primitives carry contracts: `assert_run` plus `RUN_OUT` (never discard output), `trace_has` for conditions (`trace_grep` ends `|| true`; that shape produced a real vacuous assertion on main), and rc-asserted invocation helpers (the masked-rc class hid a real production defect: `scripts/prune.sh`'s exec bit).
5. B's runtime deps are still absent: no `ps`, `pkill`, `parallel`, or `bats` in the image, and `BATS_TEST_TIMEOUT` silently runs 0 tests without `ps` or `pkill`. Repeat the throwaway provisioning at measurement time; it is not committed anywhere.
6. The isolation probe must be harness-neutral: main's `REVERSE_RUN` gate is an in-process keep-current instrument; bats has no equivalent. Decide one probe (for example reversed per-file order across the whole suite) before measuring, or B's isolation claim stays structural rather than measured.
7. `test_done` is now universal (all 58 files; the inline-footer class is gone). A fresh bats port must not reintroduce footers or rely on the old structure.

## Acceptance criteria

Both tracks re-ported onto main's finished suite; equal-footing re-measurement of wall time, a harness-neutral isolation probe, and the final dependency count (Track A zero deps vs Track B bats + GNU parallel + procps); the harness decision recorded; then M3.1 close.

All five criteria accepted at close (2026-09-22); the pre-close summary holds the verified evidence.

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Keep-current runner (branch A) adopted; bats-core rejected | On equal footing branch B closes no bug class branch A lacks, and costs three runtime dependencies plus a slower suite | [`20260922-design-settled-m3_1_test_harness_decision.md`](../discussions/20260922-design-settled-m3_1_test_harness_decision.md); ADR [`docs/adr/test_harness.md`](../../docs/adr/test_harness.md) |
| Branch A merged by squash; branch B archived | Git-policy squash for a session branch; the losing branch stays as the comparison record | commits `3859ef0`, `9b54339` |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Branch A parallel ~4.7x (46s to 9.7s); branch B ~2.1x (65s to 31s at JOBS=8) | measurement | current iteration | decision record (class C) |
| Branch-B report claims corrected: 710 units not 709; 14 self-test cases not 13; the failing-test-holds-the-deadline claim did not reproduce (0.09s fail-fast at 5s and 60s deadlines) | measurement | current iteration | decision record (class C) |
| Branch B runs only after throwaway provisioning (bats, GNU parallel, procps are absent from the image); branch A runs dependency-free | measurement | recorded in the decision record | decision record (class C) |
| The branch-A session handover `20260921-14-test_parallel_and_deadline` collides in sequence with the main-line `20260921-14`; kept branch-local, not merged | contradiction | current iteration | Deferred items |

## Deferred items

| Item | Reason | Destination |
|---|---|---|
| Branch-A session handover `20260921-14-impl-m3_1_test_parallel_and_deadline.md` | sequence collision with the main-line `20260921-14`; a branch-local session record | stays archived on the branch ref |
| Branch-A comparison record under the capital name `...-branch_A.md` | branch-local naming; the main line keeps the established `_branch_a.md` name with refreshed content | stays archived on the branch ref |

## Completed

| File | Change |
|---|---|
| `scripts/run_tests.sh` | parallel dispatch and the pure-bash per-file deadline merged from branch A |
| `tests/test_runner_selftest.sh` | reconciled with the unified harness; 16 units lock the parallel and deadline contracts |
| `devlog/discussions/20260922-design-settled-m3_1_test_harness_decision.md` | new: the evaluation and the harness decision |
| `docs/adr/test_harness.md` | new: ADR for the keep-current harness decision |
| three comparison records | statuses settled or superseded, with pointers to the decision |

## What's Next

M3.1 fold-back ceremony: M3.1 holds only closed rows; fold it into M3, run the roadmap maintenance (summary-table status, changelog entry), and close. The design-document policy amendment (queued `[O] 2026-09-22`) is a separate small iteration, order free. The ADR name `test_harness.md` is recommended per `adr_policy.md`; the operator decides the final name.
