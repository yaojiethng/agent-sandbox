# Agent Handover

**Date:** 2026-09-21
**Milestone:** M3.1 - Backpressure
**Type:** Impl
**Status:** Closed

## Objective

The lint-gate duration task of the lint/tests duration split. The operator chose the study's "parallel per-file" approach for the ShellCheck gate, directed a patch of the 8 sites the strict mode exposed (characterised as leaks from gaps in the previous invocation method), authorized the three lint gates to run in parallel, and instructed the roadmap row to be split into two refined tasks rather than the "takes forever" phrasing.

## Scope

- `scripts/check_shell.sh`: one shellcheck run per file, in parallel, instead of one batch invocation that treated the first file as "the script" and suppressed script-context warnings on the rest.
- `scripts/lint.sh`: run the shell, lib-contract, and markdown gates concurrently; aggregate verdicts; print each gate's output on completion.
- Patch the 8 sites strict per-file exposed: `scripts/start_agent.sh`, `scripts/workflows/reject.sh`, `tests/test_confirm_workflow.sh`, `tests/test_dispatch.sh`, `tests/test_draft_workflow.sh`, `tests/test_interactive_session_select.sh`, `tests/test_reject_workflow.sh`, `tests/test_trace_compose_gen.sh`.
- `devlog/roadmap.md`: split the old row into **Lint gate duration** (closed) and **Test suite duration** (open) with refined wording.
- `devlog/discussions/20260921-study-...md`: record that the lint recommendation landed and the per-approach dispositions.

**Deferred:** the **Test suite duration** row (wait-dominated suite; the operator scoped this iteration to lint only). The `[A]` doc-format and other feedback dispositions remain at the M3.1 pre-close review.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | The shell gate runs per-file in parallel and reports zero warnings | `bash scripts/check_shell.sh` | Agent |
| 2 | The shell gate is materially faster than the ~30s batch | `time bash scripts/check_shell.sh` | Agent |
| 3 | The three gates run in parallel with a correct aggregate verdict | `bash scripts/lint.sh` | Agent |
| 4 | The 8 exposed sites are strict-clean, patched not blanket-suppressed | `shellcheck -S warning` each file | Agent |
| 5 | The umbrella lint behavioural tests still pass | `bash tests/test_lint_umbrella.sh` | Agent |
| 6 | Full suite green with no dormant suppressions | `bash scripts/run_tests.sh` | Agent |
| 7 | Roadmap and study record the split and the resolution | read the files | Agent |

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/check_shell.sh`](scripts/check_shell.sh) | per-file parallel invocation + merged verdict |
| [`scripts/lint.sh`](scripts/lint.sh) | concurrent gates |
| scripts/start_agent.sh, scripts/workflows/reject.sh | strict-mode patches (directive: cross-source / eval) |
| tests/test_confirm_workflow.sh, test_dispatch.sh, test_draft_workflow.sh, test_interactive_session_select.sh, test_reject_workflow.sh, test_trace_compose_gen.sh | strict-mode patches (export preset / remove dead / directive) |
| [`devlog/roadmap.md`](devlog/roadmap.md) | row split into lint (closed) and suite (open) |
| devlog/discussions/20260921-study-settled-lint_and_tests_duration.md | resolution recorded |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Per-file parallel shellcheck | the operator's chosen approach; strict (no library mask) AND ~30s -> ~1.5s | this handover; study Open Question 1 |
| Patch, never re-suppress, the 8 exposed sites | the strict gate is the point; each leaked site was a gap the batch masked | this handover; study Open Question 2 |
| Export `AGENT_SANDBOX_REPO` in the five tests | the documented preset-and-sourcing contract; matches two sibling tests | the five test files |
| Targeted rationale directive where a `source`/`eval`-introduced read is untraceable | sanctioned suppression policy (only for genuine false-positive classes) | each directive's site |
| Remove the dead `PROJECT_DIR` in `make_real_session` | genuinely unused assignment | tests/test_draft_workflow.sh |
| The three gates run concurrently, output printed on completion | operator authorization; deterministic report under concurrency | scripts/lint.sh |
| Keep verdict-only exit codes; aggregate the worst per-file rc | bash-coding-conventions 3.2 | scripts/check_shell.sh |

## Findings

| Finding | Type | Impact |
|---|---|---|
| A leftover `SC_RC=0` from the old aggregation tripped the new gate's own SC2034 scan | verification | the gate caught its own regression on first run; removed, then clean |
| All 8 "leaks" are genuinely masked gaps, not new bugs being introduced | verification | the batch invocation's library-mode suppression hid real static findings that per-file now reports |
| The suite is wait-dominated, so this iteration (lint only) leaves the **Test suite duration** row open | scope | the tests approach selection is the deferred follow-up |

## Completed

| File | Change | Status |
|---|---|---|
| `devlog/handovers/20260921-12-impl-m3_1_lint_gate_duration.md` | opened this handover | done |
| `scripts/check_shell.sh` | per-file parallel shellcheck; deterministic merged verdict | done |
| `scripts/lint.sh` | concurrent gates; aggregate verdict | done |
| `scripts/start_agent.sh` | SC2034 directive with rationale for `ENV_REL` | done |
| `scripts/workflows/reject.sh` | SC2154 directive with rationale for eval-emitted `source_branch` | done |
| 4 tests | `export AGENT_SANDBOX_REPO` (confirm, dispatch, reject_workflow, interactive, draft) | done |
| `tests/test_interactive_session_select.sh` | SC2034 directive for `PROJECT_DIR` | done |
| `tests/test_draft_workflow.sh` | removed dead `PROJECT_DIR`; exported `AGENT_SANDBOX_REPO` | done |
| `tests/test_trace_compose_gen.sh` | SC2034 directive for `COMPOSE_ARGS` | done |
| `devlog/roadmap.md` | row split: Lint gate duration `[x]`, Test suite duration `[ ]` | done |
| devlog/discussions/20260921-study-settled-lint_and_tests_duration.md | resolutions recorded | done |

## Deferred items

- **Test suite duration** row: the suite is wait-dominated; its approach selection is a separate iteration by operator choice.
- M3.1 close ceremony (fold-back, the two write-back discrepancies, feedback-entry dispositions).

## What's Next

M3.1 - Backpressure. Roadmap maintenance: none pending.

Remaining M3.1 rows: **Test suite duration** (open; approach selection by the operator) and the M3.1 close. After the suite-duration row, M3.1 closes and folds back into M3.

Feedback-entry dispositions at the M3.1 pre-close review (pending): `[O]` library return-not-exit (durable fix `20260921-08`), `[A]` shellcheck-directive (durable fix `20260921-07`), `[A]` doc-format (durable fix live since `20260921-11`), `[A]` record-write-back and `[A]` mechanical-edit families (unchanged).
