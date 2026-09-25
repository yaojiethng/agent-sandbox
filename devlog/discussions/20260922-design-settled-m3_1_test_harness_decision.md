# Design: M3.1 test-harness decision (keep-current vs bats-core)

**Date:** 2026-09-22
**Status:** settled

## Context

The M3.1 harness line compares two test-runner approaches on parallel branches: branch A keeps the bespoke harness and adds dependency-free parallel plus a pure-bash deadline; branch B migrates the suite to bats-core. The comparison records are the framework study ([`20260921-study-settled-lint_and_tests_duration.md`](20260921-study-settled-lint_and_tests_duration.md)), the branch-A protocol record ([`20260921-design-settled-m3_1_test_runner_merge_comparison_branch_a.md`](20260921-design-settled-m3_1_test_runner_merge_comparison_branch_a.md)), and the branch-B report ([`20260921-study-superseded-m3_1_bats_harness_merge_branch_b.md`](20260921-study-superseded-m3_1_bats_harness_merge_branch_b.md)).

The earlier comparison was rejected for lack of a common basis: branch A ran tests in-process with PASS-marker accounting while branch B ran isolated `@test` subshells with unit accounting, so the harness choice was confounded with the authoring model. The unified test-harness improvement (U1-U7) remedied that. Both branches were re-ported onto the finished suite: an identical 696-unit name set on both (verified by set diff; the only count difference is the runner self-test, 16 units on branch A vs 14 on branch B). The operator released this session to record the evaluation and merge the winning branch.

## Options Considered

All numbers below were measured on 2026-09-22 on the 16-core host, both suites green and lint Clean, branch A dependency-free and branch B with throwaway-provisioned bats-core 1.14.0, GNU parallel 20260722, and procps 4.0.2 (none exist in the base image).

| Axis | Branch A (keep-current) | Branch B (bats-core) |
|---|---|---|
| Wall, serial | 46s | 65s |
| Wall, parallel (P8 / JOBS=8) | 9.7s (~4.7x) | 31s (~2.1x) |
| Verdict | 712/712 green | 710/710 green |
| Order-independence probe | 58/58 clean | normal equals reversed, totals identical |
| Runner self-test | 16/16 green | 14 green (via bats) |
| Runtime dependencies | zero | bats-core, GNU parallel, procps; none in the base image |
| Harness-bug classes 1-4 | closed (FD, dead registration, output-coupled count, timeout) | closed |

Branch A is faster on both serial and parallel wall, closes every harness-bug class the study named, and keeps two mechanical silent-green guards that branch B demotes to the authoring bar: the no-assertion detector (a body with zero assertions fails the run) and the trailing-rc zombie detector (a trailing non-zero command flips a pass to a fail). Branch B's measured advantage is deadline granularity: its deadline is per-test, so a hung test is killed at the deadline and the file continues; branch A's deadline is per-file, so a hung file loses the rest of its tests (the verdict stays red either way).

Corrected claims from the branch-B report: the suite is 710 units, not 709; the self-test is 14 cases, not 13; the claim that a failing test holds the bats process for the full deadline wall did not reproduce (a failing test fails fast at 0.09s under a 5s and a 60s deadline).

## Decision

Keep-current (branch A) is the adopted test-runner approach. The `xargs -P8` parallel dispatch and the pure-bash per-file deadline merge onto the main line; the bats-core migration is rejected and branch B is archived as the comparison record.

The branch-A protocol record pre-registered the accept condition: the merging agent accepts bats only if branch B closes a bug class that branch A does not, at a cost the project accepts. Measured, branch B closes no bug class branch A lacks, while costing three runtime dependencies, a slower suite on serial and parallel wall, and a larger maintenance surface (the dual-mode test library and the TAP-reparse launcher). The decision is recorded as an ADR: [`docs/adr/test_harness.md`](../../docs/adr/test_harness.md).

## Consequences

- The roadmap rows **Test suite duration** and **Individual per-test timeout** close; the harness-decision text replaces the deferred-comparison tail of the **Test-harness improvement (unified plan)** row.
- Branch A is merged; branch B stays archived as the comparison record, not merged.
- The three harness-evaluation robustness rows landed (iterations `20260922-10` to `20260922-12`); M3.1 now holds the open test-suite read-through task, and the fold-back into M3 follows its close.
- The branch-B report's measurement claims stand corrected by this record (units, self-test count, failing-test wall cost).
