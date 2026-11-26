---
date: 2026-11-26
milestone: M3.5.6 - The discussion record corpus
type: Workflow
status: Closed
---

# Handover - The criteria enter the convention and the gate

## Objective

Close the three failures the criteria model found, so a record that stops earning its place cannot stay, a criterion can justify a deletion, and an open row cannot name a file that is gone.

## Scope

An eighth row on `M3.5.6`: one convention section and two rule sentences, a third finding in the lifecycle gate, eight open rows corrected, the discussion machine's note and invariants, and two gate tests.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The convention states what a record has to earn, and that a failed criterion can decide a deletion. | `grep -n 'earn its place' .agents/skills/work-log/SKILL.md` | Agent [x] |
| The convention states that the layer has no parking state. | `grep -n 'no third state' .agents/skills/work-log/SKILL.md` | Agent [x] |
| The gate flags an open row that names a record which is not in the directory. | `bash tests/test_record_lifecycle_gate.sh` 9 passed, two of them new | Agent [x] |
| No open row in the tree names a record that is gone. | `bash scripts/check_record_lifecycle.sh` clean; the same script reports eight findings before the row corrections | Agent [x] |
| The gates and the suite pass. | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The criteria are stated in `work-log` as what a record has to earn, not as a gate. | `P1` and `P4` are judgements about prose, so a gate would be a claim it cannot check; the review that applies them is the corpus review the convention already names. | `work-log` |
| The gate carries the one criterion a file can settle: an open row names a file that exists. | The other three need a reader. This one needs a directory listing, and it caught all eight rows the decision emptied. | `record-lifecycle.mjs` |
| A deleted record's naming row states what carries the evidence, and the record's name is removed rather than kept as a code span. | A code span is right for a closed row, whose link is history; on an open row it is a source that resolves to nothing. | `work-log`; the eight rows |
| The discussion machine keeps two regions and gains guards, not states. | The criteria change when a deletion is permitted, not what a record is. | `workflow_statechart.md` |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The criteria model found the gate soundness failure in three steps: a carrier appears, and both gates still read clean. | gate | `P1` has no standing check, so the corpus regrows the way the archive did | stated as a review obligation; no gate can read it |
| The code-span move that served the closed-row rule silently stripped eight open rows of their source, and no gate could see it, because a code span is not a link. | gate | the deletion landed with eight unsupported rows | the third lifecycle finding |
| The convention said tenancy alone decides a deletion, and the archive pass had already deleted eight records an open row owned. | record | the written rule forbade the work the evidence required | `work-log`; the criteria paragraph |
| The four criteria were applied once, by hand, in a dispatched pass; nothing in the tree repeats them. | record | the next archive will be found the same way, by a reader rather than a check | `work-log` states the review obligation |
