---
description: Record the active task tracker before a pi /fork or /tree divergence, so the work tree and the traversal stack survive the return. pi provider only, because it pairs with pi's session tree.
argument-hint: "<task name> <reason>"
---

> $@

Record the active task tracker before the divergence. Its directory is the session-local scratch the project `AGENTS.md` Scope table declares; write `<scratch>/ACTIVE_TASK_TRACKER.md`. Read the scratch path from that table instead of hardcoding it.

Write the file; do not restate it here.

1. The work tree, with the current node marked and each node's state.
2. The stack: the path from the root to the current node, and the frontier still to visit.
3. A new frame: the task name and reason from the argument, the workspace git HEAD, and the work item it owns.

Change no other file.
