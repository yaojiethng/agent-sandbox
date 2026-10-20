---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Housekeeping
status: Closed
---

# Handover - remove the dead census plans and consolidate the rows

## Objective

Remove the rejected census plans from the tree, correct the records that cite them, and reduce M3.3.4 to the rows whose outcome is known.

## Scope

The forward half of the census correction: three artifacts deleted, four carriers corrected, and six planning rows consolidated into two. The history rewrite that erases the census commit from the series is out of scope, because it needs its own release and a backup ref. The re-plan page and the filing are out of scope: they are the two rows this iteration leaves standing, and they land as their own iterations.

Out of scope, with reason: the corpus. It lived only in the deleted report, and the classifier prompt's after-action entry keeps its shape and numbers.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The three artifacts are gone and no record cites them as live | `test ! -f` on the report, the design and the archived census handover; `grep -rn` over `devlog/` and `.agents/prompts/` names them only as removed, inside a correction tag, or in this record | Agent [x] |
| The classifier prompt's after-action entry stands on its own | read `.agents/prompts/classifier-models.md` `### 2026-10-19`; five lines, no source path | Agent [x] |
| The probe feedback entry is removed, and the two dispatch-hygiene entries stay | `grep -c '^## \[A\] 2026-10-19'` on `devlog/AGENT_FEEDBACK.md` prints 2 | Agent [x] |
| M3.3.4 carries four open rows: two norm-ledger rows, the filing, the re-plan | read `devlog/roadmap.md` `##### M3.3.4` | Agent [x] |
| The filing row rests on duplication, not on a census verdict | read the row; it names `20261019-06` and `20261019-12`, and no census count | Agent [x] |
| Every edited closed record carries one `[CORRECTION]` tag at the end of its corrected section | `grep -c 'CORRECTION -- 2026-10-20'` on the three records | Agent [x] |
| Every decision this iteration records is realized in the files | read this record's `## Decisions` against the tree | Operator [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The census report, its design and its own handover are deleted | the run is rejected, and a record whose deliverable is deleted has nothing left to describe | this record |
| The probe feedback entry is deleted; the other two stay | `.agents/prompts/classifier-models.md` now owns that learning, and a second home is the duplication this milestone removes | this record |
| Closed records are annotated, not rewritten | their tables state what the iterations did, which stays true; the removal is a later event and the tag states it | this record |
| The two plan rows and the dedupe row are deleted | their content is the re-plan's decision, and the spec census's line map is that plan's input | `devlog/roadmap.md` |
| The re-plan is the only carrier of undefined work | a row that cannot name a file and a nature of change is a question, and one row already owns it | `devlog/roadmap.md` |
| The spec census stays until the filing closes | it is the only map from a judgement line to its proposed group | `devlog/roadmap.md`, the re-plan row |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The deleted report was cited by the classifier prompt and two handovers, so a plan propagated further than it was validated | process | a plan's verdicts reach records before the plan is tested; the prompt's after-action entry is the durable fix | this record; `devlog/AGENT_FEEDBACK.md` holds the related entry |
| Seven rows planned the same corpus from different angles, and five rested on a method that was rejected | result | the roadmap now carries the question and the outcome, not the plans | `devlog/roadmap.md` |

## Completed

| File | Change |
|---|---|
| `devlog/discussions/20261019-report-settled-neutral_principle_census.md` | deleted |
| `devlog/discussions/20261019-design-settled-neutral_principle_census.md` | deleted |
| `devlog/handovers/archive/20261019-11-audit-neutral_principle_census.md` | deleted |
| `.agents/prompts/classifier-models.md` | the after-action entry's source clause removed |
| `devlog/AGENT_FEEDBACK.md` | the near-constant-probe entry removed; two dispatch-hygiene entries stay |
| `devlog/roadmap.md` | the two plan rows, the dedupe row and the census row removed; the filing and the re-plan rows rewritten |
| `devlog/handovers/archive/20261019-07-plan-neutral_census_and_codemode.md` | the design row corrected, `[CORRECTION]` tag |
| `devlog/handovers/archive/20261020-01-workflow-model_selection_instruction_surface.md` | two rows corrected, `[CORRECTION]` tag |
| `devlog/handovers/20261020-02-workflow-gate_owns_the_close_decisions.md` | two rows corrected, `[CORRECTION]` tag |
| `devlog/handovers/20261020-06-chore-remove_the_dead_census_plans.md` | this record |
