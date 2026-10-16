# active-tracker

The model behind `active-tracker.mjs`. The agent-facing contract is [`SKILL.md`](SKILL.md); this file records why the data is shaped the way it is.

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

## Idempotence, and the log

The store records the traversal as it stands. It is not a log of events, so recording it twice changes nothing: `push` upserts by node id, `pop` on an absent id is a no-op, and `view` is a pure render.

Idempotence and history pull in opposite directions, so they live in different files. The store is idempotent and small. The log beside it is append-only and never edited, and every push and pop emits one event there. The log is the change record the store is not, so a missed push or a missed pop can be reconciled after the fact, which the store alone cannot show.

## Non-goals

- The session tree. The tracker survives a pi `/fork` or `/tree`; it does not observe one.
- The memory. The `session-memory` skill holds the steering; this tool holds the traversal.
- The roadmap. The tree is the work in hand, not the project's task list.
- The destination of an `elsewhere` node. The roadmap owns filing, and a second copy of the destination goes stale. `elsewhere` says the node does not continue here; the roadmap says where it went.
