---
date: 2026-10-14
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Implementation
status: Closed
---

# Handover - retire the roadmap policy

## Objective

Retire `roadmap_policy` as a form: home its mechanism in the procedure that runs it, its convention in the project's `task-list` convention, and its remainder where it is enforced.

## Scope

The second slice of `Retire the policy form` (roadmap row `Retire roadmap_policy`), after `handover_policy`. The split method and the section-grain map are settled at handover `20261014-08` and recorded in [`20261014-design-settled-retire_the_policy_form.md`](../../discussions/20261014-design-settled-retire_the_policy_form.md); this slice applies the map and resolves what it straddles.

| `roadmap_policy` section | Fate | Destination |
|---|---|---|
| `## Roadmap maintenance` - compaction cascading, top-level milestone close, summary table update | mechanism, milestone grain | `/milestone-close`, at its compaction and records steps |
| `## Milestone Promotion` | mechanism, milestone grain | `/milestone-close` at a top-level close; `/milestone-start` and `/iter` at their own moments |
| `## Milestone States` | convention | `.agents/skills/task-list/SKILL.md` |
| `## Structure and Filing Rules` | convention | `.agents/skills/task-list/SKILL.md` |
| `## Changelog Format` | convention | `.agents/skills/task-list/SKILL.md` |
| `## Corrections to Closed Roadmap and Changelog Entries` | straddles the line | marker forms to `task-list`; the shared principle already sits in `documentation_policy.md`; the checks already sit in `roadmap-maintenance` |
| `**One record**` (preamble) | remainder | `task-list`, the rule the record set carries |
| `## When the Roadmap Is Touched` | split | the invariant (`completed tasks are marked and the commit carries the mark`) to `task-list`; the timing to the pre-close step that enforces it |

The policy document is deleted. `docs/policies/` keeps its two survivors, `iteration_policy` and `documentation_policy`, and the bundle still ships.

The reference set is 23 live files. A shipping document names the convention path in a code span rather than linking it, the way `documentation_taxonomy.md` already names `.agents/skills/work-log/SKILL.md`, because a project path is not in the image.

Out of scope: the other seven policies; the `Drop the policy bundle` step, which lands after the last policy leaves; `roadmap_policy`'s decision rows in `devlog/roadmap.md`, which are historical records; and the maintenance-surface declaration the review pass identified, which is raised as its own row.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `docs/policies/roadmap_policy.md` is gone and no live reference to it survives outside closed records, the two ADRs that recount the pre-decision state, and four dated `AGENT_FEEDBACK.md` entries | `git ls-files docs/policies/`; filtered `grep -rn roadmap_policy` | Agent [x] |
| The convention half - milestone states, numbering, the record's shape, the filing rules, the changelog entry, and the correction markers - is stated in `.agents/skills/task-list/SKILL.md` | read it | Operator [x] |
| The milestone-grain procedure - the compaction, the upward cascade, the top-level close, the summary table update and the promotion transport - is owned by `/milestone-close`, and the task-grain compaction by `/wrapup` B4 | read both | Operator [x] |
| No advisor carries a procedure it does not execute, and no prompt is the only home of a rule | read `roadmap-maintenance`; grep the timing invariant | Operator [x] |
| `roadmap-maintenance` is an advisor: it names the owner of each rule it tests, and its schedule sits with the prompts that dispatch it | read it | Operator [x] |
| Architecture documents in scope describe the system as built | `docs/reference/agent_workflow.md` | Operator [x] |
| The roadmap maintenance run's finding is applied and recorded | `sed -n '185p' devlog/roadmap.md` | Agent [x] |
| Every repointed reference resolves, and no shipping document links `.agents/` | record-links gate; grep for a `.agents/` link under `docs/` and `workflow/` | Agent [x] |
| Lint is clean and the suite is green | lint across 8 gates; suite | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `## Corrections to Closed Roadmap and Changelog Entries` resolves by subtraction like a named section | the map is at section grain and the design says a straddling section is resolved in the slice that moves it; its principle already lives in `documentation_policy.md` and its checks in `roadmap-maintenance`, so only its marker forms were unplaced | this handover |
| The remainder's two rules are stated where they are enforced, so no document survives | `roadmap_policy` is one of the six that dissolve; its remainder binds no other procedure | this handover |
| Ownership follows the grain, and the executor owns the procedure: task-item compaction is the iteration close's, a sub-milestone's compaction and everything above it are `/milestone-close`'s | operator direction in the review of this unit; the skill is an advisor and executes neither, so a procedure it cannot run is a runbook body in the wrong file | this handover |
| The rule is "a completed task is marked and the mark is committed"; the timing is a step of the procedure that enforces it | operator direction: a timing specification is not a rule, and it belongs where the work happens. The close marks the row; the write-back rides the delivery commit | `task-list` `## Marking a task done`; `wrapup` B4 |
| The timing is stated at the grain that enforces it rather than as one strict condition | operator direction: an equivalent effect is acceptable so long as the task is checked off by the close that resolves it | `wrapup` B4 |
| The schedule moves from the advisor to the prompts that dispatch it | a dispatch moment is the procedure's, by the same rule the compaction move follows; the advisor keeps the access rule and the exclusion | `roadmap-maintenance` `## When to run`; `/iter`, `/wrapup`, `/milestone-close`, `/milestone-start` |
| The two skills are rewritten to the writing bar by two adviser subagents, one owning each file | the unit's own prose had grown past a readable length, and a second voice on the delete test is cheaper than another pass by the author; the diffs are not separable from the unit's own edits because no snapshot was taken first | this handover; review pass below |
| A `state:` field or a catalog for the dispatcher set is deferred | the ADR already reserves **maintenance surface** as "the fixed set of maintenance skills the prompts invoke", so the set is a declaration on the fixed side, not a per-skill key; the handoff decision rejected name-based discovery for a deterministic path, so the shape is a mapping and not a lookup | roadmap row **Declare the maintenance surface** |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The `/iter` runbook delivered to the session is the installed copy, which lags the repository: it still states a `## Hot files` section, a `handover_policy.md` reference, and two acceptance-criteria table shapes, all retired in iterations `20261014-09` and `20261014-10`. The repository copy is the source of truth and this run followed it. | contradiction | not this iteration |
| `roadmap.md` row `Retire handover_policy` read `[ ]` although handover `20261014-09` closed it and commit `80bb143` landed. | write-back omission | current iteration |
| The first reviewer run (`opencode-go/step-5-preview-free`) timed out after 955 s with an empty report and did no work; it was re-run, and the tree was scored in the interval rather than the report. | obstacle | resolved in this iteration |
| Two review passes found four sentences naming a deleted policy as the authority of rules this unit had re-homed, the one-record rule stated in two files, and two prompts restating a rule whose owner is the convention. | defect | current iteration |
| The same passes found eight rules or qualifiers the move dropped: the marker-reversion rule, the targeted-edit rule, the changelog's balance guidance, the correction-reopen half, the `roadmap_future.md` framing, the anti-accumulation sentence, the top-level close's `## Upcoming Milestones` qualifier, and the promotion transport's four verbs. | content loss | current iteration |
| An eval fixture could not satisfy its own assertion: `placement-check.json` expected a finding grounded in the placement default, and its fixture trimmed away the tree that default now lives in. | defect | current iteration |
| The two skills were rewritten to the writing bar by two subagents on `openrouter/z-ai/glm-5.3-flash` at high. `roadmap-maintenance` went 167 to 149 lines and `task-list` 145 to 128, losing no rule. Their reports were verified claim by claim; two claims were refuted as overstated, and both were harmless. No snapshot was taken before dispatch, so their diff is not separable from this unit's own. | process defect | recorded, not repeated |
| The writing grew past a readable length: `roadmap-maintenance` reached 237 lines against the 193-line policy it partly replaced, and the dogmatic per-step completion criterion was the larger contributor. | verbosity | current iteration, remainder raised as a row |
| The advisor's `## When to run` was the advisor stating its callers' business, and the dispatcher set is visible nowhere in one place. | design gap | current iteration, remainder raised as a row |

## Completed

| File | Change |
|---|---|
| `docs/policies/roadmap_policy.md` | deleted; its content homed below |
| `.agents/skills/task-list/SKILL.md` | gains the convention half: milestone states, numbering, the record's shape, the filing rules, the changelog entry, the correction markers, and `## Marking a task done` carrying the invariant |
| `workflow/coding-agent/skills/roadmap-maintenance/SKILL.md` | repoints its 17 citations; gains the owner map; loses the procedures it does not execute; its checks merge; 237 - 167 lines under the writing review |
| `workflow/coding-agent/prompts/milestone-close.md` | owns the milestone-grain compaction, the cascade, the top-level close and the promotion, each step with a completion criterion; its `## Invariants` and `## Update the records` recaps cut |
| `workflow/coding-agent/prompts/wrapup.md` | B4 owns the task-grain compaction; the invariant is referenced, not restated |
| `workflow/coding-agent/prompts/iter.md` | the write-back presents the compacted item; the promotion check and design step repointed; dispatches the advisor |
| `workflow/coding-agent/prompts/milestone-start.md` | dispatches the advisor before the selection is written |
| `workflow/coding-agent/prompts/plan.md`, `sidequest.md` | repointed |
| `AGENTS.md` | the three roadmap references repointed to the project's `task-list` convention |
| `docs/policies/iteration_policy.md` | the five milestone-state and close references repointed |
| `docs/policies/documentation_policy.md` | the correction-index rows repointed |
| `docs/reference/agent_workflow.md` | the workflow table and the roadmap/iteration boundary paragraph rewritten to name the new owners |
| `docs/reference/documentation_taxonomy.md` | the roadmap and changelog rows repointed |
| `docs/development/contributors.md` | the two reading-list links became code spans, since the file names a path the image does not carry |
| `devlog/AGENT_FEEDBACK.md`, `check-in/SKILL.md`, `check-in/report-schema.md`, `eval/evals/placement-check.json`, `audits/surface-area-report.md`, `drafts/maintenance.md` | repointed; the report schema's check id follows the merged check |
| `workflow/coding-agent/skills/roadmap-maintenance/SKILL.md`, `.agents/skills/task-list/SKILL.md` | rewritten to the writing bar by two adviser subagents; every rule verified present |
| `devlog/roadmap.md` | the maintenance correction (`Retire handover_policy` marked `[x]`), the slice row marked `[x]`, four links and three names repointed, and two rows raised |
