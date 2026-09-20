# Agent Handover

**Date:** 2026-08-23
**Milestone:** M2.6  --  Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Implement the roadmap task "Test-harness hardening recommendations (campaigns 2026-08-21)": assertion-helper trio, runner self-test, shellcheck report, rot-detection smoke target for excluded tests, lib-liveness check, and the dead-flag convention rule.

## Scope

`tests/libs/test_common.sh`, one new self-test suite, three check scripts wired through the Makefile, a one-line `RUN_TESTS_DIR` override in `scripts/run_tests.sh`, and one new rule in `docs/development/bash-coding-conventions.md`. Production library code untouched.

## Carried forward

| Item | From handover |
|---|---|
| Smoke-target recommendation validated by the excluded-tests audit | `20260823-06` |

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | `assert_eq`/`assert_ne`/`assert_rc`/`assert_contains` available in `test_common.sh`; each calls pass/fail so helper-only test bodies cannot be assertion-less | In file; exercised by the self-test suite | accepted |
| AC2 | Runner counting contract locked by a self-test: pass, fail, marker-less crash, skip-as-failure, aggregate line | `tests/test_runner_selftest.sh`: 8/8 green | accepted |
| AC3 | Excluded tests have non-gating syntax-rot detection | `scripts/check_test_smoke.sh`: 5 scripts checked, 0 failures | accepted |
| AC4 | Lib orphaning is loud: every `src/libs/*.sh` needs a non-test reference | `scripts/check_lib_liveness.sh`: 12 libs, 0 orphaned; negative-tested with a planted orphan (rc=1 + listed) | accepted |
| AC5 | ShellCheck report exists and records its baseline | `scripts/check_lint.sh`: 31 warnings across 89 files; flip-to-blocking criterion documented in script header | accepted |
| AC6 | Dead-flag rule in conventions; AGENT_FEEDBACK rot entry mitigated | `bash-coding-conventions.md` rule 3.3; feedback entry state updated | accepted |
| AC7 | Suite green and deterministic | 628 tests / 38 files / 0 failed x2 runs | accepted |

## Decisions

| Decision | Rationale |
|---|---|
| ShellCheck ships **non-gating**, baseline 31 warnings recorded in the script header | A blocking gate would fail on day one (37->31 warnings measured across src/scripts/tests/test). Flip criterion documented: enforce at zero. Fixing the 31 is production-file churn deserving its own iteration |
| Runner gains `RUN_TESTS_DIR` env override rather than the self-test sed-copying the runner | One backward-compatible line beats a brittle copy of the code under test  --  the self-test must exercise the real runner |
| Gates runnable via direct bash invocation, Makefile targets as convenience | This container has no `make`; targets verified by executing the scripts directly |
| Liveness counts any non-test reference under src/, scripts/, test/, Makefile | Deliberately loose  --  the buildkit_progress failure mode was zero references anywhere; strictness about *how* a lib is referenced can come later if false positives appear |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The container has no `make`, `python3`, `jq`, or `bats`; only shellcheck | environment | All gates must stay plain-bash-runnable; recorded here since prior campaign notes listed the others but not make |

## Completed

| File | Change |
|---|---|
| [`tests/libs/test_common.sh`](../../tests/libs/test_common.sh) | Assertion trio (`assert_eq`/`assert_ne`/`assert_rc`/`assert_contains`) |
| [`tests/test_runner_selftest.sh`](../../tests/test_runner_selftest.sh) | New  --  locks runner counting contract incl. crash and skip classes |
| [`scripts/check_test_smoke.sh`](../../scripts/check_test_smoke.sh) | New  --  `bash -n` over excluded test dirs |
| [`scripts/check_lib_liveness.sh`](../../scripts/check_lib_liveness.sh) | New  --  orphaned-lib detection, negative-tested |
| [`scripts/check_lint.sh`](../../scripts/check_lint.sh) | New  --  ShellCheck report with documented flip criterion |
| [`scripts/run_tests.sh`](../../scripts/run_tests.sh) | `RUN_TESTS_DIR` override for the self-test |
| [`Makefile`](../../Makefile) | `lint`, `test-smoke`, `lib-liveness` targets |
| [`docs/development/bash-coding-conventions.md`](../../docs/development/bash-coding-conventions.md) | rule 3.3 no-speculative-flags rule |
| [`devlog/AGENT_FEEDBACK.md`](../../devlog/AGENT_FEEDBACK.md) | Knowledge-rot entry -> mitigated (smoke target exists) |

Roadmap task marked complete at close.

## Deferred items

| Item | Reason | Goes next |
|---|---|---|
| Fix the 31 ShellCheck findings, then flip `check_lint.sh` to blocking | Production-file churn, own iteration | Operator scheduling |
| Migrate older suites to the assert helpers mechanically | Churn without behaviour change; helpers are available for all new tests | Opportunistic, per-touch |

## What"s Next

M2.6 continues per roadmap.
