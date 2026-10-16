---
date: 2026-10-15
milestone: M3.2.3 - Dispatch Workflows as a Command Surface
type: Workflow
status: Closed
---

# Handover - Wire the session-memory skill

## Objective

Point the tracker prompts at the skill, so `push-task` and `pop-task` call it instead of restating its commands, and the deep design names the skill as the stopgap's home.

## Scope

The two prompts, repository and installed; the deep design prompt; the roadmap rows; the live block.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `push-task` calls the skill | it names the skill path and the `render` call with the log, the block and the heading | Accepted |
| `pop-task` reports the block | it reports `## Session memory` and expands a range with `zoom` | Accepted |
| The draft names the skill | the two references to `scripts/steer.mjs` now name the session-memory skill | Accepted |
| The roadmap names the skill | the M3.2.3 row carries the skill and both handovers | Accepted |
| The live block moved | the tracker's section is `## Session memory`, rendered by the tool | Accepted |
| Repo and installed copies match | `diff`, identical | Accepted |
| Gates clean | `bash scripts/lint.sh` clean across 8 gates | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The prompts reference the contract, not the commands | the skill owns the commands and the bounds, so the prompt cannot drift from them | `push-task`; `pop-task` |
| The block is written last | `push-task` writes the tracker first, then the tool replaces the block region, so the two writers never interleave | `push-task` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The prompt shrank by about a third, because the format and the bounds now live in the skill. | measurement | this record |
| The live tracker's section was renamed from `## Steering` to `## Session memory`, because the block is the memory's and steering is only its content. | naming | the tracker |

## Completed

| File | Change |
|---|---|
| [`push-task.md`](../../src/reasoning/providers/pi/config/agent/prompts/push-task.md) | the skill reference, the `render` call |
| [`pop-task.md`](../../src/reasoning/providers/pi/config/agent/prompts/pop-task.md) | report the block, expand with `zoom` |
| [`.agents/drafts/steering-memory-design-prompt.md`](../../.agents/drafts/steering-memory-design-prompt.md) | the skill as the stopgap's home |
| [`devlog/roadmap.md`](../roadmap.md) | the M3.2.3 rows |
| `<scratch>/ACTIVE_TASK_TRACKER.md` | the block re-rendered under `## Session memory` |
| `$AGENT_HOME/agent/prompts/` | both prompts installed identical to the repository |
