---
date: 2026-10-22
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - Retire the discussion policy

## Objective

Move the discussion record's convention into the `work-log` skill and its remaining citations to the home that states them, then delete `docs/policies/discussion_policy.md`.

## Scope

`M3.3.2 - Retire the policy form`, slice `Retire discussion_policy`, one unit. It continues the settled chain recorded in [`20261014-design-settled-retire_the_policy_form.md`](../discussions/20261014-design-settled-retire_the_policy_form.md) and follows `Retire adr_policy` (handover `20261022-07`).

The settled row sends the four document types and their section orders to `document` as mechanism. That is the same straddle the previous slice resolved: `document` forbids being a rule's source of truth, and a section order describes the record rather than the session. So the orders land in `work-log` as assets, `document` takes the retarget, and `iteration_policy` rows 3-5 name the record home for the record and keep the operation with the prompts that run it. Recorded under Decisions.

The report type's ten-section order is not followed by any report on disk. Ruling on it was presented at the scope gate and is recorded under Decisions.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The policy file is deleted | `test ! -e docs/policies/discussion_policy.md` | Agent [x] |
| No live surface outside `devlog/` names it | `grep -rln 'discussion_policy' docs scripts src workflow .agents AGENTS.md` prints nothing | Agent [x] |
| The skill states the naming format, the four type codes, the status vocabulary and the two carve-outs | `grep -n '^### Naming\|^## The exploration record'` and the four type rows | Agent [x] |
| Three assets exist, for the three types with a shape, each indexed from the skill | `test -s` the three; three index rows | Agent [x] |
| The report type states its three binding rules and has no template | `grep -c 'A report has no fixed section order'` returns 1, and `test ! -e .agents/skills/work-log/assets/report.md` | Agent [x] |
| `document` retargets its record check to the skill | `grep -c 'discussion_policy' workflow/coding-agent/prompts/document.md` returns 0; the skill is named | Agent [x] |
| `iteration_policy` rows 3-5 name the record home | `grep -c 'work-log' docs/policies/iteration_policy.md` rises by three | Agent [x] |
| `bootstrap.md` no longer lists the file | `grep -c 'discussion_policy' workflow/coding-agent/prompts/bootstrap.md` returns 0 | Agent [x] |
| The work-log skill's two pointers retarget | `grep -c 'discussion_policy' .agents/skills/work-log/SKILL.md` returns 0 | Agent [x] |
| The norm ledger is consistent | `bash scripts/check_norm_ownership.sh --check` | Agent [x] |
| Lint, the suite and the handover gate are clean | `bash scripts/lint.sh`, `bash scripts/run_tests.sh`, `bash scripts/check_handover_format.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The four section orders land in `work-log` assets rather than in `document` | `document` forbids being a rule's source of truth, and a section order describes the record. The design record permits a straddling section to be resolved in the slice that moves it | this record |
| `iteration_policy` rows 3-5 name `work-log` for the record and leave the operation with `iter` and `plan` | The operation already lives in the prompts that run it; only the record's home moved | this record |
| `document` Step 6 keeps the record checks it states and drops the policy pointer | Those checks are the live test of a discussion or design record; only the authority line moved | this record |
| The report type takes option (c): the three binding rules, and no template | No report on disk follows the ten-section order, and three rules are a judgement rather than a form, so the type earns no asset | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The report template's ten-section order is followed by no report: `Compact log of actions`, `Mid-run adjustments`, `Resolution methods`, `Post-review learnings`, `Resolution status` and `Records this supersedes` appear in none of the five | defect | the template states a standard nothing meets, so a session writing a report either invents its own order or fabricates six empty sections | fixed in this unit: the template is dropped for the three binding rules |
| No `story` record exists among the 25 on disk, though the type is the iteration's opening record | gap | the story template is unexercised, so it moves on its text alone and nothing confirms its sections are the ones a story needs | carried in this record |
| `iteration_policy` routes three iteration steps to the policy for the operation, not only for the record's shape | defect | with the file gone those rows must name an operating prompt as well as the record home, or the step points nowhere | fixed in this unit |

## Completed

| File | Change |
|---|---|
| `docs/policies/discussion_policy.md` | deleted |
| [`.agents/skills/work-log/SKILL.md`](../../.agents/skills/work-log/SKILL.md) | the exploration record's convention: the filename, the statuses, the four types, the closure rules |
| [`.agents/skills/work-log/assets/story.md`](../../.agents/skills/work-log/assets/story.md) | new, the story's section order |
| [`.agents/skills/work-log/assets/study.md`](../../.agents/skills/work-log/assets/study.md) | new, the study's section order |
| [`.agents/skills/work-log/assets/design.md`](../../.agents/skills/work-log/assets/design.md) | new, the design's section order |
| [`workflow/coding-agent/prompts/document.md`](../../workflow/coding-agent/prompts/document.md) | Step 6's record check retargets |
| [`workflow/coding-agent/prompts/iter.md`](../../workflow/coding-agent/prompts/iter.md) | the design pointer retargets |
| [`workflow/coding-agent/prompts/bootstrap.md`](../../workflow/coding-agent/prompts/bootstrap.md) | the policy set loses the file, two lists |
| [`docs/policies/iteration_policy.md`](../../docs/policies/iteration_policy.md) | rows 3-5 name the record's home |
| [`docs/reference/agent_workflow.md`](../../docs/reference/agent_workflow.md) | the record-type row retargets |
| [`docs/reference/documentation_taxonomy.md`](../../docs/reference/documentation_taxonomy.md) | the discussion row's governing cell retargets |
| [`AGENTS.md`](../../AGENTS.md) | two rows merge into the work-log row |
| [`.agents/drafts/task-list-mechanism-rewrite-run.md`](../../.agents/drafts/task-list-mechanism-rewrite-run.md) | the design-order pointer retargets |
| [`devlog/roadmap.md`](../roadmap.md) | the slice closed, the parent row text updated |
