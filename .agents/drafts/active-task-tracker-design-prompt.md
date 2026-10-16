# Active task tracker - full design prompt

Future task. The stopgap landed first as two pi-provider prompts, [`push-task.md`](../../src/reasoning/providers/pi/config/agent/prompts/push-task.md) and [`pop-task.md`](../../src/reasoning/providers/pi/config/agent/prompts/pop-task.md), with a session-local tracker whose path the provider `AGENTS.md` Scope table declares. This prompt designs the mechanism that replaces the manual prompts with automatic reorientation, and it is aware of what the stopgap fixes and what it leaves open.

## The model

The work decomposes into a **tree**, and the tracker is written as that tree. The traversal is **depth-first**, and depth-first search is implemented with a **stack**. The tracker records the tree; the stack records the position in it, the path from the root to the node in hand plus the frontier still to visit. A divergence inserts a subtree and descends, which is the push; the return pops back to the paused node. The design keeps this model; if it changes anything, it states why.

## What the stopgap leaves open

Read the two landed prompts before starting. These are the loose ends this design must close or explicitly keep.

- The restoration is manual. It helps only when the operator invokes `/pop-task`.
- The current frame is named by the operator, not read from the session tree.
- The tracker can be clobbered by a forked agent that writes from rewound context.
- The push fires from one prompt, not from a discipline, and the operator can forget it.
- The two prompts are duplicated per provider if another provider ever gains a session tree. The design says whether that matters.

## The prompt

```text
Design the automatic mechanism that replaces the manual task-tracker stopgap.
Read the two landed prompts first,
src/reasoning/providers/pi/config/agent/prompts/push-task.md and
src/reasoning/providers/pi/config/agent/prompts/pop-task.md, and the session-local
tracker they read and write, and treat their conventions and their model as the
baseline this design either keeps or supersedes with a stated reason.

The model. The work decomposes into a tree, and the tracker is written as that
tree. The traversal is depth-first, and depth-first search is implemented with a
stack. The tracker records the tree; the stack records the position, the path
from the root to the node in hand plus the frontier. A divergence inserts a
subtree and descends, which is the push; the return pops back to the paused node.
Do not redesign the model unless you can say why it is wrong; the task is the
mechanism that replaces the two manual prompts.

The problem. pi stores a session as a tree and supplies only the active branch to
the model. /tree moves within the session file; /fork creates a new session from
an earlier user message. Neither rewinds the workspace. After a divergence to
patch something urgent and a return to the main line, the conversation is older
than the disk.

Read first, and do not design before you do.

1. Read pi's own documentation: docs/session-format.md for the tree and the entry
   types; docs/extensions.md for session_start, before_agent_start, the context
   hooks, ctx.sessionManager.getBranch() and pi.appendEntry(); docs/how-pi-works.md
   for context assembly; docs/compaction.md for branch summaries. State which
   primitive makes the restoration automatic, and state what the branch summary pi
   attaches when you leave a branch carries and what it does not.

2. Observe a real session tree. Dump one session JSONL from
   ~/.pi/agent/sessions/ with jq: the entries, the parentId links, the branch
   point, and any summary entry. Do not reason from the documentation alone.

Then design.

3. Decide whether the current frame is read from the session tree or named by the
   operator, and if it is read, how the tracker's frames map to branch points.

4. Specify the injection, if that is the choice: an extension that, at
   session_start, reads the tracker and the git state and appends the
   reconciliation. State the fallback when the tracker is absent.

5. Specify the write side without a manual prompt. The agent never sees the
   /fork, so say what else can fire the write, or prove that a prompt is the only
   option.

6. Make it fork-safe. A forked agent that writes from rewound context can clobber
   the tracker; specify the append-only or the merge rule.

Then prove it.

7. Build a fork experiment that fails without the mechanism and passes with it.
   Diverge, commit, return, and observe whether the resumed agent reaches the
   right node without being told. Keep both runs.

8. Write the repo check that reproduces the experiment, and run the gates.

Deliver the mechanism, the schema, the experiment's two runs, and the roadmap row
that supersedes the stopgap. Cite the session entry or the command behind every
claim.

The result is right when the fork experiment is red before and green after, a
freshly forked agent resumes without an invocation, and bash scripts/lint.sh is
clean.

Out of scope: durability across sessions, and the roadmap and handover records.
```
