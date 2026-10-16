---
name: active-tracker
description: "The active task tracker: the task tree, the pointer and the steering memory, the state that survives a pi /fork or /tree. Use when recording what the traversal has done, when re-orienting after a return, or when reading the session's steering."
---

# active-tracker

The session's working state: the task tree, the pointer into it, and the steering memory. It lives in the session-local scratch, so it survives a divergence and dies with the session. The model behind the data is [`README.md`](README.md); this file is the contract.

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
| directive | a steering line that applies beyond the node in hand |

## The tool

`active-tracker.mjs` is both the CLI and the library. It composes `tree.mjs` and `memory.mjs`.

| Command | Does |
|---|---|
| `push <id> <parent> [--label <text>] [--state <state>] [--stay] [--note <text>] [--home <path>]` | upsert a node, move the pointer, and optionally note a directive |
| `pop <id> [<id>...]` | prune one or more nodes, each with its subtree |
| `view` | render the tree and the path into the tracker file |
| `report` | print the combined change report, and advance both marks |
| `memory <wake\|note\|merge\|zoom\|forget>` | the memory's own operations |
| `log [--since <n>]` | print the tree's change record |

The paths default to `<scratch>/ACTIVE_TASK_TRACKER.json`, `<scratch>/ACTIVE_TASK_TRACKER.md` and `<scratch>/SESSION_MEMORY_LOG.jsonl`, overridden by `--store`, `--tracker` and `--log`. A missing store or a missing section refuses, so a render never half-writes.

## The tree

`push` upserts by node id, so a repeated push is a no-op. `pop` on an absent id changes nothing. `view` is a pure render.

| State | Means |
|---|---|
| `open` | in hand, or not started |
| `later` | continues later |
| `elsewhere` | continues elsewhere |

There is no resolved state: a resolved node is pruned, because its history is the roadmap and the handover. `elsewhere` names no destination, because the roadmap owns filing.

## The memory

An append-only log is the storage, and a bounded view is the reading budget. The view is at most 16 lines by 240 characters; when it overflows, `note` reports a merge due, and the two ranges it names merge into one summary. A summary is a cache, so `forget` drops one and the originals resurface. The log is never pruned.

`note` appends one occurrence. `--restates <n>` records a restatement and adds no view line. `--home <path>` points at a durable record. `wake` prints the view, and `zoom <lo>-<hi>` prints the log range.

## The report

`report` is a pure function of the tree's log since its mark, the memory's diff, and the memory's view. It prints the tree diff, the memory diff and the memory block, and advances both marks. The same events always produce the same report, so the caller relays it instead of composing one.

## Codemode

Import the facade, or either library, rather than shelling out.

```js
import { push, pop, view, report, tree, memory } from "$AGENT_HOME/agent/skills/active-tracker/active-tracker.mjs";

push({ id: "B6b", parent: "B6", label: "the dispatch-CLI pin and gate", note: "the free tier is measured" });
pop({ ids: ["B3e", "B4a-i", "B4a-ii", "B4a-iii"] });
console.log(report());
```

Each function takes `{ store, tracker, log, ... }` and defaults to the scratch paths. `pop` takes `ids`, an array.

## Non-goals

- The session tree. The tracker survives a pi `/fork` or `/tree`; it does not observe one.
- The roadmap. The tree is the work in hand, not the project's task list.
- Durable memory. Nothing here outlives the session, so a durable directive goes to its own record and the memory holds a pointer.
