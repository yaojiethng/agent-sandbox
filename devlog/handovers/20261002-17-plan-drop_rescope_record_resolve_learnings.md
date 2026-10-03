# Handover - Drop the rescope record and resolve its learnings

**Date:** 2026-10-02
**Milestone:** M3.2.1 - Iteration loops and workflow
**Type:** Plan
**Status:** Closed

## Objective

Plan the resolution of the four workflow findings the rescope investigation carried: drop the investigation record from the branch, and route each learning to the record that owns it.

## Problem

The analysis document `devlog/discussions/20261002-analysis-rescope_and_handover_numbering.md` recorded a takeover investigation of a worktree state that exists only on the remote side, not on host. The operator judged persisting it worthless. Its findings section held four learnings that caused counted violations (`merge:` prefixes, a scope field, roadmap bookkeeping typed `chore:`, handoverless units) and needed durable resolution.

## Decisions

Settled through the grill-me interview with the operator; the two implementation units that execute this plan carry their own handovers (`20261002-18`, `20261002-19`).

1. The dropped record is an acceptable loss in full, including the handover-renumbering mapping explanation. The renumbered filenames and the gap-free sequence are self-evidencing.
2. The `/plan` deliverable rule and the fan-out merge-back contract fold into the rows that own those surfaces: the `/plan` per-prompt quality pass row and the `/task-queue` dispatch-procedure row (M3.2.3).
3. The commit-discipline check is split by close shape: a self-check step in `/wrapup` (M3.2.1) for acceptance-gate closes, and a reviewer-subagent counterparty (M3.2.2) for gateless closes. The reviewer counterparty is deferred to M3.2.2, whose roadmap row already lives there; the reviewer milestone is the counterpart `/iter` needs to `/wrapup`'s close.
4. The unit-rule independence test is superseded before implementation: the file-edit criterion is the wrong axis (commits legitimately share files), and the workshape question is M4 scope. The tentative workshape definition is persisted in `roadmap_future.md` under M4.7; M3 carries the scope rule instead -- the confirmed scope lands as one unit in one commit, checked by the self-check and the reviewer.
5. The `maintenance` prompt's provenance (agent-authored, agent-only review, immediately load-bearing) drives the draft-gate unit: prompts join the persisted set through a drafts directory and switch over only on explicit operator direction.
6. The task-queue run itself yields two findings: `taskq_list` and `taskq_cancel` are missing tools, recorded as a subtask under the dispatch-procedure row; and the worker-dispatch shape is dropped for small policy tasks after worker orientation duplicated reads the primary already held -- the grill-me skill's questioning discipline findings route to `devlog/AGENT_FEEDBACK.md`.

## Changes

| File | Change |
|---|---|
| `devlog/roadmap.md` | the four learnings routed: two folds, the reviewer row (M3.2.2), the draft-gate row (T1), the taskq subtask row (M3.2.3) |
| `devlog/roadmap_future.md` | the tentative workshape definition persisted under M4.7 |
| this handover | the plan record |
| dropped | the rescope analysis document and its commit (the record the operator directed off the branch) |

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | The analysis document is off the branch | no rescope path in the tree | pass |
| 2 | All four learnings survive in roadmap records | the rows listed in Changes | pass |
| 3 | The plan's implementation units carry their own handovers | `20261002-18` and `20261002-19` | pass |
