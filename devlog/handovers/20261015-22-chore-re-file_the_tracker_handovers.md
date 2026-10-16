---
date: 2026-10-15
milestone: M3.2.3 - Dispatch Workflows as a Command Surface
type: Housekeeping
status: Closed
---

# Handover - Re-file the tracker handovers under M3.2.3

## Objective

File the two reorientation fixes where the task-tracker mechanism lives, M3.2.3, instead of under M3.6.1, and record them on the M3.2.3 row.

## Scope

Two handover frontmatter fields and one roadmap row.

Out of scope: the read-back prompt, which is a separate mechanism.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Both handovers name M3.2.3 | `grep -m1 '^milestone:'` on `20261015-20` and `20261015-21` | Accepted |
| The M3.2.3 row names both | the task-tracker row carries handovers `20261015-20` and `20261015-21` | Accepted |
| Gates clean | `bash scripts/lint.sh` clean across 8 gates | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A new correction commit rather than a history rewrite | the handovers are already committed; a correction commit preserves the history and reaches the same record state | this record |
| `/read-back` stays out | it is a general prompt, not the push and pop mechanism, and the operator named the push and pop handovers | this record |

## Decisions pending

Whether `/read-back` belongs under M3.2.3 too. It is a general prompt with no tracker tie, so the answer is probably no.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The two fixes were filed under M3.6.1 while the mechanism they fix lives under M3.2.3, so a reader of M3.2.3 would not see the state of its own prompts. | filing defect, fixed | the roadmap row |
| The tracker is session-local, so a filing correction like this one is exactly the cross-task steering that has no home today. | design gap, raised | the steering proposal |

## Completed

| File | Change |
|---|---|
| [`20261015-20-workflow-restore_the_pointer_only.md`](20261015-20-workflow-restore_the_pointer_only.md) | milestone re-filed to M3.2.3 |
| [`20261015-21-workflow-prune_the_resolved_nodes.md`](20261015-21-workflow-prune_the_resolved_nodes.md) | milestone re-filed to M3.2.3 |
| [`devlog/roadmap.md`](../roadmap.md) | the M3.2.3 task-tracker row names both fixes |
