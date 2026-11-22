---
date: 2026-11-22
milestone: M3.3.7 - The principle corpus admission
type: Plan
status: Closed
---

# Handover - the header rule re-filed to the task list

## Objective

Move the row-header rule out of the principle sub-milestone into the one that owns the task list, and write it as an intent with the method left to the doer.

## Scope

The `Rewrite the condition-shaped row headers` row of M3.3.7, its new home under M3.5.2, and the `Not in scope` line that keeps it from drifting back. The row's own subject is unchanged; only its home, its header and its grain are. Not in scope: the sweep of the current open rows, which the moved row's finish deliberately excludes; and the neighbouring form-study row, which is flagged in Findings and not edited.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The row is gone from M3.3.7. | `grep -c "condition-shaped" devlog/roadmap.md` returns `0`. | Agent [x] |
| The row sits in M3.5.2, beside the row that measures the task-row form. | Read M3.5.2's task list. | Agent [x] |
| The header opens on a verb, and the row names its class and its dependency. | Read the row against `task-list`'s Task granularity and Row headers paragraphs. | Agent [x] |
| The row states the outcome and leaves the instrument to the doer. | Read the row against `communication-principle-state-intent-delegate-method`'s test: name the decisions the row leaves to the doer. | Agent [x] |
| M3.3.7's `Not in scope` names the task-list rows, so the misfiling cannot repeat. | Read `##### Not in scope: M3.3.7`. | Agent [x] |
| The record and lint gates hold. | `check_handover_format.sh`, `check_record_citations.sh`, `check_record_lifecycle.sh`, `check_record_names.sh`, `lint.sh`, `run_tests.sh`. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The row moves to M3.5.2 rather than folding into the neighbouring form-study row. | The operator chose the move over the fold and the deferral: the row survives where someone will find it, and the check is worth having whichever form the study picks. | The roadmap; this record. |
| The row is rewritten as an intent, with the instrument left open. | The filed row named a method (one pass over the headers) whose finish nothing could see; the rule the corpus needs is that a condition-shaped header is caught where it is filed, not that yesterday's headers are reworded. | The moved row; this record. |
| The class-less half is dropped from the row, and the row says where that half is held. | `task-list` refuses a row that names no class at the scope gate, which is the moment the class decides anything, so the row would duplicate a holder that already exists. Naming the holder stops the half being re-added. | The moved row; this record. |
| The row depends on the form study above it. | That row proposes enforcement only after its histogram is on the table, so a row that asks for a check must not land ahead of it. | The moved row's `Depends on`; this record. |
| M3.3.7 gains a `Not in scope` line rather than only losing the row. | Without the line, the next header defect found in a principle iteration is filed here again, which is how this row arrived. | `##### Not in scope: M3.3.7`. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The row was filed by locality: the iteration that wrote the `task-list` header rule (`9bb8f6af`, handover `20261119-06`) lived in M3.3.7 and parked the deferred sweep there, though M3.3.7's own boundary sentence reads "This sub-milestone owns the principles themselves: how one enters or changes". | Record | The row moves, and the boundary gains a `Not in scope` line. | The roadmap; this record. |
| The premise still holds: of 174 open rows, 107 do not open on a verb, 88 of them opening on "The" and 11 on "A". Both counts come from `grep -c '^- \[ \]' devlog/roadmap.md` and from the same rows piped through a first-word match on the determiners and negations, taken 2026-11-22. | Evidence | The row keeps the subject and drops the pass. | The moved row; this record. |
| The neighbouring form-study row is itself method-prescriptive, naming a report-only scanner, a defect coding, a red-team corpus and a cold-writer probe. | Design | It sits against the principle this row now follows. Flagged, not edited: that row's own iteration owns it. | This record. |
| `tests/test_doc_wrap_legacy_gate.sh` sits on its 45s deadline in this container: three runs of the same tree measured 24s, 37s and 49s, so the suite reports it as a timeout under load while it passes standalone. | Environment | The suite's two timeout reports are the deadline, not a regression; the test's own result is `5 passed`. | This record. |

## Completed

| File | One-line change summary |
|---|---|
| [`devlog/roadmap.md`](../../roadmap.md) | The header row leaves M3.3.7 and lands under M3.5.2 as an intent-shaped row with its class and dependency; M3.3.7's `Not in scope` names the task-list rows. |
| [`20261122-04-plan-header_rule_re_filing.md`](20261122-04-plan-header_rule_re_filing.md) | This record. |
