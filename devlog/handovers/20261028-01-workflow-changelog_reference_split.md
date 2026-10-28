---
date: 2026-10-28
milestone: M3.5 - Task List Mechanism
type: Workflow
status: Closed
---

# Handover - Split the changelog out of the task-list convention

## Objective

Move the changelog's entry format and its correction form out of `task-list` into a disclosed reference, so the roadmap's live task list stops carrying changelog rules and a closed roadmap row is edited in place while the changelog keeps its marker-and-successor form.

## Scope

Works the M3.5 task-list format out of order, on operator direction; no roadmap row for this slice exists yet, and the write-back proposes one under M3.5.

In scope: the two changelog-specific sections leaving `task-list` for `references/changelog.md`, the index pointer that opens it, the roadmap/changelog split in the closed-entry correction rule, the ADR entry that narrows R2 and R3 to the changelog, and the carriers that point at the moved sections.

Out of scope: the rest of M3.5 -- the store, the converter, the concurrency proof and the parallel-milestone rule.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `task-list` states neither the changelog entry format nor the closed-entry correction form; the reference holds both and `task-list` names it by the situation | `grep -n '^## ' .agents/skills/task-list/SKILL.md` shows neither section; `grep -n 'references/changelog'` shows the index row | Agent [x] |
| A closed roadmap row has an in-place form and no marker; a closed changelog entry keeps the marker and successor | read `references/changelog.md`, `record-correction.md`'s form table, and the ADR entry | Agent [x] |
| Every live carrier that named the moved sections points at the reference | `grep -rn 'The changelog entry\|Corrections to a closed entry'` returns the reference and the ADR's 2026-10-19 historical rationale only; `bash scripts/lint.sh` clean | Agent [x] |
| Every decision this iteration records is realized in the files | each Decisions row appears in the file it names | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A disclosed reference under `task-list`, not a sub-skill | the changelog never fires independently, and a new skill pays an always-loaded description for a job reached through `task-list` | this handover |
| The changelog keeps the marker and successor; a closed roadmap row is edited in place | the changelog is the permanent archive; the roadmap is the live task list, and its provenance is the handover and the git history | `docs/adr/closed_record_corrections.md`, 2026-10-28 entry; `task-list/references/changelog.md` |
| The ADR gains a dated entry rather than being rewritten | it is a claim-type record whose history is its dated entries | `docs/adr/closed_record_corrections.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The 2026-09-27 ADR rejected "a closed roadmap row editable in place"; the 2026-10-28 entry accepts it for the roadmap and keeps the rejection for the changelog | decision | a reader of the old entry sees a rejected form that is now the roadmap's rule | the 2026-10-28 ADR entry |
| `record-correction.md` said a closed record's content does not change, which the roadmap rule contradicts | defect | the procedure would forbid the edit this unit makes legal | fixed in this iteration |
| `milestone-close.md` and `roadmap-maintenance` pointed at the removed section names | defect | a reader following the pointer finds no section | fixed in this iteration |
| The ADR's 2026-10-19 rationale still names `## Corrections to a closed entry` | observation | none for a live reader, because the 2026-10-28 entry above it governs | this record |

## Completed

| File | Change |
|---|---|
| `.agents/skills/task-list/SKILL.md` | removed the two changelog sections; added the index row and the closed-roadmap-row rule |
| `.agents/skills/task-list/references/changelog.md` | new: the entry format and the closed-entry correction form |
| `docs/adr/closed_record_corrections.md` | 2026-10-28 entry narrowing R2/R3 to the changelog |
| `workflow/coding-agent/prompts/record-correction.md` | the form table and prose split roadmap from changelog |
| `workflow/coding-agent/prompts/milestone-close.md` | points at the changelog reference |
| `workflow/coding-agent/skills/roadmap-maintenance/SKILL.md` | points at the changelog reference and the roadmap's in-place rule |
| `workflow/coding-agent/skills/handover-maintenance/runbook/chain.md` | Step 6 splits the state-record form by record type |
| `devlog/roadmap.md` | the M3.5 row, marked `[x]`, and M3.5 promoted to `In progress` |
| `devlog/handovers/20261028-01-workflow-changelog_reference_split.md` | this handover |
