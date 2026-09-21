# Agent Handover

**Date:** 2026-09-21
**Milestone:** M3 -- Autonomous Task Execution, Manual Review Workflow (major-loop planning)
**Type:** Plan -- open sub-milestone M3.1 (Backpressure), aggregate the lint / linting-rule / pre-commit-hook work under it, move run-budget under Perf
**Status:** Closed

## Objective

Start the M3 major loop by opening sub-milestone M3.1, titled Backpressure, as the first active sub-milestone. Aggregate all lint, linting-rule, and pre-commit-hook work under it, including a new task for the slow lint/test run. Move `Tool timeout / run budget` out of the backpressure track into the Perf workstream.

## Scope

Planning output only. Restructure the roadmap so the backpressure work becomes a dedicated M3.1 sub-milestone with a task list; rehome the Perf run-budget row; add the slow-lint/test task. No implementation, no code, no document rewrites beyond the roadmap task-list reorganization and this handover's planning records.

## Carried forward

None.

## Open questions

_None -- operator directives captured._

## Acceptance criteria

- [x] M3.1 sub-milestone (Backpressure) created in the roadmap with a task list
- [x] Every lint / linting-rule / pre-commit-hook entry moved under M3.1
- [x] New task added under M3.1 for the slow lint/test run, raising issues with the existing backpressure mechanisms
- [x] `Tool timeout / run budget` moved out of the backpressure track into the Perf workstream (T2)
- [x] Lint gate clean

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/roadmap.md`](devlog/roadmap.md) | M3.1 sub-milestone and the lint/hook aggregation |
| [`devlog/AGENT_FEEDBACK.md`](devlog/AGENT_FEEDBACK.md) | `scoped:` destinations rehomed from T3 to M3.1 / T2 |

## Decisions

| Decision | Rationale |
|---|---|
| M3.1 Backpressure nests as `#### M3.1 - Backpressure` under the `### M3` header, with its own sub-list, and appears in the Milestone Summary table indented under M3 | operator: nested `#### M3.1` per confirmed scope |
| `Lint and tests take forever` is a backpressure-gate-cost task under M3.1, distinct from the run-budget concern | operator: the slow backpressure gate is a backpressure issue |
| `Tool timeout / run budget` moves to T2 Perf (from the former T3 Backpressure track) | operator: run budget is a Perf concern, not backpressure |

## Findings

| Finding | Type | Impact |
|---|---|---|
| _none_ |  |  |

## Completed

| File | Change |
|---|---|
| `devlog/roadmap.md` | renamed T3 to nested `#### M3.1 - Backpressure`; moved `Tool timeout / run budget` into T2 Perf; added the `Lint and tests take forever` M3.1 task; added M3.1 row to the Milestone Summary table; corrected the stale `[!H]` tag to `[O]` in the sourced-lib row |
| `devlog/AGENT_FEEDBACK.md` | rehomed four `scoped:` references from M3 T3 to M3.1 (three) and M3 T2 (run-budget) |
| `devlog/handovers/20260921-05-plan-m3_1_backpressure.md` | opened and closed this planning handover |

## Deferred items

| Item | Reason | Destination |
|---|---|---|
| _none_ |  |  |

## What's Next

M3.1 (Backpressure) is the active sub-milestone, scoped and ready. Pick the first M3.1 task to iterate. Recommended easy start: `Doc-format lint rules` (offline lint gate, resolves the `Doc-format discipline via lint` probation feedback entry). Roadmap maintenance is not pending; the M3.1 row and summary table are current.
