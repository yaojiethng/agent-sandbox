---
date: 2026-10-28
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - the cleanup pass is one runbook, and its records move into the fixture

## Objective

Leave one artifact carrying the instruction-cleanup pass, and put the records the eval grades against where the case can hold them, so a reader checks one file for the pass and one archive for its evidence.

## Scope

The cleanup pass, its carrier records and the fixture that seals them: the 167-line prompt and its goal-only draft, the runbook that replaces them, the four `devlog/discussions/` records the case is graded from, the fixture's `reports/` subtree, and every live citation of those files.

Out of scope, one sentence each with the reason: the eval's ruling table stays unwritten, because it is the case's ground truth and belongs to the row that assembles the case; `20261026-report-draft-eval_inputs_required.md` stays in the tree, because it is the harness's requirement list rather than evidence about this corpus.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| One artifact carries the pass | `find . -path ./.git -prune -o -name '*instruction-cleanup*' -print` lists the runbook and the fixture directory, and no prompt | Agent [x] |
| The prompt root loses the entry | `ls workflow/coding-agent/prompts/instruction-cleanup.md` prints nothing | Agent [x] |
| The draft is gone | `ls .agents/drafts/instruction-cleanup-goal-only.md` prints nothing | Agent [x] |
| The runbook states what it accepts and returns | `grep -c '^## Scope accepted$\|^## Returns$' workflow/coding-agent/skills/prose-review/runbooks/instruction-cleanup/SKILL.md` prints `2` | Agent [x] |
| The runbook names no project path | `grep -c 'workflow/\|devlog/\|\.agents/' <the runbook>` prints `0` | Agent [x] |
| The shell lists it | the `prose-review` Runbooks table carries an `instruction-cleanup` row | Agent [x] |
| The archive holds the four records | `tar tzf tests/eval/instruction-cleanup/payload.tar.gz \| grep -c '^reports/.*\.md'` prints `4` | Agent [x] |
| The pin matches the archive | `cd tests/eval/instruction-cleanup && sha256sum -c SHA256SUMS` prints OK, and `bash scripts/check_eval_fixtures.sh` is clean | Agent [x] |
| No run can read the answer key | `tar tzf tests/eval/instruction-cleanup/payload.tar.gz \| grep '^room/' \| grep -c 'report-'` prints `0`, and the README states that only `room/` is handed over | Agent [x] |
| The records left the tree | `ls devlog/discussions/20261026-report-settled-census_six_carriers.md devlog/discussions/20261026-report-settled-instruction_cleanup_comparison.md devlog/discussions/20261026-report-settled-carrier_fates.md devlog/discussions/20261026-report-draft-ablation_problems_found.md` prints nothing | Agent [x] |
| No link dangles | `bash scripts/lint.sh` clean across 15 gates, the linking gate included | Agent [x] |
| Every decision recorded here is realized in the files | the decisions table | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The pass is a `prose-review` runbook, not a prompt | operator direction 2026-10-28; and a shell that states what a reviewer accepts and returns is where a pass with a standard belongs | the runbook, `prose-review/SKILL.md` |
| The seat returns the cleaned surface and changes nothing | the shell's translation states that a reviewer changes nothing it judges and the caller applies; a runbook that also edited would need the shell to carve a second acceptance path | the runbook's `## Returns` |
| The ruling log and the open list are parts of the return | an accepted ruling nobody can audit is a decision held only in the run, and a refinement that names its settling condition is what makes the pass improvable | the runbook's `## Returns` |
| The canonical text is the 18-line statement, and the 167-line pass is deleted | operator ruling on maintainability: the census compared fault counts and never graded them, and its own reproduction check re-raised five of nineteen sites on a second run, so no result ranks the two | `devlog/roadmap.md`, the closed row |
| The detector table dies with the prompt | the row that wanted to keep it is superseded by the ruling: the value is the standard and the log, not the procedure around them | `devlog/roadmap.md` |
| The four records move into the archive and leave the tree | a record that no longer owns a live decision is one more file to check, and inside the sealed archive it is the only form, so the drift the SOURCES table guarded against cannot happen | `SOURCES.md`, the fixture README |
| The records sit in `reports/`, outside `room/` | the census names every fault site, so a run that could read it would read the answer key; only `room/` is handed over | the fixture README |
| `container_rules_census` retires now, `surface_census` retires with its consumer | the container census has no live carrier and its findings are already in the container runbook; the surface census is still the measurement the command-surface matrix works from, so it retires when that row has taken it | `devlog/roadmap.md`, the command-surface row |
| The harness's requirement list stays in the tree | it is what the milestone building the harness reads, and its evidence lines now name the archive | `20261026-report-draft-eval_inputs_required.md` |
| The eval row moves to M3.3.5 | the harness that runs it is that milestone's, and this one's acceptance criteria carry no eval | `devlog/roadmap.md` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The eval still has no ruling table to grade against | data | carried forward: the case cannot be graded until one carrier's sites are ruled | `devlog/roadmap.md`, the case row |
| `SOURCES.md` argued that the records must stay in `devlog/` so a copy could not drift; the deletion inverts the argument rather than breaking it | record | the archive is now the only copy, so there is nothing to drift from | `tests/eval/instruction-cleanup/SOURCES.md` |
| The ablation's contamination finding now survives only inside the archive | docs | a harness builder must open the archive to read why thirty-five cells were discarded | the harness row at M3.3.5, through the requirement list |
| `devlog/AGENT_FEEDBACK.md` cites the moved records by the names they carried when the naming defect was found | record | left as written: the entry is the incident's evidence, and those names were already replaced once | no action |
| The runbook contract forbids project paths in a runbook, so the pass cannot name where its ruling log lands | constraint | the shell states the report location, and the runbook states only that a log comes back | the runbook, `prose-review/SKILL.md` |

## Completed

| File | Change |
|---|---|
| [`workflow/coding-agent/skills/prose-review/runbooks/instruction-cleanup/SKILL.md`](../../workflow/coding-agent/skills/prose-review/runbooks/instruction-cleanup/SKILL.md) | new: the standard, the accepted scope and the three-part return |
| `workflow/coding-agent/prompts/instruction-cleanup.md` | deleted, 167 lines |
| `.agents/drafts/instruction-cleanup-goal-only.md` | deleted, 18 lines, its statement folded into the runbook |
| [`workflow/coding-agent/skills/prose-review/SKILL.md`](../../workflow/coding-agent/skills/prose-review/SKILL.md) | the Runbooks table gains the row |
| [`docs/adr/coding_agent_loop_workflow.md`](../../docs/adr/coding_agent_loop_workflow.md) | `/instruction-cleanup` leaves the active-operator prompt list, with the move recorded |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the census row's record link repointed at the fixture; the detector-table row replaced by the closed ruling row; the eval row moved to M3.3.5 and restated as the separating case |
| [`tests/eval/instruction-cleanup/payload.tar.gz`](../../tests/eval/instruction-cleanup/payload.tar.gz) | repacked with a `reports/` subtree of four records |
| [`tests/eval/instruction-cleanup/SHA256SUMS`](../../tests/eval/instruction-cleanup/SHA256SUMS) | repinned |
| [`tests/eval/instruction-cleanup/SOURCES.md`](../../tests/eval/instruction-cleanup/SOURCES.md) | the "referenced, not copied" table becomes the copied `reports/` table, with the reason the copy is now the only form |
| [`tests/eval/instruction-cleanup/README.md`](../../tests/eval/instruction-cleanup/README.md) | four subtrees, and `reports/` named as the grader's, never handed to a run |
| `devlog/discussions/20261026-report-settled-census_six_carriers.md` | deleted, sealed in the archive |
| `devlog/discussions/20261026-report-settled-instruction_cleanup_comparison.md` | deleted, sealed in the archive |
| `devlog/discussions/20261026-report-settled-carrier_fates.md` | deleted, sealed in the archive |
| `devlog/discussions/20261026-report-draft-ablation_problems_found.md` | deleted, sealed in the archive |
| [`devlog/discussions/20261026-report-draft-eval_inputs_required.md`](../../devlog/discussions/20261026-report-draft-eval_inputs_required.md) | its evidence line names the archive instead of linking a deleted record |
| [`.agents/drafts/dispatch-harness-defects-handoff.md`](../../.agents/drafts/dispatch-harness-defects-handoff.md) | same repoint |
| `devlog/discussions/20261026-report-draft-container_rules_census.md` | deleted; no live carrier, and its findings live in the container runbook |
| [`devlog/discussions/20261027-report-draft-surface_census.md`](../../devlog/discussions/20261027-report-draft-surface_census.md) | kept, and the command-surface matrix row now names it as the record that retires with that row |
