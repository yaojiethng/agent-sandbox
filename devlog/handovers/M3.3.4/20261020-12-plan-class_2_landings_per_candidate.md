---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Plan
status: Closed
---

# Handover - one landing per candidate

## Objective

Correct the class-2 schedule so each accepted candidate lands in its own iteration, carrying its own propagation edits.

## Scope

Two records: the roadmap row **The class-2 candidate review**, retimed, and the correction tag on the decision it supersedes. No candidate is read and no skill lands here.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The row no longer schedules one combined landing | read the row: a landing is one iteration per accepted candidate | Agent [x] |
| The row states what a landing must carry | read the row: regenerate the ledger, regroup the touched rows, rerun the gates, one handover, one commit | Agent [x] |
| The row states how the tranche rows are written | read the row: at this row's close, one per accepted candidate, none for a rejected one | Agent [x] |
| The superseded decision carries a correction tag rather than a rewrite | `grep CORRECTION devlog/handovers/20261020-11-plan-class_2_candidate_review.md` | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| One grill session for all ten dispositions, then one iteration per accepted candidate | the alignment is one question asked across ten candidates, while each landing is a distinct source edit with its own propagation, gates and commit | the roadmap row |
| A landing iteration owns its propagation: regenerate, regroup, rerun | a pointer edit changes a source line's hash, so both ledger rows orphan and both gates fail until the row is regrouped; that work belongs to the landing, not to a later pass | the roadmap row, and `20261020-11`'s finding |
| The row writes no placeholder rows for candidates the grill rejects | the roadmap carries a task only where the work is defined, and a rejection is not work | the roadmap row |
| The superseded decision takes a correction tag, not a rewrite | `20261020-11` is closed, and a closed record's decision is corrected by annotation | `20261020-11`'s Decisions row |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The propagation cost is the reason to split, and it is uniform | consequence | ten accepted candidates means ten ledger regenerations and ten regroups, so batching would have made the filing's final pass ambiguous about which edit orphaned which row | the roadmap row |
| A rejection needs no row and no propagation | result | the row's tranche is smaller than the candidate list by however many the grill rejects | the roadmap row |

## Completed

| File | Change |
|---|---|
| `devlog/roadmap.md` | the class-2 row retimed: one grill session, one landing iteration per accepted candidate, its propagation named, its tranche rows written at close |
| `devlog/handovers/20261020-11-plan-class_2_candidate_review.md` | correction tag on the combined-landing decision |
| `devlog/handovers/20261020-12-plan-class_2_landings_per_candidate.md` | this record |
