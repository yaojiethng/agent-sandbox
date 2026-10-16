---
name: active-tracker
description: The active task tracker, its task tree and the pointer that survives a pi /fork or /tree. Use when recording what the traversal has done, when re-orienting after a return, or when rendering the task tree.
---

# active-tracker

The active task tracker. The task tree is the decomposition of the work in hand; the pointer is the node the traversal resumes at. The tracker lives in the session-local scratch, so it survives a divergence and dies with the session.

## What it carries

The traversal: the tree, the pointer, and the state of each node. Nothing about the session that produced it.

## The tree is an edge list

Every node names exactly one parent, and the root names none. From the edges and the pointer the tool derives two things, so neither is stored:

- the path from the root to the pointer node,
- the frontier still to visit.

A linked list is the case where every node has at most one child. The task tree is not that, which is why it is an edge list and not a list.

## The tool

`active-tracker.mjs` beside this skill, run with `node`.

| Command | Does |
|---|---|
| `push <id> <parent> [--label <text>] [--state <mark>] [--stay]` | upsert a node, and move the pointer to it |
| `pop <id>` | drop the node and its subtree |
| `view` | render the tree and the path into the tracker file |

`parent` is `-` for the root. `--stay` keeps the pointer where it is.

The store is `<scratch>/ACTIVE_TASK_TRACKER.json`. The render target is `<scratch>/ACTIVE_TASK_TRACKER.md`, whose `## The work tree` and `## The stack` blocks the tool owns. Pass `--store` and `--tracker` when the paths differ. A missing section refuses, so a render never half-writes.

## The states

`[ ]` open, `[~]` continues later, `[-]` continues elsewhere. There is no resolved state. A resolved node is pruned when it is popped, because it is neither on the path nor in the frontier, and its history is the roadmap and the handover.

## Idempotence

The tracker records the traversal as it stands. It is not a log of events, so recording it twice changes nothing.

- `push` upserts by node id, so a repeated push is a no-op.
- `pop` on an absent id changes nothing.
- `view` is a pure render.

## The model

The tree is an edge list; the pointer is one node id. The session tree is a different structure, and the agent cannot observe it.

**The frame, and why there is none.** A frame would be one divergence: the operator forked a session branch, worked, and returned. The tracker does not store one, for two reasons.

- The agent cannot observe a session fork or a session tree. It cannot know that a frame is live, or that two records are two divergences rather than one record repeated.
- `push` records what the operator has already done, and `pop` forces a re-orientation immediately before the operator issues the next instruction. No moment exists at which a frame is the right structure.

A frame is an unobservable event plus a label. The label belongs to the node, not to a stack. The model still earns its place: it names what the tracker deliberately does not hold, and it is the right shape for a test that feeds the tool a sequence of divergences and returns.

## The read

`push` is called to record the traversal, and `pop` to re-orient. A tracker that is neither read nor written at the decision point is not a tracker.

## Non-goals

- The session tree. The tracker survives a pi `/fork` or `/tree`; it does not observe one.
- The memory. The `session-memory` skill holds the steering; this skill holds the traversal.
- The roadmap. The tree is the work in hand, not the project's task list.
