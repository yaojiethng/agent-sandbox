---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - Gate owns the close decisions

## Objective

The release gate asks every question the close would otherwise answer, so the close is data entry. A finding carries its destination when it is raised. The read-only audits run before the release. A lint check proves the record conforms, rather than a prompt asking the agent to notice.

## Scope

**In scope.** The row `The close decisions move to the release gate`, nested under `Declare the maintenance surface`. The diagnosis, already landed in `## Diagnosis`. The finding as a record with states, and the point where its destination is decided. `docs/reference/autonomous_agent_loop.md` and the transition rules in `docs/adr/coding_agent_loop_workflow.md`: the acceptance gate's evidence set, findings as a named input, and the sentence that defines the close as work. `docs/policies/iteration_policy.md`: the triage invariant at raise time and the late-decision path. `/iter` Step 7 and the release gate: the findings queue and the record-check reports join the pre-close summary. `workflow/coding-agent/prompts/wrapup.md` Part B: the record checks move before the gate, and the close keeps the duty to raise what it finds. `scripts/lint/handover-format.mjs` and `tests/test_handover_format_gate.sh`: the enforcement seam.

**Out of scope.** Repairing the links inside archived handovers that name documents retired since those records closed. A closed record keeps its content, and moving the record is not permission to rewrite it. Reducing the two gates; both stay. Suppressing late discovery: the close still raises every decision it finds, and the change is where a known decision is asked, not whether an unknown one may surface. Milestone-grain compaction and changelog drafting, which belong to `/milestone-close`. The model-selection thread, closed at `e802f13c`. Rewriting the maintenance skills' own methods.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| AC1 The diagnosis states four counts that the two scripts re-derive | `node .scratchpad/diagnose.mjs` and `node .scratchpad/diagnose-turns.mjs`, both run in this session | Agent [x] |
| AC2 `iteration_policy.md` requires the destination at raise time and names the late-decision path | `grep -n "Write Findings immediately, with its destination" docs/policies/iteration_policy.md`; the file's lines 93, 114, 118 and 126 | Agent [x] |
| AC3 `/iter`'s pre-close verification runs both record checks and carries the findings queue with their reports, and the release gate paragraph presents them | `workflow/coding-agent/prompts/iter.md`, the sixth summary item and the release gate paragraph | Agent [x] |
| AC4 `wrapup.md` dispatches neither record check and keeps a late-raise step | `grep -c "roadmap-maintenance\|handover-maintenance" workflow/coding-agent/prompts/wrapup.md` prints 0; three `recorded as \`late\`` clauses | Agent [x] |
| AC5 The reference document names findings as gate evidence and says the close lands and raises | `grep -n "the agent presents the findings queue\|It lands what the gate confirmed" docs/reference/autonomous_agent_loop.md` | Agent [x] |
| AC6 The ADR records the gate inputs and the close's raise-only role | `docs/adr/coding_agent_loop_workflow.md`, the `2026-10-20` section | Agent [x] |
| AC7 The lint gate fails a `Closed` handover whose Findings row lacks a destination, by a fixture the pre-change scanner passes | `bash tests/test_handover_format_gate.sh`, case `t10`; 13 of 13 pass | Agent [x] |
| AC8 The same gate passes a finding triaged `late`, so the late path is legal | same test, cases `t11` and `t12` | Agent [x] |
| AC9 No new runbook step and no new gate | `iter.md` keeps 6 step headings and `wrapup.md` keeps 12, counted in `HEAD` and in the tree | Agent [x] |
| AC10 A replay lists what the gate would have surfaced over the last ten iterations | `## Replay` below | Agent [x] |

## Diagnosis

Four measurements, each re-derivable by one command in this run. The unit is a decision the loop made after a release.

| Measure | Value | Command | What it shows |
|---|---|---|---|
| `[CORRECTION]` tags dated after their record's own date | 108 tags over 824 records: 49 same day, 26 within 1 to 3 days, 23 within 4 to 30, 9 beyond 30, 1 predating its record | `node .scratchpad/diagnose.mjs` | A correction dated after the record closed is a decision that record's gate did not ask for |
| Records whose Findings table carries a `Triaged to` column | 35 of 824, and 34 of those 35 have every cell filled | `.scratchpad/diagnose.mjs` reads every table header and its cells | The column exists and is mostly filled where it exists, and 789 records show the policy's requirement was not enforced |
| Delivery commits amended in this container | 1, today's `bf4aa6b9` | `git reflog --date=iso \| grep -c 'commit (amend)'` | Counts this container only. The accepted history is created by the diff pipeline, so it is not the workflow's amend rate |
| Findings whose destination was decided after the operator's last message before the close | `20261020-01`: 6 of 11. `20261019-11`: 0 of 10 | `.scratchpad/diagnose-turns.mjs` walks the owning session, takes the operator's last message before the close write, and finds each row's first destination | The discriminator. One iteration was ready at its gate and one was not |

**Findings rows in the last ten handovers:** 49. Thirty-five records across the corpus carry the column and 34 fill it, so the form exists and its coverage is 4 percent.

**Audit after release.** The previous iteration ran `roadmap-maintenance` at B4 and produced 5 fix-now findings, two of them defects in that iteration's own surface: a row keeping a retired exclusion beside its retraction, and a promoted section with no objective.

**Limit.** The release turn is read as the operator's last message before the close write. Eight of the ten sessions ran silent for a long stretch before their close, so their figures are upper bounds. Only `20261019-11` and `20261020-01` carry a release message immediately before the close, and only those two figures are exact.

## Replay

The redesigned gate applied to the last ten iterations, from `.scratchpad/diagnose-turns.mjs`. For each record, its findings and how many gained a destination after the operator's last message before the close. That second number is the gate-time decision the redesign moves forward.

| Handover | Findings | Destination after the operator's last message | What the gate would have shown |
|---|---|---|---|
| `20261019-03-design-prose_standards_spec_census` | 3 | 3 | all three, before the release |
| `20261019-04-audit-closed_record_corrections_assessment` | 3 | 3 | all three, before the release |
| `20261019-05-design-sentence_structure_principle` | 6 | 6 | all six, before the release |
| `20261019-06-plan-communication_domain_milestone` | 3 | 3 | all three, before the release |
| `20261019-07-plan-neutral_census_and_codemode` | 4 | 4 | all four, before the release |
| `20261019-08-docs-free_tier_quota_in_the_dispatch_skill` | 4 | 2 | the two undecided rows as gate questions |
| `20261019-09-plan-file_the_requests_per_task_metric` | 2 | 2 | both, before the release |
| `20261019-10-workflow-file_attach_as_you_read` | 3 | 3 | all three, before the release |
| `20261019-11-audit-neutral_principle_census` | 10 | 0 | nothing changes; that iteration was ready at its gate, and its record and report were removed in handover `20261020-06` |
| `20261020-01-workflow-model_selection_instruction_surface` | 11 | 6 | six destinations, before the release |

The ten closed records hold 49 findings rows. Two cases carry the argument. `20261019-11` scores zero, so the check does not fire on an iteration that was ready. `20261020-01` scores six of eleven, and the two defects its close-time audit found, a row keeping a retired exclusion and a promoted section with no objective, are what a gate-time record check reports.

Limit: eight of the ten sessions ran silent before their close, so their figures are upper bounds. Only `20261019-11` and `20261020-01` carry a release message immediately before the close, and only those two are exact.

## Decisions

| Decision | Rationale | Recorded in |
|---|---|---|
| The finding is specified as a record with states, not a table row | A row has no state, so nothing distinguishes raised from triaged, and the close becomes the only place the distinction is made | this record |
| Triage is required at raise time | The destination is cheapest to decide while the evidence is fresh, and the release gate then reads a decision instead of making one | this record |
| The close keeps its duty to raise what it finds | A late decision is evidence that a check sits in the wrong place, so the close records it with the gate that should have asked; suppressing it would remove the signal the loop learns from | this record |
| The handover field names the active milestone, not the section its row sits in | A dispatch fix can be filed under an earlier sub-milestone while the active one is later, so the field follows the roadmap frontmatter and the section follows the task's parent | this record |
| The gate summary gains one section rather than one step | The gate must show the findings queue, and the queue is shown at the release the iteration already has; a step would be a new stop, a section is more evidence at the existing one | this record |
| The model carries the placement, not only the prompts | The reference document and the ADR name the gates' inputs, and a prompt that contradicts them is the defect this iteration removes | this record |
| The work rides a new child row under `Declare the maintenance surface` | The parent also covers coverage checks for the maintenance skills and is a larger change; the run point where the audits fire is one part of it | `devlog/roadmap.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The diagnosis command did not re-derive its own figures: the column test matched only a first-column header, and the replay script read the emptied live folder | defect, this surface, found by the gate's handover check | two counts could not be reproduced from the record | fixed: both scripts find the column in any position and read `archive/`, and both were re-run |
| The record's title, its empty Decisions-pending form, and three files missing from Completed did not match the work-log convention | defect, this surface, found by the gate's handover check | the record did not match its own convention | fixed |
| `iter.md` listed the two record-check reports but prescribed no run for either, so the roadmap row's claim that both run before the release was false | defect, this surface, found by the gate's roadmap check | the design named evidence it never asked for | fixed: the sixth summary item runs both skills |
| The closed row `A mechanism constrains which models an agent can reach` states "the role table is the only source of a dispatch's pair", which `opencode-dispatch/SKILL.md:16` falsifies with its pinned default | pre-existing, found by the gate's roadmap check | a closed row asserts a fact the tree contradicts | `/milestone-close` with the compaction, and open row `The dispatch-rule surface` owns the skill's default |
| The handover's `milestone` field named M3.3.2, where its row lives, and the roadmap frontmatter names M3.3.4 as active | record defect, this surface | the convention requires the field and the frontmatter to agree | fixed on operator direction: the field names the active milestone, and a dispatch row may sit under M3.3.2's section out of order, which is known |
| `iter.md` still said the pre-close summary has five sections after the sixth landed | defect, this surface, found by the gate's handover check | the prompt contradicted its own list | fixed: six sections |
| The diagnosis reported 1 of 824 records with a destination column; the count is 35, and 34 fill every cell | defect, this surface, found by the gate's handover check | the headline overstated the gap | fixed in `## Diagnosis` and `## Replay` |
| This record's AC and Decisions-pending tables used columns the work-log template does not state | defect, this surface, found by the gate's handover check | the record did not match its own convention | fixed: `Criterion \| Verification \| Result` and `Question \| What it blocks \| Options` |
| The roadmap child row named three read-only audits where the gate runs two record checks | defect, this surface, found by the gate's roadmap check | a count the tree does not hold | fixed: the row names both checks |
| The roadmap child row cited `/iter` Step 7 | defect, this surface, found by the gate's roadmap check | the step number moves with every edit above it | fixed: the row names the pre-close verification |
| The closed row `A mechanism constrains which models an agent can reach` still carries its implementation narrative and measurement literals | pre-existing, found by the gate's roadmap check | the task-list convention compacts a closed row to what landed plus a handover link | `/milestone-close`, which owns compaction |
| The `--staged` scan enforced records under `archive/`, so populating the archive failed the gate | defect, this surface | the move could not land | fixed: the staged pathspec excludes `archive/` |
| This record's Findings table held an unescaped pipe inside a backticked command | defect, this surface | markdownlint failed on the record the gate reads | fixed: the pipe is escaped |
| Links inside archived handovers name documents retired since those records closed | out of scope | a reader following one finds nothing | ruled out of scope, with the reason in `## Scope` |

## Completed

| File | Change |
|---|---|
| `docs/policies/iteration_policy.md` | the destination at raise time, the gate's evidence rule, the close publishes and raises |
| `workflow/coding-agent/prompts/iter.md` | Step 7's sixth section, the exit condition, the acceptance-gate paragraph, Steps 8-9 |
| `workflow/coding-agent/prompts/wrapup.md` | B4 writes what the gate released, B6 publishes, B8 publishes the correction, B9 names the format gate |
| `docs/reference/autonomous_agent_loop.md` | the agent presents at the gate, the close lands and raises, findings named, the work-log convention |
| `docs/adr/coding_agent_loop_workflow.md` | the 2026-10-20 section |
| `scripts/lint/handover-format.mjs` | the `Closed` findings-destination check and its section helper |
| `scripts/check_handover_format.sh` | the staged scan excludes `archive/` |
| `tests/test_handover_format_gate.sh` | three findings cases, 13 of 13 passing |
| `devlog/handovers/archive/` | 149 records moved, and the links that named them rewritten in the files that carry them |
| `.agents/drafts/harness-tier-unification-run.md` | a handover link rewritten to `archive/` |
| `devlog/discussions/20261018-study-settled-numbering_scheme_census.md` | the same rewrite |
| `devlog/discussions/20261019-report-settled-neutral_principle_census.md` | the same rewrite; the report was removed in handover `20261020-06` |
| `devlog/roadmap.md` | the nested row `The close decisions move to the release gate` |

[CORRECTION -- 2026-10-20: the neutral-census record and report named above were removed in handover 20261020-06; the paths no longer resolve.]

[CORRECTION -- 2026-10-20: the series rewrite in handover `20261020-07` changed this iteration's id from `e802f13c` to `bf4aa6b9`; the row is updated and the old id no longer resolves.]
