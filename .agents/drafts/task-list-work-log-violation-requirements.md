# Task-list and work-log violation requirements

**Scope:** the error classes the retired `/gm` exhaustive check searched for. Each row states an error the redesigned task-list and work-log mechanisms should make impossible by design, not a procedure to run afterwards. The source check is named for provenance only.

**Origin:** the `roadmap-maintenance` procedure and the `handover-maintenance` chain runbook, which the check-in's exhaustive branch dispatched. That branch is being retired with the record-report contract.

## Task list

| Code | The error to make impossible | Source check |
|---|---|---|
| TL1 | A task item not written as markdown task-list syntax (`- [x]`, `- [ ]`), such as an emoji or a bold header alone | `roadmap-maintenance` 1.1 |
| TL2 | A sub-item embedded in a prose paragraph instead of an indented bullet | 1.2 |
| TL3 | A partially complete parent with no completion context, or a done child without its `- [x]` marker | 1.3 |
| TL4 | A closed item carrying an open child | 1.4 |
| TL5 | A fully completed group still carrying its expanded checklist | 2.1 |
| TL6 | A compacted item that lost its `- [x]` marker | 2.2 |
| TL7 | A compacted item retaining a removed component (design link, file list, implementation note, sub-checklist, task breakdown, completed `Depends on`, `Prerequisite for`) or losing a surviving one (not-in-scope or deferred tag) | 2.3 |
| TL8 | A completed parent or sub-group left expanded while its children are complete | 2.4, 2.5 |
| TL9 | A manual prose summary that repeats the task list | 3.1 |
| TL10 | A superseded item still standing | 3.2 |
| TL11 | A section emptied by a removal and left as an empty heading | 3.3 |
| TL12 | A standalone ordering block that repeats existing `Depends on` lines | 3.4 |
| TL13 | An active item whose `Depends on` names a removed or compacted item | 3.5 |
| TL14 | A closed row not reduced to one line of what landed plus its handover link, carrying narrative or a count instead | 3.6 |
| TL15 | Several rows that describe one task, split by wording or boundary | 3.7 |
| TL16 | A row whose first half restates a known entry and does not name what is new | 3.8 |
| TL17 | A row bundling unrelated defects and carrying its own priority order | 3.9 |
| TL18 | A row filed in a milestone that does not own its subject, with no operator direction naming the placement | 3.10 |
| TL19 | A summary-table row that disagrees with the heading it links: wrong status, a missing fragment, or two names for one milestone | 3.11 |
| TL20 | One item restated across the roadmap records | 3.12 |
| TL21 | A row stating a fact the tree can falsify: a line or row number, a version literal, a stale path, or a sibling record cited by position | 3.13 |
| TL22 | A changelog section map that is ambiguous: a `##` heading outside `## M{n}`, or a summary link whose fragment names a correction block | 3.15.1 |
| TL23 | A changelog summary row reading `Complete` for an entry that records removal | 3.15.2 |
| TL24 | A changelog entry written in the run carrying a falsifiable fact | 3.15.3 |
| TL25 | A superseded changelog entry whose supersession is not visible where a reader meets it | 3.15.4 |
| TL26 | A task marked `- [x]` before the operator verified it | 4.2 |
| TL27 | A compaction candidate group that still holds an open task | 4.1 |

## Work log

| Code | The error to make impossible | Source check |
|---|---|---|
| WL1 | A required handover section missing, a forbidden section present, or a heading whose casing differs from the canonical form | `chain` 2 |
| WL2 | An empty nullable section without its canonical marker | 2 |
| WL3 | A handover claim that a task landed while the task's existing roadmap row does not reflect it | 3.1 |
| WL4 | An item ruled out of scope whose Scope sentence carries no reason | 3.2 |
| WL5 | A deferred item that vanished without a roadmap row or a resolution | 3.3 |
| WL6 | An invalid status value, `Active` not on the most recent handover of its track, or `Closed` elsewhere | 4 |
| WL7 | A completed-section path or named symbol that no longer exists in the tree | 5 |
| WL8 | A correction to a closed record with no `[CORRECTION]` or `[AMENDMENT]` block, or a changelog entry without `[REMOVED in MX.X]` where removal applies | 6 |
| WL9 | A correction that creates work but is not filed as a new open row | 6 |
