---
date: 2026-10-22
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - Move the git convention into the skill

## Objective

Make the commit and branch convention live in the `git-discipline` skill, and leave `docs/policies/git_policy.md` holding only the history and merge mechanism that unit 2 moves.

## Scope

`M3.3.2 - Retire the policy form`, slice `Retire git_policy`, unit 1 of 2. It continues the settled chain in [`20261014-design-settled-retire_the_policy_form.md`](../discussions/20261014-design-settled-retire_the_policy_form.md), after `Retire discussion_policy` (handover `20261022-08`).

This unit moves the convention half: the message format, the type material, the branch material, the fold rules and the table that names the three git maintenance runbooks as a set. The policy keeps its mechanism sections until unit 2 moves them into `merge`, `rebase`, `record-correction` and `wrapup` and deletes the file.

The eval case `commit-body-budget` tests a rule this unit moves, and `run_case.sh` requires the policy file in its candidate bundle. Both retarget here, because the rule they test changes home here.

The commit runbook is not created here. Five prompts perform a commit and no runbook owns it; the row that would give it one is filed this unit and worked separately.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill states the message format, the fold rules and the runbook table | `grep -n '^## The commit message\|^## The fold\|^## Runbooks'` | Agent [x] |
| Two references exist, one per lookup subject, each indexed | `test -s` both; two index rows | Agent [x] |
| The policy holds no convention section | the eight convention headings are gone, one pointer section present | Agent [x] |
| No live surface cites the policy for the convention | `grep -rln 'git_policy' docs scripts src workflow .agents AGENTS.md tests` prints only `bootstrap.md` and the audit record | Agent [x] |
| The eval case and its harness name the skill | `grep -rc 'git_policy'` returns 0 across the eval case, `run_case.sh` and `tests/test_eval_harness.sh` | Agent [x] |
| The suite passes with the retargeted harness | `bash scripts/run_tests.sh` | Agent [x] |
| Lint, ledger and handover gate clean | the three scripts | Agent [x] |
| The commit-runbook row is filed | `grep -c 'Give the commit its own runbook' devlog/roadmap.md` returns 1 | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The type material and the branch material become references, and the message, fold and runbook rules stay inline | A type table with its choosing rules is a lookup; the branch models carry two diagrams. The message rule is read every commit, so it stays where it is read | this record |
| The policy keeps its mechanism sections this unit, exchanging its convention sections for one pointer | A one-iteration bridge keeps each commit reviewable; deleting the convention sections outright would leave unit 2 as the only place the file's fate is visible | this record |
| `record-correction` keeps its record arm untouched and only retargets its fold citation | The prompt corrects closed artifacts of three kinds; the fold is one arm, and the other two cite `documentation_policy` and `work-log`, which are other slices | this record |
| The commit runbook is filed, not built | It is a new surface with its own loop-inventory and bootstrap entries; a migration moves content into procedures that exist | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `record-correction` is a cross-record correction runbook, not an amend prompt: its record arm spans `documentation_policy` and `work-log` | gap | reading it as the amend prompt would have moved the fold rules into a prompt that is not their home, and split a prompt whose arms are its classification | corrected in the plan; recorded here |
| `git_policy` is the only place that names `merge`, `rebase` and `history-cleanup` as one set; every other surface cites them individually | defect | deleting the file would leave the git runbook family unnamed, and a reader would find three unrelated procedures | the skill takes the table this unit |
| The eval case and its harness hard-code the policy path as the rule's home and as a candidate-bundle requirement | defect | the file cannot be deleted while the harness demands it, so the retirement reaches an eval fixture | fixed in this unit |
| Five prompts perform a commit by delegating to `/wrapup` Part B, and no runbook owns the operation | gap | `wrapup` carries a second subject, and a change to the commit rules edits a close runbook | a roadmap row, filed this unit |

## Completed

| File | Change |
|---|---|
| [`.agents/skills/git-discipline/SKILL.md`](../../.agents/skills/git-discipline/SKILL.md) | the convention home: the message, the fold, grouping, the branch shape, the runbook table, the index |
| [`.agents/skills/git-discipline/references/commit-types.md`](../../.agents/skills/git-discipline/references/commit-types.md) | new, the types, the choosing rules, the future types, the rejected scope field |
| [`.agents/skills/git-discipline/references/branching.md`](../../.agents/skills/git-discipline/references/branching.md) | new, the naming, the two models, the lifecycle, tagging |
| [`docs/policies/git_policy.md`](../../docs/policies/git_policy.md) | the convention sections become one pointer, Amending keeps only its routing lines, the frontmatter re-scoped |
| [`AGENTS.md`](../../AGENTS.md) | three retargets |
| [`workflow/coding-agent/prompts/iter.md`](../../workflow/coding-agent/prompts/iter.md) | two retargets |
| [`workflow/coding-agent/prompts/plan.md`](../../workflow/coding-agent/prompts/plan.md) | one retarget |
| [`workflow/coding-agent/prompts/document.md`](../../workflow/coding-agent/prompts/document.md) | two retargets |
| [`workflow/coding-agent/prompts/milestone-close.md`](../../workflow/coding-agent/prompts/milestone-close.md) | one retarget |
| [`workflow/coding-agent/prompts/backlog-triage.md`](../../workflow/coding-agent/prompts/backlog-triage.md) | one retarget, to the types reference |
| [`workflow/coding-agent/prompts/wrapup.md`](../../workflow/coding-agent/prompts/wrapup.md) | three retargets |
| [`workflow/coding-agent/prompts/record-correction.md`](../../workflow/coding-agent/prompts/record-correction.md) | one retarget, its fold rule citation |
| [`docs/policies/iteration_policy.md`](../../docs/policies/iteration_policy.md) | two retargets |
| [`.agents/drafts/review-pass-run.md`](../../.agents/drafts/review-pass-run.md) | two retargets |
| [`.agents/drafts/test-quality-campaign-run.md`](../../.agents/drafts/test-quality-campaign-run.md) | one retarget |
| [`workflow/coding-agent/skills/eval/evals/commit-body-budget.json`](../../workflow/coding-agent/skills/eval/evals/commit-body-budget.json) | the subject, the configuration variable and both cases name the skill |
| [`workflow/coding-agent/skills/eval/scripts/run_case.sh`](../../workflow/coding-agent/skills/eval/scripts/run_case.sh) | the candidate contract and the copy target move to the skill path |
| [`tests/test_eval_harness.sh`](../../tests/test_eval_harness.sh) | the fixtures write and copy the skill |
| [`devlog/roadmap.md`](../roadmap.md) | the commit-runbook row filed |
