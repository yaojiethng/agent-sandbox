---
description: Restore the traversal from the active task tracker after returning through pi's /tree or /fork. pi provider only, because it pairs with pi's session tree.
argument-hint: "[the frame to pop]"
---

> $@

Read the active task tracker after the return. Its directory is the session-local scratch the project `AGENTS.md` Scope table declares; read `<scratch>/ACTIVE_TASK_TRACKER.md`.

Report three lines, then resume.

1. The frame popped: the task named by the argument, or the top of the stack.
2. The node it returns to.
3. The workspace delta: the git HEAD now against the recorded one.

Then resume the returned-to node. Do not re-derive the tree.
