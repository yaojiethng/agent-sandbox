---
name: active-tracker
description: The active task tracker, its task tree and the pointer that survives a pi /fork or /tree. Use when recording what the traversal has done, when re-orienting after a return, or when rendering the task tree.
---

# active-tracker

The active task tracker: the task tree and the pointer. It lives in the session-local scratch, so it survives a divergence and dies with the session. The model behind the data is [`README.md`](README.md); this file is the contract.

## Terminology

| Term | Is |
|---|---|
| node | one unit of work, named by its id |
| edge | a node's link to its parent; exactly one per node, and none for the root |
| root | the one node with no parent |
| pointer | the node the traversal resumes at |
| path | the chain from the root to the pointer, derived from the edges |
| frontier | the nodes off the path, derived from the edges |
| state | `open`, `later` or `elsewhere` |
| prune | drop a node and its subtree |

## The tool

`active-tracker.mjs` beside this skill is both the CLI and the library.

| Command | Does |
|---|---|
| `push <id> <parent> [--label <text>] [--state <state>] [--stay]` | upsert a node and move the pointer to it |
| `pop <id> [<id>...]` | prune one or more nodes, each with its subtree |
| `view` | render the tree and the path into the tracker file |
| `log [--since <n>]` | print the change record |

`parent` is `-` for the root. `--stay` keeps the pointer where it is. An existing node keeps its label and state unless a flag supplies a new one.

The store is `<scratch>/ACTIVE_TASK_TRACKER.json`, the render target is `<scratch>/ACTIVE_TASK_TRACKER.md`, and the log is `<scratch>/ACTIVE_TASK_TRACKER_LOG.jsonl`. Pass `--store` and `--tracker` when the paths differ. A missing store or a missing section refuses, so a render never half-writes.

## The states

| State | Means |
|---|---|
| `open` | in hand, or not started |
| `later` | continues later |
| `elsewhere` | continues elsewhere |

There is no resolved state. A resolved node is pruned, because it is neither on the path nor in the frontier, and its history is the roadmap and the handover.

`elsewhere` names no destination. The roadmap owns filing, so a second copy of the destination here would go stale.

## Idempotence

The store records the traversal as it stands, so recording it twice changes nothing: `push` upserts by node id, `pop` on an absent id is a no-op, and `view` is a pure render.

## The log

Every `push` and `pop` appends one event to `<scratch>/ACTIVE_TASK_TRACKER_LOG.jsonl`. The log is append-only and is never edited. Read it with `log`, or with `readLog` from the library, to reconcile a missed push or a missed pop.

## Codemode

Import the module rather than shelling out, so a bulk change is one script and one render.

```js
import { push, pop, view } from "$AGENT_HOME/agent/skills/active-tracker/active-tracker.mjs";

push({ id: "B6b", parent: "B6", label: "the dispatch-CLI pin and gate" });
pop({ ids: ["B3e", "B4a-i", "B4a-ii", "B4a-iii"] });
view();
```

Each function takes `{ store, tracker, ... }` and defaults to the scratch paths. `pop` takes `ids`, an array.

## The read

`push` is called to record the traversal, and `pop` to re-orient. A tracker that is neither read nor written at the decision point is not a tracker.

## Non-goals

- The session tree. The tracker survives a pi `/fork` or `/tree`; it does not observe one.
- The memory. The `session-memory` skill holds the steering; this skill holds the traversal.
- The roadmap. The tree is the work in hand, not the project's task list.
