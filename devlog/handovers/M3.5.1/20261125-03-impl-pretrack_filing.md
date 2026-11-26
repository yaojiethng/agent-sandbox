---
date: 2026-11-25
milestone: M3.5.1 - The work-log record layer
type: Implementation
status: Closed
---

# Handover - the pre-track handovers are filed

## Objective

File the loose pre-track handovers into their milestone's track, delete the ones whose track a milestone close has retired, and remove the gate's root-level exemption so no record sits at the handovers root again.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No record sits at the handovers root. | `find devlog/handovers -maxdepth 1 -name '*.md'` lists nothing | Accepted: empty. |
| The three open-milestone records sit in their track and pass the folder check. | `find devlog/handovers/M3.4 devlog/handovers/M3.4.1 -name '*.md'` lists three; `bash scripts/check_handover_format.sh` | Accepted: three, gate clean across 53 records. |
| Each deleted record is absent, and the removal commit's parent renders it. | `git show HEAD:devlog/handovers/20261016-01-docs-resolution_model_and_census_defects.md` renders its `date:` line; `test ! -e` the same path | Accepted: history prints `date: 2026-10-16`; the path is absent. |
| The gate fails a record at the handovers root. | `bash tests/test_handover_format_gate.sh` | Accepted: 24 passed, 0 failed, including the root case. |
| Every decision this record carries is realized in the files. | Step 7 read of the Decisions table | Accepted: file-by-field, the closure predicate, both tracks, and the root finding are all in the files. |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| File each record by its `milestone` field. | The field names the milestone the record belongs to, so it decides the track without a second mapping. | This record |
| A milestone with a `## <id>` heading in `devlog/changelog.md` is closed; its track was retired, so its loose record is deleted and the removal commit holds it. | The track lifecycle already treats that heading as the closure predicate, and a record of a closed milestone has no live reader. | This record |
| Create the tracks `M3.4/` and `M3.4.1/`, both summary rows `In progress` and neither carrying a changelog heading. | Both milestones are open, so their records are current and must stay readable. | This record |
| Drop the root-level exemption from `filedUnder` and report a record at the handovers root as a finding, guarded by a test. | The exemption let the leak exist; with the root empty, the gate holds the region. | This record |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The loose records carry no citation outside `devlog/handovers/`, so filing or deleting them leaves no dangling name. | evidence | The move needs no re-pointing sweep. | This record |
| Roadmap maintenance before the scope gate: two closed `M3.5.1` rows carried no handover reference (3.6), and the two rows filed last turn carried counts the tree will falsify (3.13). | record | Both corrected in place before the gate. | This record |
