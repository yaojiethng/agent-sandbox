---
description: Restore the traversal pointer from the active task tracker after returning through pi's /tree or /fork. pi provider only, because it pairs with pi's session tree.
argument-hint: "[the frame to pop]"
---

> $@

Restore the traversal pointer only. Do not start the work. If you have an autopilot grant, consider it invalidated. Proceed with autonomy off until the operator explicitly re-grants it.

Read `<scratch>/ACTIVE_TASK_TRACKER.md` and nothing else: not the repository, not the work files, not the prompt that produced this call. The scratch directory is the one the project `AGENTS.md` Scope table declares.

Report exactly three lines.

1. The frame popped: the frame named by the argument, or the tracker's stack top.
2. The node the pointer returns to.
3. The workspace delta: `git log --oneline -1` now against the tracker's recorded HEAD.

The tracker's resume marker owns line 2. When the marker, the stack path and the popped frame's return node disagree, report the marker's node and name the disagreement in the same line.

Report the `## Session memory` block after the three lines, or `steering: none`. Expand a range only when you need the original, with the `session-memory` skill's `zoom <lo>-<hi>`. Do not act on it; the operator's next instruction is the action.

Then stop. The operator issues the next node.
