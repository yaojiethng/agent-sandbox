---
date: 2026-10-16
milestone: M3.2.3 - Dispatch Workflows as a Command Surface
type: Workflow
status: Closed
---

# Handover - Retire a directive the design outgrew

## Objective

Close the gap the push report exposed. The memory could append and compress a directive and never retire one, so a directive outlived the design it described.

## Scope

`memory.mjs`, the facade's CLI, the skill, the push prompt, the test, the live memory, the roadmap, repository and installed.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| An original can be retired | `test_memory_retire_drops_a_directive`; the earlier reproduction showed `forget` could not | Accepted |
| The log keeps the fact | the retirement is one logged occurrence carrying `retires` | Accepted |
| An absent range refuses | `test_memory_retire_refuses_an_absent_range` | Accepted |
| A later `forget` cannot resurrect a retirement | `forget` skips an entry that carries `retires` | Accepted |
| The procedure retires | `/push-task` names `memory retire` in the same recording | Accepted |
| The live memory is reconciled | `[3-3]` and `[4-4]` retired, logged as n=8 | Accepted |
| Gates clean | lint clean; the suite green | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A retirement is logged, not edited | the log is append-only, so the retirement is auditable and is not confused with a deletion | `memory.mjs` |
| `retire` is separate from `forget` | `forget` is a summary-cache operation that resurfaces the originals, and retiring an original is a different act | `SKILL.md` |
| A retired range leaves the view entirely | the view is the reading budget, so a superseded line is cost without a reader | `SKILL.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The gap came from the OptMem shape, which treats an original as a durable fact. A steering directive is a mutable instruction, so it needs an invalidation the shape does not have. | design | `retire` |
| `forget` reported "forgot 1 line(s)" for an original and then restored it, so the tool claimed a change it did not make. The retirement path is separate, so that claim cannot recur. | defect | `forget` |
| The push report surfaces a contradiction only when the operator reads it. The procedure now retires in the recording that invalidates, so the reconciliation is not left to the reader. | process | `push-task.md` |

## Completed

| File | Change |
|---|---|
| [`memory.mjs`](../../../src/reasoning/providers/pi/config/agent/skills/active-tracker/memory.mjs) | `retire`, and the `forget` guard |
| [`active-tracker.mjs`](../../../src/reasoning/providers/pi/config/agent/skills/active-tracker/active-tracker.mjs) | the `memory retire` subcommand |
| [`SKILL.md`](../../../src/reasoning/providers/pi/config/agent/skills/active-tracker/SKILL.md) | the verb and its rule |
| [`push-task.md`](../../../src/reasoning/providers/pi/config/agent/prompts/push-task.md) | retire in the same recording |
| [`test_active_tracker.sh`](../../../tests/test_active_tracker.sh) | twenty-one cases |
| [`devlog/roadmap.md`](../../roadmap.md) | the M3.2.3 row |
| `<scratch>/SESSION_MEMORY_LOG.jsonl` | n=8, the retirement of `[3-4]` |
| `$AGENT_HOME/agent/skills/` | the skill installed |
