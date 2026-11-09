---
date: 2026-11-08
milestone: M3.7.1 - Gate boundary capability
type: Plan
status: Closed
---

# Handover - The draft branch record and its statechart

## Objective

Land the draft branch lifecycle decision and its statechart, seed the implementation as two T7 rows, and clean the roadmap carriers that still name `.draft-state` as a persisted record.

## Scope

This plan iteration targets T7's **Git boundary and repository state** row. It lands the 2026-11-08 entry in `docs/adr/diff_packaging.md`, the reference statechart, two implementation rows under the narrowed parent, and the record corrections those rows expose. It changes no code or tests. The implementation rows are out of scope: the first is **Draft consumes the package fork point; the hint is unconditional**, and the second is **Replace `.draft-state` with the branch-local draft record**.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The ADR current entry is 2026-11-08 and the old `.draft-state` and `BRANCH_FROM` clauses are marked superseded. | `rg -n "2026-11-08\|Reason superseded by 2026-11-08" docs/adr/diff_packaging.md` | Agent [x] |
| The statechart reference carries the package chart, the no-record confirm chart, and the invariant table. | `rg -n "The package\|The draft and confirm\|RecordPresentDuringDraft" docs/reference/draft_branch_statechart.md` | Agent [x] |
| The T7 parent is narrowed and the two implementation rows are present. | `rg -n 'the apply state and the composition rule' devlog/roadmap.md; rg -n 'Draft consumes the package fork point' devlog/roadmap.md; rg -n 'branch-local draft record' devlog/roadmap.md` | Agent [x] |
| The `.draft-state` examples are removed from the T11 carriers and the seed row names handover `20261102-08`. | `rg -n "Record shape: one KV\|The shapes the harness writes\|20261102-08" devlog/roadmap.md` | Agent [x] |
| The record gates are clean. | `bash scripts/check_markdown.sh`; `bash scripts/check_document_shape.sh`; `bash scripts/check_handover_format.sh` | Agent [x] |
| No code or test file changed. | `git diff --name-only` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Subsume the decision into `diff_packaging.md` instead of opening a second ADR. | The existing ADR already owns the export baseline, the workflow commands and the `.draft-state` clause; a second ADR would be a second source for one scope. | `docs/adr/diff_packaging.md` |
| Persist the statechart in a reference document, not in the ADR body. | The project keeps diagrams in `docs/reference/` and the ADR states the decision and the invariants. | `docs/reference/draft_branch_statechart.md` |
| Split the implementation into two T7 rows, fork-point consumer first. | The record row writes the fork point, so `draft` must consume the package branch point before the record can be stored correctly. | `devlog/roadmap.md` |
| Remove `.draft-state` from the T11 carriers now. | The ADR removes the record; leaving it as a persisted-record example is a stale carrier. | `devlog/roadmap.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The T7 Git boundary row still owned the draft/confirm/reject state chain after the 2026-11-08 decision. | record drift | The new row would have been a second source for the same lifecycle. | Roadmap, this iteration: the parent now keeps the apply state and the composition rule, and the two sub-rows carry the lifecycle. |
| The M3.4.2 record-shape row and the T11 Note B scope sentence still named `.draft-state` as a persisted record. | record drift | A removed record remained a carrier for the KV-pair and record-format work. | Roadmap, this iteration: the examples are removed; the rows remain for the other records. |
| The T7 seed-path row named handover `20261102-01` in `.agents/drafts/`; the actual record is `20261102-08`. | record drift | A reader could not reach the record the row cites. | Roadmap, this iteration: the row links the actual handover. |

## Completed

| File | Change |
|---|---|
| `docs/adr/diff_packaging.md` | Added the 2026-11-08 draft-record decision, marked the old `.draft-state` and `BRANCH_FROM` clauses superseded, and applied the cut pass to the whole record. |
| `docs/reference/draft_branch_statechart.md` | New reference with the package chart, the no-record confirm chart, the invariants and the model limits. |
| `devlog/roadmap.md` | Narrowed the T7 Git boundary row, added the two implementation sub-rows, removed the `.draft-state` T11 examples, and corrected the seed-row handover. |
| `devlog/handovers/M3.7.1/20261108-01-plan-draft_branch_record.md` | This handover. |
