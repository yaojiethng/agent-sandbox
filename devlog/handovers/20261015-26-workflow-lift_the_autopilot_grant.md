---
date: 2026-10-15
milestone: M3.2.3 - Dispatch Workflows as a Command Surface
type: Workflow
status: Closed
---

# Handover - Lift the autopilot grant on a divergence

## Objective

Stop a standing autonomy grant from surviving a fork or a tree. The agent has no view into pi's `/fork` and `/tree` operations, so the two prompts that wrap those operations are the hook. A push or a pop invalidates any grant, and a recorded flag is deliberately not used.

## Scope

The two prompts, repository and installed.

Out of scope: any state tracking of the grant.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A push lifts the grant | `push-task.md` states "If you have an autopilot grant, consider it invalidated." | Accepted |
| A pop lifts the grant | `pop-task.md` states the same | Accepted |
| The lapse is recorded as a recurrence | the third occurrence in the `[O] 2026-09-25` entry | Accepted |
| No state is tracked | the tracker carries no autopilot section; there is nothing to go stale | Accepted |
| Repo and installed copies match | `diff`, identical | Accepted |
| Gates clean | `bash scripts/lint.sh` clean across 8 gates | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The rule lives in the prompts, and no flag is recorded | the agent cannot see the fork or the tree, so the prompt is the only hook; a flag would be session state that can go stale, and a reminder cannot | the prompts |
| Both a push and a pop lift it | any divergence boundary invalidates the grant, so a divergence and the return after it both run with autonomy off | the prompts |
| The state is opt-in after a divergence | autonomy belongs to the main line the operator is watching, not to a divergence | the prompt text |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The grant that caused the runaway was never lifted because it was never written down. It lived only in the conversation, so no return could see it and no mechanism could expire it. The same class as the steering gap. | root cause, recorded | the prompt fix |
| The tree advanced during this turn: the session-memory skill and tool landed (`c7836f91`) and the prompts were rewired to it (`4ffcb310`). The lift edits apply on top of that wiring. | environment | the prompt edits |
| The movement was linear work plus an amend of the steering commit. The amend was at the operator's direction, and the operator reports a likely missed pop, an operator error. Git cannot show a missed push or pop, because a `/tree` moves inside one session file and a `/fork` creates a new one, so neither appears in the repository; the tracker is the only signal. | operator error, logged | the `[O] 2026-09-25` third occurrence |

## Completed

| File | Change |
|---|---|
| [`push-task.md`](../../src/reasoning/providers/pi/config/agent/prompts/push-task.md) | the lift rule |
| [`pop-task.md`](../../src/reasoning/providers/pi/config/agent/prompts/pop-task.md) | the lift rule |
| `$AGENT_HOME/agent/prompts/` | both prompts installed identical to the repository |
| [`devlog/AGENT_FEEDBACK.md`](../AGENT_FEEDBACK.md) | the third occurrence on `[O] 2026-09-25`, and the grant-lifetime sentence in its mitigation |
