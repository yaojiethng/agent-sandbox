---
description: Record the active task tracker before a pi /fork or /tree divergence, so the work tree and the traversal pointer survive the return. pi provider only, because it pairs with pi's session tree.
argument-hint: "<task name> <reason>"
---

> $@

Record the active task tracker before the divergence. Its directory is the session-local scratch the project `AGENTS.md` Scope table declares; write `<scratch>/ACTIVE_TASK_TRACKER.md`. Read the scratch path from that table instead of hardcoding it.

The tracker is a call stack: a divergence pushes a frame, a return pops it, and a node is kept only while it can still be resumed. Prune before you write.

Prune.

- Drop every `[x]` node. It returned, so it is neither on the path nor in the frontier, and its history is the roadmap and the handover.
- Drop every frame whose divergence is resolved. A frame is live only while its work item is unresolved.
- Keep `[~]` and `[-]`. A fork can resume either one, and a resume needs the frame.

Steering travels with the tracker. A steering entry is a directive that applies beyond the node in hand and would change what a future task does. One entry per occurrence; a restatement takes `--restates <n>` and adds no view line. The tool `scripts/steer.mjs`, run as `node scripts/steer.mjs --dir <scratch>`, owns the log and the view. `STEERING_LOG.jsonl` is the append-only storage, `STEERING_VIEW.jsonl` is the bounded cache, and the view is at most 16 lines by 240 characters, newest first.

Write the file; do not restate it here.

1. One resume marker line, `<node> <- resume here`. It owns the node the pointer restores to, and the file names that node nowhere else.
2. The kept work tree, with the current node marked. The states are the stack's: `[ ]` open, `[~]` continues later, `[-]` continues elsewhere. There is no resolved state, because a resolved node is pruned.
3. The stack: the path from the root to the current node, the frontier still to visit, and the top marked `top: <frame>`.
4. A new frame row: the task name and reason from the argument, the workspace git HEAD, the node it returns to, and the work item it owns.
5. `## Steering`, holding the tool's `wake` output as a fenced `text` block, or nothing when it prints `steering: none`.

Record a directive with `note "<text>"`, adding `--home <path>` when it also has a durable record. When `note` reports a merge due, merge the two ranges it names with `merge <lo> <hi> "<summary>"`.

Report what this write changed, before writing.

- The tree diff: each pruned `[x]` node and spent frame by name, the added frame, and any node whose state moved. A drop names its node, because a prune the operator cannot see is a prune they cannot question.
- The memory diff: `diff`, then `mark`.

Change no other file.
