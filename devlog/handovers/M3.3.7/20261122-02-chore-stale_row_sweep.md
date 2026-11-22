---
date: 2026-11-22
milestone: M3.3.7 - The principle corpus admission
type: Housekeeping
status: Closed
---

# Handover - the stale row evidence swept

## Objective

Correct or remove the M3.3.7 rows whose evidence no longer holds, and move the row the milestone boundary owns into M3.3.8.

## Scope

The five open M3.3.7 rows checked against the tree: the condition row's counts, the naming row's count, the `Every reference to the organizational judgement says something true` row with its two sub-rows, the voice row's requirements, and the permitted-form row's place. The `Every reference` row is dropped whole rather than closed. The permitted-form row moves to M3.3.8, which owns the merge it waits on. Not in scope, with its reason: the runbook-caller row, which is the next iteration's work and is not a correction to what this milestone already states.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The condition row names its defect without a count. | Read the row. | Agent [x] |
| The naming row names the principle slugs without a count. | Read the row. | Agent [x] |
| `Every reference to the organizational judgement says something true` and its two sub-rows are gone. | `grep` over `devlog/roadmap.md`. | Agent [x] |
| The permitted-form row sits in M3.3.8, names the reference merge as its dependency, and records the move. | Read both milestone sections. | Agent [x] |
| The voice row records the corpus's extension of Rule 3.6 in its requirements. | Read the row. | Agent [x] |
| The record and lint gates hold. | `check_handover_format.sh`, `check_record_citations.sh`, `check_record_lifecycles.sh`, `check_record_names.sh`, `lint.sh`, `run_tests.sh`. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The `Every reference` row is dropped, not closed with `[x]`. | Nothing landed because nothing was needed, and a `[x]` asserts a landing; the precedent is the 2026-11-20 ruling that a stale row is moved or dropped, never closed with a pointer. | The roadmap; this record. |
| The two counts are dropped rather than re-measured. | The condition row's class is a judgement call, so its numbers are not reproducible and nothing re-derives them; the naming row's count was one edit behind the corpus, at 27 against 28 principles. | The two rows; this record. |
| The permitted-form row moves to M3.3.8. | It cannot land before the reference merge, and M3.3.7 closes first. | The roadmap; this record. |
| The owner keeps its wider passive exception, recorded as the corpus's extension of Rule 3.6. | The operator's ruling: the corpus may extend a referenced rule, and the citation must say so rather than imply the source grants it. | The voice row; this record. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The `Every reference` row named four defects: `scope.md` already names the runbook and the procedure, `rewrite-syntax` uses the boundary-dispatch form the corpus now requires, and the other two rest on a unit the principle stopped stating on 2026-11-20. | Evidence | The row is dropped whole. | The roadmap; this record. |
| The condition row's counts cannot be re-derived from its own definition, and the naming row's count was one principle behind. | Evidence | Both counts are dropped. | The two rows. |
| The voice rule's owner grants the passive when the object is the topic, which Rule 3.6 does not. | Design | The owner extends the source by the operator's ruling, and the row's requirements say so. | The voice row; this record. |
| The drop removes a `Triaged to` destination that handovers `20261105-02` and `20261122-01` name. | Record | A closed record is not edited to chase a deleted row; this record names the removal. | This record. |

## Completed

| File | One-line change summary |
|---|---|
| [`devlog/roadmap.md`](../../roadmap.md) | The condition and naming rows lose their counts; the `Every reference` row and its two sub-rows are deleted; the permitted-form row moves to M3.3.8; the voice row carries the extension requirement. |
| [`20261122-02-chore-stale_row_sweep.md`](20261122-02-chore-stale_row_sweep.md) | This record. |
