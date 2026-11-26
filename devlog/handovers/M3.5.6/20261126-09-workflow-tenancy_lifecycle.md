---
date: 2026-11-26
milestone: M3.5.6 - The discussion record corpus
type: Workflow
status: Closed
---

# Handover - The lifecycle rule replaces the placement test

## Objective

Drop the placement test and state the stronger rule it was standing in for: a record is introduced by a row and deleted when that row ends, so nothing has to judge whether a record still deserves to exist.

## Scope

A ninth row on `M3.5.6`: the placement section removed from `work-log`, the deletion paragraph replaced with the lifecycle rule, the cancelled-row clause extended in `task-list`, the tenancy transition renamed in the model, and a lifecycle model run that tests the claim.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No placement test remains in the convention. | `grep -n 'earn its place' .agents/skills/work-log/SKILL.md` returns nothing | Agent [x] |
| The convention states that a row's end deletes its record, cancellation included. | `grep -n 'cancelled task.s row is deleted' .agents/skills/work-log/SKILL.md` | Agent [x] |
| `task-list` deletes the record with the cancelled row. | `grep -n 'cannot own one' .agents/skills/task-list/SKILL.md` | Agent [x] |
| The model holds the claim, and names the one condition it needs. | `.scratchpad/statechart/record_lifecycle.tla`; `NoRecordOutlivesTheLastRow` fails until cancellation deletes the record | Agent [x] |
| The gates and the suite pass. | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The placement test is withdrawn. | It judged a record that a lifecycle already bounds: a record exists because a row introduced it, and it goes when that row ends. A judgement on top of that bounds nothing. | `work-log` |
| A row's end includes cancellation, and a cancelled row takes its record with it. | The model found the hole: a deleted row owns nothing, so the record it introduced is orphaned with no close event to delete it. | `work-log`; `task-list` |
| The layer holds no parking state. | Kept from the previous row: it is what made an unbounded archive possible. | `work-log` |
| The eight rows corrected in the previous row keep their corrected text. | Their records were deleted while the rows stayed open, which this rule now forbids; the text says what carries the evidence, which is true of the tree. | this record |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The lifecycle model reproduced the operator's claim: `NoRecordOutlivesTheLastRow` holds once a cancelled row deletes its record, and fails while cancellation leaves the record behind. | model | the claim is true under one stated condition, and the condition is the one the convention omitted | `work-log`; `task-list` |
| Rewriting a row so it drops the record's name is benign under the lifecycle rule: the record stays while the row is open and dies when it closes. | model | no rule is needed for the rewrite; the close does the work | this record |
| The eight deletions of 2026-11-26 were made under the placement test, which this row withdraws. | record | the tree holds deletions the current rule does not permit, and each is recoverable from its parent commit | recorded here rather than reversed |

## Model

`record_lifecycle.tla` in the session scratch: states `rec` (absent, live, deleted), `row` (none, open, closed, cancelled) and `named` (yes, no). Actions: a task opens with its record, the row closes and deletes it, the row is cancelled, the row is rewritten, a record appears unbidden, an owned record is swept, an orphan is repaired. Four invariants, three of them deliberately violable: `EveryLiveRecordHasANamingRow` fails on the unbidden record, `NoRecordIsBornWithoutARow` fails for the same reason and is the gate's job, `TheGateIsSound` fails while a row can name a swept record, and `NoRecordOutlivesTheLastRow` fails on cancellation and holds once cancellation deletes the record.
