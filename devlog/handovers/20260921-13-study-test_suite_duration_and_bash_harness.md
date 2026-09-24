# Agent Handover

**Date:** 2026-09-21
**Milestone:** M3.1 - Backpressure
**Type:** Study
**Status:** Closed

## Objective

Close the "Test suite duration" investigation and perform the "Official bash unit-test harness evaluation" for M3.1 (an M3 item in another track, moved here). The operator directed an updated study with the lint resolution status and a test-duration analysis (parallel, per-test timeout, busy-waiting) plus an empirical per-option comparison of bats-core / shunit2 / shellspec. The operator then decided the roadmap ownership and the approach: M3.1 subsumes the harness-migration and per-test-timeout tasks; two parallel branches (keep-current vs bats-core) are built before an authoritative merge decision.

## Scope

- `devlog/discussions/20260921-study-active-lint_and_tests_duration.md`: lint resolution status; fresh suite measurement; per-option framework comparison; open questions.
- `devlog/roadmap.md`: move the harness-migration and per-test-timeout tasks into M3.1; record the operator's decisions and the two-branch plan.
- `tests/test_doc_wrap_rule.sh` + `docs/development/testing-conventions.md`: correct a bad testing direction the study exposed (whole-project lint as a unit assertion); audit for other instances.

## Findings

| Finding | Weight | Evidence |
|---|---|---|
| The suite is latency + child-CPU bound, not busy-wait bound; the earlier "user 8s, wait-dominated" claim is stale | high | serial ~40s wall, user ~32s / sys ~14s; `xargs -P8` ~7.8s, all 58 files green |
| The costliest test was a whole-project lint, not a wait | medium | `test_doc_wrap_rule.sh` 4.7s: a real-tree `markdownlint-cli2` over 596 `.md` files |
| The bespoke harness has produced four testing-harness bugs | high | FD-offset silent coverage loss; dead `run_test` after `test_done`; grep-based PASS counting; no per-test timeout |
| bats-core is the only candidate solving the per-test-timeout axis natively | high | `BATS_TEST_TIMEOUT` env + watchdog + `# timeout after Ns` tap annotation, verified in source |
| shellspec and shunit2 fail the timeout and/or parallel axes | high | shellspec internal `timeout()` is a retry helper; shunit2 v2.1.8 stale (release 2020-03), serial only |
| The git-test umbrella cases are gate-behaviour tests against stubbed tools | medium | all gate invocations override PATH to stubs; no project-file-identity assertion remains except lib_contract's cheap conformance smoke |

## Decisions (operator, 2026-09-21)

| Decision | Resolution |
|---|---|
| Run the test files in parallel | yes - adopt on a branch |
| Add a per-test deadline | yes - default ~5s; exact mechanism depends on the comparison |
| Framework choice | not yet - build two parallel branches first (keep-current `xargs -P8` + pure-bash deadline; bats-core) and compare the results for the authoritative merge decision |
| M3.1 subsumes the harness-migration and per-test-timeout tasks | yes - both moved into the M3.1 section |
| `test_doc_wrap_rule.sh` whole-tree scan | bad testing direction - removed; conventions updated; audit run |

## Completed

| File | Change | Status |
|---|---|---|
| `devlog/discussions/20260921-study-active-lint_and_tests_duration.md` | lint status; suite measurement; per-option comparison; open questions | done |
| `devlog/roadmap.md` | moved harness-migration + per-test-timeout into M3.1; recorded decisions and two-branch plan | done |
| `tests/test_doc_wrap_rule.sh` | removed the whole-tree `test_real_tree_zero_findings`; fixture tests remain; ~4.7s to ~1s | done |
| `docs/development/testing-conventions.md` | added Anti-Pattern 8 (whole-project scan as a unit assertion) | done |
| `devlog/handovers/20260921-13-study-test_suite_duration_and_bash_harness.md` | record + close this handover | done |

## Audit result (other such tests)

- `test_lib_contract.sh` real-tree guard: kept. It is a cheap (~0.1s) conformance smoke scanning `src/libs` + `src/build`, the exact corpus the return-not-exit rule governs; acceptable under Anti-Pattern 8's principle.
- `test_lint_umbrella.sh`: kept. Every gate invocation overrides PATH with stub tools; it tests gate behaviour (rc, messages, discovery), not project-file identity.
- No other test scans the whole project tree as an assertion.

## Verification

- `test_doc_wrap_rule.sh` 12/12 passed (~1s, down from 4.7s).
- Full suite 1042/1042 across 58 files (0 failed, 0 skipped) in ~37s.
- `scripts/lint.sh` Clean (3 gates, 3s); `bash -n` clean on the amended test.

## What's Next

M3.1 - Backpressure. Roadmap maintenance: none pending.

Next iteration starts the two-branch plan: branch A patches `run_tests.sh` with the dependency-free `xargs -P8` parallel and a pure-bash ~5s deadline (and moves the runner self-test to the parallel contract); branch B implements a bats-core migration (test-tree conversion, docker-stub and zero-skip/verdict-exit wiring, dependency pinned in image + Dockerfile + macOS bootstrap). The operator compares the branches for the authoritative merge decision on the harness-migration and per-test-timeout rows, then M3.1 closes and folds back into M3.
