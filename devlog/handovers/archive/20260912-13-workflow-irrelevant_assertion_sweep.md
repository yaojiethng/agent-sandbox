# Agent Handover

**Date:** 2026-09-12
**Milestone:** M2.6 - Session Persistence (general-track hygiene)
**Type:** Workflow
**Status:** Closed

## Objective

Remove procedure-trigger assertions that are irrelevant to both the precondition and the outcome of the procedure they gate, and rename the roadmap-maintenance procedure to a self-describing name so agents invoke the defined procedure instead of improvising.

## Scope

- `src/reasoning/agent/prompts/new-iteration.md` -- the false-cause recovery clause.
- `docs/operations/handover_policy.md` -- the Open-state recovery presumption.
- The "post-close bookkeeping" to "roadmap maintenance" rename across all policy, prompt, and audit files that reference it.
- The "Recovery check" label on the plain roadmap-state check.

## Carried forward

| Item | From handover |
|---|---|
| None. | |

## Acceptance criteria

1. `new-iteration.md` no longer asserts "the prior iteration's close sequence did not complete".
2. `handover_policy.md` Open-state says continue the existing session, propose recovery only when there is reason to suspect progress was lost.
3. All "post-close bookkeeping" references renamed to "roadmap maintenance", consistent across policy, prompt, and audit files, with links resolving to the renamed anchor.
4. The plain roadmap-state check is no longer named "Recovery check".
5. No stale "bookkeeping" or "recovery check" reference remains in the sweep scope.

## Hot files

| File | Why in scope |
|---|---|
| [`src/reasoning/agent/prompts/new-iteration.md`](../../src/reasoning/agent/prompts/new-iteration.md) | false-cause clause removed; heading renamed to "Roadmap maintenance check" |
| [`docs/operations/handover_policy.md`](../../docs/operations/handover_policy.md) | Open-state recovery presumption corrected |
| [`docs/operations/roadmap_policy.md`](../../docs/operations/roadmap_policy.md) | canonical "Post-close Bookkeeping" section renamed "Roadmap maintenance" |
| [`docs/operations/iteration_policy.md`](../../docs/operations/iteration_policy.md) | rename + "Recovery check" label dropped |
| [`docs/concepts/agent_workflow.md`](../../docs/concepts/agent_workflow.md) | rename |
| [`docs/operations/milestone_policy.md`](../../docs/operations/milestone_policy.md) | rename |
| [`src/reasoning/agent/prompts/wrapup.md`](../../src/reasoning/agent/prompts/wrapup.md) | rename |
| [`workflow/coding-agent/audits/audit.skill.md`](../../workflow/coding-agent/audits/audit.skill.md) | "Step 1 recovery check" renamed |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Drop the false-cause clause "the prior iteration's close sequence did not complete" from the roadmap maintenance check | states a cause that is false for the M2.6.6 case (each prior close completed; the compaction trigger was mis-scoped) and irrelevant to both the precondition and the outcome | new-iteration.md |
| Open-state: continue the existing session when the prior handover is not Closed; propose recovery only with reason to suspect progress was lost | "not Closed" most often means the session is genuinely in progress; recovery presumes corruption and must not be the default | handover_policy.md |
| Rename "post-close bookkeeping" to "roadmap maintenance" | the old name stated timing, not action; an opaque name invites the agent to improvise instead of running the defined procedure. "Roadmap maintenance" conveys continuous upkeep without asserting the roadmap is deviant | roadmap_policy.md; operator nomination |
| Drop the "Recovery" label from the plain roadmap-state check | "recovery" stays reserved for the lost-progress protocol; the roadmap check is plain maintenance | iteration_policy.md, new-iteration.md, audit.skill.md |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The "post-close bookkeeping" name stated when the procedure runs, not what it does; an agent must read roadmap_policy to act, inviting improvisation. | design | current iteration |
| "Recovery check" and "Recovery checks" named the plain roadmap-state check, overloading "recovery" from the lost-progress protocol. | design | current iteration |

## Completed

| File | Change |
|---|---|
| `src/reasoning/agent/prompts/new-iteration.md` | removed the false-cause close clause; renamed heading to "Roadmap maintenance check"; frontmatter updated |
| `docs/operations/handover_policy.md` | Open-state rewrites to continue the session; recovery only with reason to suspect loss; 3 references renamed |
| `docs/operations/roadmap_policy.md` | "Post-close Bookkeeping" section renamed "Roadmap maintenance" with all mentions and anchor |
| `docs/operations/iteration_policy.md` | 7 references renamed to "roadmap maintenance"; "Recovery check" label dropped; anchors updated |
| `docs/operations/milestone_policy.md` | reference renamed |
| `docs/concepts/agent_workflow.md` | 2 references renamed |
| `src/reasoning/agent/prompts/wrapup.md` | 2 references renamed |
| `workflow/coding-agent/audits/audit.skill.md` | "Step 1 recovery check" renamed |

## Deferred items

None.

## What's Next

M2.6 - Session Persistence (general-track hygiene).

Roadmap maintenance: not applicable this iteration (mid-milestone; no submilestone closed).

Blocking design questions the next agent must resolve before advancing:

- None.

**Conclusions from this iteration:** procedure triggers in this repo carried two kinds of irrelevant assertion -- a false cause attribution (bookkeeping recovery) and a name describing timing instead of action (post-close bookkeeping). Both are resolved by stating the procedure's actual condition and action.
