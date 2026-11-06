---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# The check-placement principle

## Objective

Place a check where its input first exists and where its decision is cheapest to take, stated once as a judgement. A skill that holds checks points at it.

## Scope

**In scope.** A new principle skill at `src/reasoning/providers/pi/config/agent/skills/principle-check-placement/SKILL.md` and its installed copy. Two pointers that dispatch it, in `$AGENT_HOME/agent/skills/skill-scaffolder/SKILL.md` and `docs/development/prompt-authoring-conventions.md`, with the norm ledger kept in step.

**Out of scope.** The completeness ledger that would have bound each check to a record and a gate. It was dropped on operator direction as a second surface beside the judgement. The gate redesign that led here stays with `20261020-02`.

## Acceptance criteria

| # | Criterion | Class | Result |
|---|---|---|---|
| AC1 | The skill exists in the repository config tree and the installed tree, and the two copies are byte-identical | Agent | Agent [x] |
| AC2 | The skill carries `disable-model-invocation: true`, and stays out of the always-loaded list while an unflagged sibling stays in it | Agent | Agent [x] |
| AC3 | `prompt-authoring-conventions.md` names the skill, and the norm ledger carries the new line classified | Agent | Agent [x] |
| AC4 | `skill-scaffolder` points at the skill from the step that drafts a skill's content | Agent | Agent [x] |
| AC5 | `scripts/lint.sh`, `scripts/check_frontmatter.sh`, `scripts/check_norm_ownership.sh --check` and `scripts/run_tests.sh` all pass | Agent | Agent [x] |
| AC6 | Every Stop rule states the permitted form, and the skill names no path its own reader cannot resolve | Agent | Agent [x] |

## Decisions

| Decision | Rationale | Recorded in |
|---|---|---|
| The placement is a judgement, stated in one skill | A rule with an observer belongs with its observer, so only what no observer can check stays in a principle | `devlog/roadmap.md`, this record |
| No completeness ledger | It stands beside the rule it would guard, and the operator ruled it a second surface | this record |
| The skill carries `disable-model-invocation: true` | It costs no always-loaded line, and the two pointers carry the discovery instead | this record |
| Cross-links go only to repository-shipped siblings | The tree ships three of twenty-five principle skills, and a link to an unshipped target fails the `record-links` lint | this record |
| The new skill lands in both trees | It is repository content, unlike the plugin-installed principles, which have no repository mirror | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The norm ledger has no observer vocabulary for a pi config skill. `review:` resolves only under `workflow/coding-agent/skills/` and `.agents/skills/`, so the pointer line is classified `model` with observer `none` | record defect, pre-existing | the ledger cannot record that a principle reviews a norm | roadmap row `The norm ledger names a principle skill as an observer` |
| `skill-scaffolder` exists only in the installed tree, so one of the two pointers appears in no repository diff | pre-existing | a repository reader never meets that pointer | this record's Decisions, because the plugin owns the file and no repository change can carry it |

## Completed

| Artifact | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/principle-check-placement/SKILL.md` | new, the judgement stated once |
| `$AGENT_HOME/agent/skills/principle-check-placement/SKILL.md` | byte-identical installed copy |
| `$AGENT_HOME/agent/skills/skill-scaffolder/SKILL.md` | step 4 points at the skill |
| `docs/development/prompt-authoring-conventions.md` | one paragraph in `## Runbook versus advisor versus skill` |
| `scripts/lint/norm-ownership.tsv` | the new line classified `model`, observer `none` |
| `devlog/roadmap.md` | one open row filed under M3.3.4 for the ledger finding |
