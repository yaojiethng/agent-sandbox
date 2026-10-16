# Steering memory - full design prompt

Future task. The stopgap lands first as a `## Steering` section in two pi-provider prompts, [`push-task.md`](../../src/reasoning/providers/pi/config/agent/prompts/push-task.md) and [`pop-task.md`](../../src/reasoning/providers/pi/config/agent/prompts/pop-task.md), over a session-local append-only log and a bounded view, both owned by [`scripts/steer.mjs`](../../scripts/steer.mjs). This prompt designs the measured mechanism that replaces the stopgap's round-number limits and its single read trigger, and it is aware of what the stopgap fixes and what it leaves open.

## The model

Steering is an operator instruction that applies across tasks rather than to one node: a filing rule, a constraint, a preference. The memory that carries it is a reading budget over an append-only store, the shape [OptMem](https://github.com/VictorTaelin/OptMem) uses at lifetime scale. Concretely, its `LOG.txt` is unbounded and never edited, `WAKE_LINES` is a reading budget rather than a storage budget, `memo note` appends one line and may ask for a compression, `memo wake` prints the budget, `memo zoom` opens a summary into its halves, `memo forget` drops a bad summary, and `TREE/` is a cache rebuildable from the log alone. The stopgap implements that shape in [`scripts/steer.mjs`](../../scripts/steer.mjs), with `note`, `wake`, `merge`, `zoom`, `forget` and `diff`, and drops the binary tree, because the view is 16 lines rather than a million records. The design keeps the shape; if it changes it, it states why, and it reads `steer.mjs` beside `memo` rather than substituting one for the other.

## What the stopgap leaves open

Read the two landed prompts and the log they write before starting. These are the loose ends this design closes or explicitly keeps.

- The limits, 16 lines and 240 characters, are round numbers, not measured.
- The read trigger is `/pop-task` alone, so an agent deciding mid-task does not read the view.
- The loss cause is undiagnosed. Never recorded, recorded but never read, read and then removed by compaction, and read and ignored are four causes with four fixes, and the stopgap assumes the first.
- No eval separates the mechanism from the alternatives, so its value is asserted.
- Session-locality is assumed. If steering is lost across sessions, the tracker is the wrong home by construction.
- The merge is unguarded. A bad summary is rebuildable in principle and untested in fact.

## The prompt

```text
Design the steering memory for the task tracker, and prove it recovers steering
that is lost today. Depth means measurement and an eval, not a richer data
structure. The deliverable is the eval and the mechanism it selects. The stopgap
is already landed: read
src/reasoning/providers/pi/config/agent/prompts/push-task.md and pop-task.md
beside it, and the session-local log and view they read and write, and treat
their limits and their read trigger as the baseline this design keeps or
supersedes with a stated reason.

Diagnose first.

1. Name where steering is lost today. Trace one real steering instruction, an
   operator instruction that applies across tasks, from where it arrived to the
   turn it stopped being available, and say which step dropped it: never
   recorded, recorded but never read, read and then removed by compaction, or
   read and ignored.

2. Measure the workload from $AGENT_HOME/agent/sessions/, not from intuition:
   steering-like operator instructions per session, their length distribution,
   their arrival rate, how long each stays relevant, and the token cost of
   reading them. The limits come from this table, not from a round number.

3. Read OptMem's `memo` implementation, source at https://github.com/VictorTaelin/OptMem, and read
   the stopgap's scripts/steer.mjs beside it rather than substituting one for
   the other. State which parts fit a session-scoped, roughly 16-item,
   read-on-return memory, and which exist only for its million-record lifetime
   store.

Then design, and let the eval choose.

4. The primary deliverable is an eval: a script that plants N steering items in
   a session, runs a later task that depends on one, and measures compliance.
   Ablate at least four arms: no memory, an unbounded list, the bounded view
   alone, and the log plus view. The mechanism is the arm that wins on
   compliance per token.

5. Only then the mechanism: the log, the bounded view, the merge, the read
   trigger. Set the limits from the measured arrival rate and the measured token
   cost.

6. Name the read trigger. It is the crux. A memory that is not read at the moment
   of decision is not a memory. Say when the view is consulted, and why that
   moment is the decision point rather than a convenient one.

Deliver the eval, the workload table, the loss diagnosis, and the mechanism the
eval selects. Cite the session count and the token cost behind every limit.

The result is right when the eval separates the arms, the workload table comes
from the sessions, a bad merge is detectable and rebuildable from the log, and
the token cost is measured.

Out of scope: changing compaction behavior, and any cross-session memory. If the
loss is cross-session, say so and stop; the tracker is then the wrong home.
```
