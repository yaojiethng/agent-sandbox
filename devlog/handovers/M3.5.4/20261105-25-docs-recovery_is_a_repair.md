---
date: 2026-11-05
milestone: M3.5.4 - The git and change model
type: Documentation
status: Closed
---

# Handover - Recovery is a repair at the claimed state

## Objective

Reframe recovery as a repair selected by a record-versus-repository disagreement at a claimed progress state, and remove mergeability and the normal uncommitted path from it.

## Scope

`.agents/skills/git-discipline/references/recovery.md`, `docs/reference/workflow_statechart.md` (the chart's recovery region, the command tables, the stories, the checks), the `git-discipline` runbook row, and the M3.5.4 roadmap row.

Out of scope, with reasons: the discussion-record machine and the records region, which already hold their own states; a mechanical gate for "one property per machine", which the tree does not have.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Four classes: partial, bad, messy, absent | `recovery.md`'s table | Agent [x] |
| No merge or rebase class | `grep` over `recovery.md` | Agent [x] |
| No `rec_triage`, `rec_merge` or `rec_rebase` in the chart | `bash scripts/check_statechart.sh` | Agent [x] |
| The repairs attach to `it_implementing` and `it_committed` | the chart's recovery region | Agent [x] |
| Every prompt is covered by one of the two command tables | the `Command coverage` query | Agent [x] |
| The stories resolve | `bash scripts/check_statechart.sh` and a hand read | Agent [x] |
| The gates are clean | `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Recovery is a repair, not a phase | the workflows are keyed by the claimed state; a unit cannot be `implementing` and `corrupt` at once | `recovery.md`; this record |
| The surviving property is a predicate: the record's claim against the repository's evidence | that comparison is the only thing the four classes share, and it selects the repair, not a state | `recovery.md` |
| A child branch that will not rebase onto its parent is mergeability | the same three-state machine on another edge; `prepare-rebase` owns it | `recovery.md` |
| `Uncommitted` leaves recovery | the normal `implementing -> committed` transition, not a loss | `recovery.md` |
| `rec_*` is reserved for records; repairs use `rep_*` | the chart already used `rec_handover_*`, `rec_roadmap_*`, `rec_disc_*` | the chart |
| The change-flow commands get their own table | a separate machine, so a separate table; coverage reads both | `workflow_statechart.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The six recovery classes mixed the normal path, mergeability and loss | defect | a reader could not tell a unit that was merely uncommitted from one whose work was gone | fixed: four classes, all disagreements |
| `rec_triage` was a choice drawn as a state | defect | the chart implied recovery was a phase a unit enters | fixed: four repair states on the two claiming states |
| `rec_merge` and `rec_rebase` were mergeability under a recovery name | defect | the prepare/accept path looked like loss recovery | fixed: removed; the change flow owns it |

## Completed

| File | Change |
|---|---|
| `.agents/skills/git-discipline/references/recovery.md` | four disagreement classes; mergeability and uncommitted leave |
| `docs/reference/workflow_statechart.md` | `rep_*` repairs, the change-flow table, the stories and the checks |
| `.agents/skills/git-discipline/SKILL.md` | the recovery row's trigger |
| `devlog/roadmap.md` | the row closes |
| `devlog/handovers/M3.5.4/20261105-25-docs-recovery_is_a_repair.md` | this record |
