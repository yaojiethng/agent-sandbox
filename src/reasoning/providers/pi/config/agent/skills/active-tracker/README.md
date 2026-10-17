# active-tracker

The model behind the tool. The agent-facing contract is [`SKILL.md`](SKILL.md); this file records why the data is shaped the way it is.

## Two libraries, one facade

`tree.mjs` holds the task tree as an edge list. `memory.mjs` holds the steering memory in the OptMem shape. Neither knows about the other.

`active-tracker.mjs` is the facade. It is the single writer of the tracker file, and it composes the single report from both. The composition is the point: the two libraries share a lifecycle, a file and a mark, so a caller that recorded one without the other would leave the session's state inconsistent. One entry point makes that state hard to get wrong.

## The skill owns its filenames

One value crosses the boundary, and it is a directory. `paths({ root })` is the only place in the skill that builds a filename, and the four names under the root are constants. Three separately settable paths would let a caller put the store in one directory and the log in another, which is the split the paragraph above says the design exists to prevent. A parameter that can express the failure is not a guarantee.

## The task tree is an edge list

The task tree is the decomposition of the work in hand. Every node names exactly one parent, and the root names none, so the tree is an edge list: one `(child, parent)` pair per node.

A linked list is the degenerate case where every node has at most one child. The task tree is not that, which is why the store is an edge list and not a list.

Two values are derived, so neither is stored:

- the path from the root to the pointer node,
- the frontier still to visit.

Deriving both keeps the store small and keeps the two renderings from drifting apart.

## The frame, and why there is none

A frame would be one divergence: the operator forked a session branch, worked, and returned. The tracker does not store one, for two reasons.

- The agent cannot observe a session fork or a session tree. It cannot know that a frame is live, or that two records are two divergences rather than one record repeated.
- `push` records what the operator has already done, and `pop` forces a re-orientation immediately before the operator issues the next instruction. No moment exists at which a frame is the right structure.

A frame is therefore an unobservable event plus a label. The label belongs to the node, not to a stack. The model still earns its place: it names what the tracker deliberately does not hold, and it is the shape a test uses when it feeds a sequence of divergences and returns.

## Idempotence, and the two logs

The store records the traversal as it stands. It is not a log of events, so `push` upserts by node id and `pop` on an absent id is a no-op.

Idempotence and history pull in opposite directions, so they live in different files. The store is idempotent and small. Each library keeps an append-only log beside it, and neither log is ever edited: the tree's log records every push and pop, and the memory's log records every occurrence. They are the change records the store is not, so a missed push or a missed pop can be reconciled after the fact, which the store alone cannot show.

## The memory is the OptMem shape

The memory is OptMem's, https://github.com/VictorTaelin/OptMem: an append-only log as storage, a bounded read, a merge on write, and a summary that is a rebuildable cache. `memory.mjs` reimplements that shape for short-term memory, with the constants adjusted and the binary tree dropped, because the view is 16 lines rather than a million records.

## The report is the reason for the facade

A report that a model composes is a report that varies. The tree's diff is derivable from its log, the memory's diff from its own, and the memory's view is already rendered, so the combined report is a pure function of the two logs since their marks and the two views.

That is why the facade exists rather than a document telling a caller how to write the report. The caller runs one command and relays the output, and the same events always produce the same text.

## Non-goals

- The session tree. The tracker survives a pi `/fork` or `/tree`; it does not observe one.
- The roadmap. The tree is the work in hand, not the project's task list.
- Durable memory. Nothing here outlives the session.
- The destination of an `elsewhere` node. The roadmap owns filing, and a second copy of the destination goes stale.
