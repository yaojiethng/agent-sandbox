# Agent Handover

**Date:** 2026-09-26
**Milestone:** M3.1 - Backpressure
**Type:** Workflow
**Status:** Closed

## Objective

Amend the `grill-me` skill to open with a problem summary: grounding context around the problem being grilled. The summary has three parts: the problem we encountered, how we are sure it is a problem (the evidence), and the kind of solution we are trying to achieve. The interview then tests the plan against that summary. Operator direction (2026-09-26). No roadmap row - the T1 workflow tracks have no row for the grill-me prompt surface.

## Scope

`src/reasoning/agent/skills/grill-me/SKILL.md` only. The `/opt/workflow/agent/skills/` copy is baked from this file at provider image build time (`provider.dockerfile`) and is not a deliverable. No code change, no test change: the skill tests pin the deployment mechanism, not skill content.

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| The skill names the problem summary step before the interview step | read of the skill file | Agent [x] |
| The summary has the three parts: the problem encountered, the evidence it is a problem, the kind of solution aimed for | read of the skill file | Agent [x] |
| A missing or vague part is asked for before the interview starts | read of the skill file | Agent [x] |
| Every interview branch is tested against the problem summary; a branch that does not serve the stated problem is resolved or dropped | read of the skill file | Agent [x] |
| The existing rules survive: one question at a time, a recommended answer for each question, explore the codebase when a question can be answered there | read of the skill file | Agent [x] |
| Lint clean, suite green | `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | Agent [x] - 3 gates clean, 990 tests 0 failed |
| Roadmap write-back | `devlog/roadmap.md` | none - operator-directed prompt-surface work with no roadmap row |

## Hot files

| File | Why in scope |
|---|---|
| [`src/reasoning/agent/skills/grill-me/SKILL.md`](../../src/reasoning/agent/skills/grill-me/SKILL.md) | the skill body; the canonical source the provider image bakes into `/opt/workflow/agent/skills/` |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The problem summary is an opening step, not a mandatory pre-questionnaire | the skill grills a stated plan; the three parts ground the interview when the plan drifts from the problem. The step asks only for what is missing. | this handover |
| The interview tests each branch against the summary | grounding is worthless if the questions do not use it; a branch that does not serve the stated problem is the first drift to resolve. | this handover |
| Existing terse style kept; frontmatter untouched | the sibling skills carry headers but stay short; the description surface is deployment-contract (pi reads `name`/`description`). | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| none | | |

## Completed

| File | Change |
|---|---|
| `src/reasoning/agent/skills/grill-me/SKILL.md` | new `## Problem summary first` step (three parts: problem, evidence, solution kind; ask for what is missing before the interview); the interview now tests every branch against the summary; the one-question-at-a-time rule kept once, under Interview |

## Deferred items

| Item | Reason |
|---|---|
| `/opt/workflow/agent/skills/` copy refresh | the deployed copy updates at the next provider image rebuild; outside the repo and not editable in this iteration |
