---
date: 2026-11-26
milestone: M3.5.6 - The discussion record corpus
type: Plan
status: Closed
---

# Handover - The discussion corpus, cleaned rung by rung

## Objective

Settle how the live discussion records are cleaned: the disposition rule for a stale record, the rung order that keeps every step permitted by the rules in force, and the two conventions that gain a clause so the cleanups stay cleanups.

## Scope

A plan session at milestone grain. This record and the five roadmap rows it rewrites are the whole change; the reading, deletion and rename work hands to a scope brief.

The problem is a sequence, not a corpus. The gates exempt every record dated before `20261105` through one constant in `scripts/lint/record-cutover.mjs`, and the exemption hides what the rules have since retired. The handover clear-out removed 716 archived records and 13 retired tracks; the discussion corpus never had the same pass. Read as a sequence, the milestone is four rungs, each permitted before it runs and each shrinking the set the next one starts from:

1. **Delete what the rule already orphans** -- a record whose row closed and whose decision an ADR, a milestone or the principle corpus carries.
2. **Narrow by tenancy** -- a record whose row stops needing it is orphaned by the row, then deleted; a record an open row still needs stays.
3. **Narrow by conformance** -- what survives carries one status shape and the live vocabulary, so no live record is exempt.
4. **Delete the constant** -- the exemption has nothing left to exempt, so the gates hold the whole corpus.

Measured, 2026-11-26, against the live tree:

- 17 records in `devlog/discussions/`; 12 are named by an open roadmap row, 5 by none.
- Of the 5 unowned: 2 designs are carried by `docs/adr/coding_agent_project_bindings.md`, 2 records of the sentence-structure stratum by the four `communication-principle-*` skills, and `20261023-design-settled-derived_artifacts` by `principle-justify-materialization-cost` plus `M3.3.2`'s closed census row.
- The survivors carry retired state tokens (`draft`, `settled`, `active`) and one holds YAML frontmatter where the rest put `**Status:**`.

Out of scope: `devlog/discussions/archive/` (80 records, operator ruling), the handover record layer, and the `scripts/worklog.sh` defect recorded under Findings.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The disposition rule names what is stale, with one branch for metadata and one for contents. | the first row of Decisions; the `work-log` clause it commits | Agent [x] |
| Each rung's permission exists before the rung runs, and the permission names its carrier. | the rung list in Scope; rows 1-5 of the milestone | Agent [x] |
| The milestone owns the row edits wherever a row lives, and no cancelled row is marked complete. | row 3; the `task-list` clause it adds | Agent [x] |
| Every ruling is realised in a roadmap row. | the five rows under `M3.5.6` | Agent [x] |
| The gates pass. | `bash scripts/lint.sh`; `bash scripts/check_handover_format.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The disposition splits on what is stale: metadata stale and contents live means rename under a stated permission; contents stale means the record is moot and goes unless something strictly requires it. | A name is a label over the content; when the content has moved past the tree, no label repairs it. | This record; the `work-log` clause; milestone rows 3 and 4 |
| A survivor's verdict rests on reading it against the tree, not on the row that cites it. | The binding-surface record looked owned and its inventory had drifted five times over; a citation is a claim, not evidence. | This record; milestone row 3 |
| The milestone owns the row edits, wherever the row lives; a moot row is deleted or rewritten, never marked complete. | A `[x]` on work nobody did disguises a cancellation as a delivery, which is the churn this milestone removes. | This record; the `task-list` clause; milestone row 3 |
| The four records whose decision an ADR or the principle corpus carries are deleted, and the ADR's `### In development` sentence is corrected. | `M3.3.2` closed, so the sentence is false, and it defers to a record that the record's own pruning rule forbids knowledge to cite. | This record; milestone row 1 |
| `derived_artifacts` is deleted into two carriers: its rule is `principle-justify-materialization-cost`, its census is `M3.3.2`'s closed row, and R1--R4 fold into the deferred scope. | The record's own handoff names that principle under a name no longer in the tree; the rejections are the only part no carrier holds, and they answer the section's opening question. | This record; milestone row 2 |
| The rename is permitted by a stated clause, not by a fabricated edit. | The convention permits a rename on a substantive edit; a corpus review is not one, and a touch line added to unlock a rename is the churn the milestone removes. | This record; the `work-log` clause; milestone row 4 |
| The reading, deletion and rename are the iteration's work, not this session's. | The plan would read the corpus twice to write a table the iteration then acts on. | This record; the scope brief |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The ADR's `### In development` section says its principle "stays under development until they land" and points at the binding-surface record, though `M3.3.2` closed. | record | a live ADR defers to a record the plan proposes to delete, and to a state that no longer holds | milestone row 1 |
| `scripts/worklog.sh latest` and `list` answer nothing, because `current_track` derives a track from the newest live record's `milestone` field and that track has no folder. | tool | every procedure that opens with `latest` starts blind | this record; not this milestone |
| `work-log` permits a rename only on a substantive edit, so rung 3 had no permission for a record that is clean and merely misnamed. | convention | a corpus review cannot correct a name without inventing content to earn it | the `work-log` clause; milestone row 4 |
| `task-list` states no form for a task that will never be done, so a cancelled row would be re-invented as `[x]` by the next session. | convention | a cancellation would be recorded as a delivery | the `task-list` clause; milestone row 3 |
| `principle-guard-derived-state`, the name the derived-artifacts record hands off to, resolves nowhere; `principle-justify-materialization-cost` carries the same column test and four classifications. | record | the record's carrier is findable only by its subject | milestone row 2 |
