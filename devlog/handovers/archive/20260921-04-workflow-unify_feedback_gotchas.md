# Handover - Unify AGENT_FEEDBACK and GOTCHAS into One Record

**Type:** Workflow
**Milestone:** M3 - Autonomous Task Execution, Manual Review Workflow
**Date:** 2026-09-21
**Status:** Closed
**Iteration:** 20260921-04
**Branch:** feat/M_3-orchestration

## Problem statement

Roadmap T1 row (queued this iteration): unify `devlog/AGENT_FEEDBACK.md` and `devlog/GOTCHAS.md` into a single record. The two files share format, handling, and the same writer (the agent); the agent-autonomous vs operator-owned distinction is expressible as an entry-level source tag rather than a file boundary. Then rewrite the `harness_iterative_improvement_loop` ADR with a log entry.

## Current state (evidence)

- **`AGENT_FEEDBACK.md`**: 18 entries, all tagged `[A]`, under section headers (Consolidated M3 cleanup, Bash, Agent experience sessions).
- **`GOTCHAS.md`**: 3 entries, tagged `[G]` (x2) and `[H]` (x1), under an `## Open gotchas` section.
- Both files share the identical `## Entry format` template (state/scoped/legacy/mitigation), the same point-in-time lifecycle, the same pre-close review gate, and the same writer.
- The `harness_iterative_improvement_loop` ADR currently records the two-file design (2026-08-09 primer) and the cataloguing model (2026-09-21).

## Set up by prior iteration

- Reader model already reworded to cataloguing/frequency (both files no longer the agent's behavior source).
- The `[CORRECTION]` on `20260809-04` row 22 already applied.
- Feedback entries for resolved T1 rows already flipped to `probation`.

## Confirmed design (operator)

1. Keep `AGENT_FEEDBACK.md`; drop `GOTCHAS.md`. Propagate the GOTCHAS filename everywhere; confirm the migration is complete. No retitle.
2. Tag semantics: `[A]` = raised by the agent, `[O]` = raised by the operator. Drop `[G]` and `[H]`.
3. Merge into a single list; keep the descriptive section labels for the consolidated groups created at the start of M3.
4. Update the ADR.

## Propagation checklist

| # | File | Change | Status |
|---|---|---|---|
| 1 | `devlog/AGENT_FEEDBACK.md` | absorbed 3 GOTCHAS entries under `## Gotchas -- operator-raised entries`; retagged `[G]`/`[H]` to `[O]`; canonicalized the format to the A/O tag scheme | done |
| 2 | `devlog/GOTCHAS.md` | deleted | done |
| 3 | `AGENTS.md` | collapsed the two-record directive to one; renamed the section header | done |
| 4 | `docs/operations/iteration_policy.md` | updated pre-close gate and findings review/publish routing to the single file and `[A]`/`[O]` tags | done |
| 5 | `docs/operations/handover_policy.md` | updated the Findings routing to the single file | done |
| 6 | `docs/concepts/agent_workflow.md` | updated the persistent-records section and routing table | done |
| 7 | `docs/adr/harness_iterative_improvement_loop.md` | appended a new current entry (2026-09-25 unified record) demoting the cataloguing entry | done |
| 8 | `workflow/coding-agent/prompts/gm.md`, `bootstrap.md` | updated references | done |
| 9 | `docs/development/bash-coding-conventions.md`, `conventions.md` | updated cross-references | done |
| 10 | `devlog/discussions/20260809-design-settled-...` | added a superseded note | done |
| 11 | `devlog/handovers/20260809-04` | added a `[CORRECTION -- 2026-09-21]` note for the unification | done |
| 12 | `devlog/roadmap.md` | marked the unify row done | done |

## Completed

- Unified record merged; GOTCHAS deleted; tag scheme canonicalized to `[<A|O>]`; ADR updated with a new current log entry.

## Acceptance criteria

- [x] GOTCHAS entries folded into AGENT_FEEDBACK
- [x] GOTCHAS file deleted; zero live pointers remain (remaining `GOTCHAS` hits are historical/descriptive)
- [x] Tags canonicalized to `[A]`/`[O]`; `[G]`/`[H]` dropped
- [x] M3 consolidated section labels preserved
- [x] ADR updated with a new current log entry
- [x] Lint gate clean

## Deferred items

| Item | Reason | Destination |
|---|---|---|
| _none_ |  |  |

## What's Next

Iteration closed pending operator review.
