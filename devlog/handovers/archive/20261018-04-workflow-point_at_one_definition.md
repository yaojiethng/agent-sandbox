---
date: 2026-10-18
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - Point every numbering instruction at one definition

## Objective

Remove the three restatements of the numbering rule and the last residual copies, so the convention is the only definition and a later change reaches every reader.

## Scope

Four surfaces stated the rule: the convention, `docs/policies/documentation_policy.md` `### Numbered vs bulleted presentation`, `AGENTS.md`'s *Context-aware numbering*, and the provider `AGENTS.md`'s *Numbering* bullet. None named the convention. This iteration reduces each to a pointer, renames the policy heading to what it now holds, and puts the feedback entry that motivated the chat rule on probation.

Checked and kept: `AGENTS.md` *Output Format* points at policy `## Communication Standards`, which holds `### Rule placement`, `### Simplified Technical English` and `### Reserved terminology`. That is one hop to substantive rules, not a hop to a pointer.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The policy section states no rule the convention carries | a pointer, plus the heading rule the convention does not carry | Accepted |
| The project `AGENTS.md` points at the convention | *Context-aware numbering* | Accepted |
| The provider `AGENTS.md` defers without naming a project path | the repo source and the installed copy are identical | Accepted |
| The provider bullet states no second rule | one clause, no instruction about axes | Accepted |
| The feedback entry names a section that exists | `## Chat: one token per item` in the convention | Accepted |
| The feedback entry is on probation | `state: probation`, with the observation named | Accepted |
| The census is reclassified and clean | `check_norm_ownership.sh --check`, 167 rows, 41 model, 82 judgement | Accepted |
| The gates and the suite are green | `bash scripts/lint.sh` 10 gates; `bash scripts/run_tests.sh`, 1227 of 1227 | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The convention owns the rule | The canonical owner test in `doc-maintenance` asks which document an agent reads when it needs the rule. A writer needs the skill, not the policy. | `doc-maintenance` `## The diagnostic register`; this record |
| The policy keeps the heading rule and nothing else | Moving an often-cited item into a heading is structure, not numbering, and the convention does not state it. | the policy section |
| The policy heading becomes `### Numbering` | No live document linked to the old anchor, and the section no longer promises a scheme. | the policy section |
| The provider layer keeps a one-clause fallback | That file ships to every project and cannot assume a project convention exists. A path it named would break in a project without one. | the provider `AGENTS.md` bullet |
| The two new policy lines are classified `model` and `judgement` | The pointer is model instruction; the heading rule is a writer's judgement. Neither has an observer that could detect a breach. | `norm-ownership.tsv` |
| The feedback entry moves to `probation` on operator direction | The fix landed and the entry is the case the convention now prevents. Under `iteration_policy.md` the next decision is dismiss, maintain or escalate, and that decision is the operator's. | `AGENT_FEEDBACK.md`; `iteration_policy.md` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Does the feedback record gain a close convention? | whether a resolved entry can leave the open set | the roadmap row already filed; leave it there |
| Does `AGENTS.md` *Output Format* keep its Communication Standards paragraph? | one home for the output-format rule set | keep, as today; fold into the policy pointer |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Four surfaces stated the numbering rule and none named the convention that defines it. | diagnosis | The rule had no owner, which is why a change to it could not reach the reader. |
| The provider `AGENTS.md` cannot point at `.agents/skills/`, because it ships to projects that have no such directory. | constraint | The provider layer keeps a generic clause and defers; the project layer carries the pointer. |
| The feedback entry pointed at `documentation_policy.md` `### References`, a heading that has never existed. | diagnosis | A pointer nobody follows rots silently, and the rule it named had already moved. |
| The census gate refused the edited policy lines until each was classified. | evidence | The mechanism works: an edited rule cannot land without a reader deciding what kind of statement it is. |
| `AGENTS.md` *Output Format* points at substantive policy content, not at a pointer. | evidence | Kept. A second hop is noise; one hop to a rule set is navigation. |

## Completed

| File | Change |
|---|---|
| [`documentation_policy.md`](../../../docs/policies/documentation_policy.md) | the section reduces to a pointer and the heading rule, and is renamed `### Numbering` |
| [`AGENTS.md`](../../../AGENTS.md) | *Context-aware numbering* points at the convention |
| [`AGENTS.md` (provider)](../../../src/reasoning/providers/pi/config/agent/AGENTS.md) | the bullet defers to a project convention in one clause; the installed copy is identical |
| [`norm-ownership.tsv`](../../../scripts/lint/norm-ownership.tsv) | regenerated and classified, 167 rows |
| [`AGENT_FEEDBACK.md`](../../AGENT_FEEDBACK.md) | the mitigation points at the convention and keeps the incident; the stale scope reference is repaired; the state is `probation` |
