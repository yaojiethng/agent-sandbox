---
date: 2026-11-05
milestone: M3.5.4 - The git and change model
type: Workflow
status: Closed
---

# Handover - The commit prompt and the iteration rule

## Objective

Remove the bare `unit` from the commit prompt and the iteration rule it cites, so the work cycle is the iteration and the landed change is the delivery commit, and the prompt family names the same carriers.

## Scope

`workflow/coding-agent/prompts/commit.md`, `docs/reference/iteration_protocol.md`, and the prompts that cite the rule or the work table: `iter.md`, `scope.md`, `wrapup.md`, `plan.md`, `milestone-close.md`, `backlog-triage.md`. The git references the commit prompt points at: `branching.md`, `recovery.md`, `correction.md`. The records the rule names: `work-log/SKILL.md`, `task-list/SKILL.md`.

Out of scope, with reasons: the rest of the shipped instruction text, carried by the roadmap's bare-`unit` row: the statechart, the test harness, the numbering skill, and the workflow skills; their senses differ (a test case, a numbered entry), so each needs its own reading rather than a rename.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The commit prompt carries no bare `unit` | `grep -niE '\bunit' workflow/coding-agent/prompts/commit.md` is empty | Agent [x] |
| The iteration rule names the delivery commit | `iteration_protocol.md`'s Iteration and scope invariants | Agent [x] |
| The prompt family cites the iteration rule and the work table | `iter.md`, `scope.md`, `wrapup.md`, `plan.md`, `milestone-close.md`, `backlog-triage.md` | Agent [x] |
| The git references name the delivery branch and the iteration | `branching.md`, `recovery.md`, `correction.md` | Agent [x] |
| The gates are clean | `scripts/lint.sh`, `scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The work cycle is the iteration, the landed change is the delivery commit | the commit history is the linear record; the iteration is the cycle, the delivery commit is what the trunk accepts, the handover is the record | `terminology.md`'s usage rule |
| The rule becomes the iteration rule | the old name carried the bag word; the rule's content is one roadmap task, one vertical slice, one delivery commit, one handover | `iteration_protocol.md` |
| The scope proposal carries a work table, one row per iteration | "work-unit table" named the bag; the row is the iteration | `iteration_protocol.md` |
| The sweep is sliced at the commit and iteration prompts | these are the rule and its readers; the other surfaces have different senses and need their own reading | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The commit prompt and the iteration rule carried 21 bare uses between them | defect | the rule and its runbook disagreed on the carrier | fixed |
| The prompt family's "unit rule" and "work-unit table" named a rule that no longer exists | defect | a reader follows a rename half-way | fixed: the iteration rule and the work table |
| The git references still called the branch a "unit branch" | defect | the branch tree's leaf had the bag name | fixed: the delivery branch |
| The commit prompt's "one commit per unit" was circular once the unit was the commit | defect | the rule could not be restated with its own term | fixed: one delivery commit per iteration |
| The remaining shipped text still uses the bare word | gap | the mandate is rule-only until the sweep and the lint land | carried: the roadmap row |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/commit.md` | the iteration and the delivery commit throughout |
| `docs/reference/iteration_protocol.md` | the iteration rule and the work table |
| `workflow/coding-agent/prompts/iter.md` | the iteration rule; the work table |
| `workflow/coding-agent/prompts/scope.md` | the work rows, one per iteration |
| `workflow/coding-agent/prompts/wrapup.md` | the iteration's close and work table |
| `workflow/coding-agent/prompts/plan.md` | the decomposition into iterations |
| `workflow/coding-agent/prompts/milestone-close.md` | an iteration of the workflow's execution |
| `workflow/coding-agent/prompts/backlog-triage.md` | the iteration rule |
| `.agents/skills/git-discipline/references/branching.md` | the delivery branch |
| `.agents/skills/git-discipline/references/recovery.md` | the iteration's state |
| `.agents/skills/git-discipline/references/correction.md` | the iteration's state; a commit is not reviewable |
| `.agents/skills/work-log/SKILL.md` | the handover record |
| `.agents/skills/task-list/SKILL.md` | a step of a workflow's ordered execution |
| `devlog/roadmap.md` | the bare-`unit` row names the remaining surfaces |
| `devlog/handovers/M3.5.4/20261105-28-workflow-iteration_usage.md` | this record |

[AMENDMENT -- 2026-11-06: the "Next session" section is removed; its items are held by the roadmap.]
