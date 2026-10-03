# Agent Handover

**Date:** 2026-09-29
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Workflow
**Status:** Closed

## Objective

Audit `roadmap_policy.md` and `iteration_policy.md` now that the full workflow has moved to `/iter`. Test whether the residual step-count enumeration (Step 1 through Steps 8-9) is too procedural, leads to redundancy, and grows the maintenance surface area. Land the scope-gate framing (restate the goal and the problem in the agent's own words, close to the grill-me preamble) in `/iter` or generally across scope gates.

## Scope

Audit `roadmap_policy.md` and `iteration_policy.md` after the workflow moved to `/iter`. Test whether the residual step-count enumeration is too procedural, duplicates `/iter`, and inflates the maintenance surface. Land the invariant-first restructure (durable state-at-commit invariants in policy; loose judgment-heavy procedure gated behind the runbook, which evolves; canonical deterministic procedures may stay as guaranteed code-blocks). Land the scope-gate framing (restate the operator's goal and problem in the agent's own words, close to the grill-me preamble) in `/iter` and in the policy's scope-gate invariant.

**Design confirmed at the scope gate (operator, 2026-09-29):** the decoupling principle -- the invariant layer should be *insensitive* to runbook evolution, not frozen by a "must not edit" rule. A runbook change should never *require* an invariant edit; improving the invariant set autonomously is healthy evolution, and an edit forced by a runbook rename/renumber signals coupling. The guard is a review-time coupling check (did a procedural diff drag the invariant layer along), not a keyword lint (the operator correctly rejected a naive lint as silly).

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Drop the step-mirror headings from the policies | the procedure lives in `/iter`; a numbered step scaffold is a second place that must stay in lockstep and costs maintenance surface | `iteration_policy.md` `## Minor Loop -- Invariants` |
| Keep canonical procedures (e.g. squash-to-one-commit) | a deterministic code-block guaranteed to satisfy an invariant may stay in policy | `iteration_policy.md` canonical procedures |
| Guard is a review-time coupling check, not a lint | a keyword lint would police vocabulary we maintain forever, not semantics; coupling is a judgment the review subagents make | this handover, operator 2026-09-29 |
| Scope gate restates intent | makes the gate a confirmation of understood intent, not a re-showing | `iter.md` scope gate, `iteration_policy.md` scope-gate invariant |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | `iteration_policy.md` is organized by invariant, not by `Step N --` procedure mirror | read `iteration_policy.md` | Met |
| 2 | The decoupling principle is stated (invariant layer insensitive to runbook evolution, not frozen) | read `iteration_policy.md` decoupling principle | Met |
| 3 | Loose procedure is referenced to `/iter`, not restated, and canonical procedures remain as code-blocks | read `iteration_policy.md` | Met |
| 4 | The scope gate restates the operator's goal and problem in the agent's own words | read `iter.md` scope gate + `iteration_policy.md` | Met |
| 5 | No broken `iteration_policy` anchors or step-number scaffolding survive repo-wide | grep sweep | Met |
| 6 | `roadmap_policy.md` step references restated as state-at-commit | read `roadmap_policy.md` | Met |
| 7 | glm advisor review passes | glm advisor dispatch | Met |

## Completed

| File | Change |
|---|---|
| `docs/operations/iteration_policy.md` | rewritten to the invariant core (unit/scope, gates, AC, record-state, close, canonical procedures, decoupling principle) |
| `docs/operations/roadmap_policy.md` | step-number headings removed; references restated |
| `docs/operations/handover_policy.md` | step anchors corrected to the invariants section |
| `docs/concepts/agent_workflow.md` | Steps 8-9 -> close review/publish |
| `docs/operations/discussion_policy.md` | Step 3 -> design phase |
| `AGENTS.md` | Step 1 -> open-handover; Step-7 anchor -> invariants |
| `workflow/coding-agent/prompts/iter.md` | scope-gate restate-intent added; anchor -> invariants |
| `workflow/coding-agent/prompts/wrapup.md` | Step 1 -> required before output |
| `workflow/coding-agent/audits/audit.skill.md` | Step 1 -> iteration-start |
| `src/reasoning/agent/drafts/roadmap-management.skill.md` | Steps 8-9 -> close |
| `tests/eval/eval_protocol.md` | invariants updated to the invariant-first model |

**glm advisor review (glm-5.3-flash, high, 2026-09-29):** the operator directed a glm advisor run on completion. It found 18 defects: decoupling violations (canonical-procedure purity, runbook restating invariants verbatim, scope-gate coaching/idiom, wrapped sub-milestone procedure), STE100/one-term issues (runbook vs prompt, canonical-rules vs canonical-procedure, release vs close gate, idioms), and stale pointers/anchors. All 18 fixed across two passes; the final re-review verdict is CONVERGED (log `/tmp/policy-advisor.refix2.log`).

## Findings

| Finding | Type | Impact |
|---|---|---|
| **Review prompts need an optional convergence constraint and an invocation budget** (operator, 2026-09-29): advisor-style prompts currently mandate "work to consensus" (a hard convergence loop), but a review should be invokable as a single pass too without being forced to converge. Thermo-nuclear-style prompts should be invokable with or without the convergence constraint -- it is a mode, not a baked-in property. In all cases review prompts should echo a subagent invocation budget (how many subagent runs the loop may use), so cost is bounded and visible. | steering | Rides `prompt-authoring-conventions.md` (authoring rules) and the review prompts (`advisor.md`, `thermo-nuclear-code-quality-review`); recorded as an `[O]` feedback entry |

## Deferred items

_(filled at close)_

## What's Next

_(filled at close)_
