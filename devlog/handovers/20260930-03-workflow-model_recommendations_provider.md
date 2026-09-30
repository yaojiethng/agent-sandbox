# Agent Handover

**Date:** 2026-09-30
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Workflow
**Status:** Closed

## Objective

Fix the provider-omission follow-on on the single-source model-recommendations row: the role-to-model table in the project `AGENTS.md` names a model and a thinking level but no provider, and providers disagree on capability so the same model can silently resolve to a variant that fails dispatch. Also record the open item as an unchecked sub-item under the landed row, and record the finding that `roadmap_policy.md` is not prescriptive enough about how work items (follow-ons, sub-items) are recorded.

## Scope

- `AGENTS.md` (project) - the Model Recommendations role table gains the provider embedded in each model token (`opencode/space-bunny-free`, `opencode-go/deepseek-v4-flash`, `opencode-go/glm-5.3-flash`).
- `src/reasoning/providers/pi/config/agent/AGENTS.md` (provider-level) - states that recommendations are defined at project level; as a fallback, shows how to find the pi default by parsing `settings.json` with `jq`, and tells the agent to confirm with the operator that it is the model to use.
- The four prompts that read the table (`auto.md`, `review-pass-run.md`, `parallel-auto.md`, `advisor.md`) - phrase changes to "read the provider, model, and thinking level"; the `<provider>` literal stays but is now answered from the table.
- `docs/adr/single_source_model_recommendations.md` - add the provider dimension.
- `devlog/roadmap.md` - convert the follow-on to an unchecked sub-item and check it `[x]`; record the `roadmap_policy` recording finding.

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Embed the provider in each model token (not a separate column) | matches the invocation form `--provider X --model Y` and recorded usage; keeps the table one-column-meaning; the `_ADVISOR` routing clause stays intact | this handover + scope gate |
| Provider-level AGENTS.md states the resolution order: project-defined AGENTS.md -> pi/provider default via `jq` parse of settings + confirm with operator -> current chat's model | recommendations are project-scoped (R2); the fallback answers the follow-on's "resolve by rule" half | this handover + operator steer 2026-09-30 |
| The current-chat fallback also requires explicit operator confirmation, like the default-model rung | a fallback that guesses silently reproduces the failure it exists to avoid; confirmation is mandatory at both fallback rungs | this handover + operator steer 2026-09-30 |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | The project `AGENTS.md` role table carries the provider in every recommendation token | `grep -n` for `opencode/` and `opencode-go/` | Accepted at scope gate (to confirm) |
| 2 | The provider-level `AGENTS.md` states project-level recommendations, the `jq` fallback to the pi default, operator confirmation, then the current chat's model | `grep -n` the provider-level AGENTS.md | Accepted at scope gate (to confirm) |
| 3 | The four prompts read "provider, model, and thinking level" and name the provider source for `<provider>` | `grep -n` each prompt | Accepted at scope gate (to confirm) |
| 4 | The ADR records the provider dimension | `grep -n` the ADR | Accepted at scope gate (to confirm) |
| 5 | The follow-on is an unchecked sub-item, then `[x]` with a land note; the `roadmap_policy` recording finding is recorded | `grep -n` the roadmap rows | Accepted at scope gate (to confirm) |
| 6 | No node/queue code changed; doc surfaces only | `git status` | Accepted at scope gate (to confirm) |

## Completed

| File | Change | Status |
|---|---|---|
| `AGENTS.md` | role table gains the provider embedded in each token; the definition sentence says each role tag names provider + model + thinking level | done |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | "Running Review Subagents" states the three-rung resolution order (project table, pi default + operator confirmation, current chat's model + operator confirmation) | done |
| `workflow/coding-agent/prompts/auto.md` | reads "provider, model and thinking level" from `_IMPLEMENTER` | done |
| `workflow/coding-agent/prompts/review-pass-run.md` | reads "provider, model and thinking level" from `_REVIEWER` | done |
| `workflow/coding-agent/prompts/parallel-auto.md` | worker tracks read "provider, model and thinking level" from `_IMPLEMENTER` | done |
| `src/reasoning/agent/prompts/advisor.md` | reads "provider, model and thinking level" from `_ADVISOR` | done |
| `src/reasoning/agent/skills/thermo-nuclear-code-quality-review/SKILL.md` | reads "provider, model and thinking level" from `_REVIEWER` | done |
| `docs/adr/single_source_model_recommendations.md` | R7 (provider travels) + decision/rationale/rejected-alternative record the provider | done |
| `devlog/roadmap.md` | follow-on converted to an unchecked sub-item, then `[x]` with land note; `roadmap_policy` recording finding filed as a T1 row | done |
| `devlog/handovers/20260930-03...md` | handover: scope, decisions, AC, completed | done |

## Deferred items

_(filled at close)_

## What's Next

The `roadmap_policy` recording-gap finding is the next relevant item: `roadmap_policy.md` does not prescribe how an open follow-on or sub-item is recorded (a closed row can carry an open task as free prose with a dangling pointer). The fix direction is a filing rule: an open follow-on to a landed row becomes an unchecked nested sub-item, and a closed row does not carry an open task as free prose. Filed as the open T1 row; the deferred-items rule gives it priority for the next scope.
