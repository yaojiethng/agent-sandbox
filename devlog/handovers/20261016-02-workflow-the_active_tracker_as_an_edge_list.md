---
date: 2026-10-16
milestone: M3.2.3 - Dispatch Workflows as a Command Surface
type: Workflow
status: Closed
---

# Handover - The active task tracker as an edge list

## Objective

Move the active task tracker out of prose and into a skill that owns the tree, so the model supplies ids, labels and states and the tool performs the move.

## Scope

The new skill and its tool, the two prompts, the tests, the live tracker, the roadmap, repository and installed.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The tree is an edge list | `push <id> <parent>` is the only way in; the store holds `nodes[]` of `{id, parent, label, state}` | Accepted |
| The path and the frontier are derived | `view` renders both from the edges; neither is stored | Accepted |
| `push` is idempotent | three pushes of one id leave one node; `test_push_is_idempotent` | Accepted |
| `pop` drops a subtree | the node and its descendants go, and the pointer falls to the parent | Accepted |
| The frame is not stored | no frame table; the model is documented with its restriction | Accepted |
| The prompts invoke the skill | both name `active-tracker/SKILL.md` and no longer describe the mechanics | Accepted |
| The live tracker is migrated | the file renders from the store, and the fork-stack section is gone | Accepted |
| Repo and installed copies match | `diff`, identical | Accepted |
| Gates clean | `bash scripts/lint.sh` clean; `bash scripts/run_tests.sh` green | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The store is JSON and the tracker file is a render | an edge list is data, and a drawn tree is not addressable; the render is a pure function of the store | `SKILL.md` |
| The tool owns two regions of the tracker file | `## The work tree` and `## The stack`; the rest stays hand-authored, so the free-form sections survive a render | `active-tracker.mjs` |
| The frame is a documented non-goal | the agent cannot observe a session fork, so a frame record would assert an event it cannot verify | `SKILL.md` |
| The pointer lives in the store | the resume marker is rendered from it, so one fact has one home | `active-tracker.mjs` |
| `push` records the traversal, not a prediction | `/push` records what the operator has already done, and an idempotent checkpoint needs no prediction | `push-task.md` |

## Decisions pending

| Decision | Why it waits |
|---|---|
| Where the state vocabulary ends and the label begins | `[ ]`, `[~]` and `[-]` carry over; whether a routing target such as `M3.6.3` is a state or a label is unresolved, and the live store keeps it in the label |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The first tool edited text regions. It pruned lines containing `[x]`, rewrote the HEAD note and appended a frame row, and it could not name a node, a parent or a child. | design | replaced; no part carried over |
| Alignment in a drawn tree needs the depth, not the label length. The first renderer padded the label alone, so each depth shifted the state column by four. | defect, fixed before landing | `renderTree` |
| Idempotence is a property of the store. The frame append was the one non-idempotent operation, because a record that asserts a fork asserts a second fork on a repeat. | design | the frame is gone |

## Completed

| File | Change |
|---|---|
| [`active-tracker/SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/active-tracker/SKILL.md) | the contract, the edge list, the states, idempotence, the frame model |
| [`active-tracker/active-tracker.mjs`](../../src/reasoning/providers/pi/config/agent/skills/active-tracker/active-tracker.mjs) | push, pop, view |
| [`test_active_tracker.sh`](../../tests/test_active_tracker.sh) | nine cases |
| [`push-task.md`](../../src/reasoning/providers/pi/config/agent/prompts/push-task.md) | records the traversal; the mechanics live in the skill |
| [`pop-task.md`](../../src/reasoning/providers/pi/config/agent/prompts/pop-task.md) | forces a re-orientation; the mechanics live in the skill |
| [`devlog/roadmap.md`](../roadmap.md) | the M3.2.3 row |
| `<scratch>/ACTIVE_TASK_TRACKER.json` | the migrated edge list |
| `<scratch>/ACTIVE_TASK_TRACKER.md` | rendered; the fork-stack section removed |
| `$AGENT_HOME/agent/skills/active-tracker/` | the skill and the tool installed |
| `$AGENT_HOME/agent/prompts/` | both prompts installed; the stray `tracker.mjs` removed |
