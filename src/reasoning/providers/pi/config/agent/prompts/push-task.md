---
description: Record the active task tracker before a pi /fork or /tree divergence, so the work tree and the traversal pointer survive the return. pi provider only, because it pairs with pi's session tree.
argument-hint: "<task name> <reason>"
---

> $@

Record the active task tracker before the divergence. Its directory is the session-local scratch the project `AGENTS.md` Scope table declares; write `<scratch>/ACTIVE_TASK_TRACKER.md`. Read the scratch path from that table instead of hardcoding it.

Write the file; do not restate it here.

1. One resume marker line, `<node> <- resume here`. It owns the node the pointer restores to. Name that node nowhere else in the file.
2. The work tree, with the current node marked and each node's state.
3. The stack: the path from the root to the current node, the frontier still to visit, and the stack top marked `top: <frame>`.
4. A new frame row: the task name and reason from the argument, the workspace git HEAD, the node it returns to, and the work item it owns.

Change no other file.
