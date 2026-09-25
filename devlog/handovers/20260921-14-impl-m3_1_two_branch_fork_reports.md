# Agent Handover

**Date:** 2026-09-21
**Milestone:** M3.1 - Backpressure
**Type:** Impl
**Status:** Closed

## Objective

Create both comparison branches for the M3.1 harness-migration decision, each forked from the study close: branch A implements the dependency-free `xargs -P8` parallel plus the pure-bash deadline; branch B implements the bats-core migration. Each branch produces an output report. This handover records both branches, their output reports, and the comparison between the branch points. Both branches are persisted; nothing is merged.

## Scope

- Branch A (`feat/M_3_1-backpressure-branch-A`): `scripts/run_tests.sh` parallel dispatch plus the pure-bash deadline; the runner self-test extended. Report: `devlog/discussions/20260921-design-settled-m3_1_test_runner_merge_comparison_branch_a.md`.
- Branch B (`feat/M_3_1-backpressure-branch-B`): bats-core conversion of the 58-file suite, launcher, liveness removal, docs, runtime dependencies. Report: `devlog/discussions/20260921-study-superseded-m3_1_bats_harness_merge_branch_b.md`.
- The comparison between the branch points: the counting-model and isolation asymmetries recorded in the study `devlog/discussions/20260921-study-settled-lint_and_tests_duration.md`.

## Completed

| File | Change |
|---|---|
| `scripts/run_tests.sh` (branch A) | Serial loop to `xargs -P8` parallel; pure-bash deadline via a worker entry branch |
| `tests/test_runner_selftest.sh` (branch A) | Extended for the parallel and deadline contract; 32/32 |
| `tests/test_*.sh` x58 (branch B) | Converted to bats-core `@test` blocks; `set +e; set +T` heads kept |
| `tests/libs/test_common.sh` (branch B) | bats-native helpers; removed the counter, `run_test`, and `test_done` machinery |
| `scripts/run_tests.sh` (branch B) | bats-core launcher; prerequisite checks; TAP aggregation; zero-skip |
| `scripts/check_test_liveness.sh` (branch B) | Removed; bats parses `@test` blocks statically |
| `docs/development/*` (branch B) | Updated for the bats harness and runtime dependencies |

## Findings

| Finding | Impact |
|---|---|
| Branch A: a 1s poll floor costs every run a second; a 0.1s poll (portable fractional `sleep`) removes it | current iteration |
| Branch B: bats runs under `-e` and `-T`; each `@test` body starts `set +e; set +T` to keep the suite's leniency and to stop `RETURN` traps deleting staged compose files | current iteration |
| Branch B: the entrypoint tests needed `exec` inside the background subshell plus a settle grace | current iteration |
| Branch B: the registration liveness gate is obsolete under bats | current iteration |
| Comparison: an identical 696-test-function set on both branches; the 1046-vs-701 gap is the counting convention (PASS markers vs test units) | current iteration |
| Isolation differs in kind: branch B runs each `@test` in an isolated subshell; branch A runs tests in-process | next iteration |
| Branch B's native timeout needs `ps` or `pkill`, which the runtime image lacks | next iteration |

## Verification

- Branch A: 1046 PASS markers across 58 files in ~9s wall (was ~37s serial); self-test 32/32; lint Clean.
- Branch B: 701 test units across 58 files, 0 failed, 0 skipped, ~15-17s; lint Clean.
- Both output reports lint Clean.

## What's Next

The operator compares branch A and branch B for the authoritative merge decision. Both branches are persisted; nothing is merged. This unit leads to the unified test-harness improvement plan (iteration `20260922-01`).
