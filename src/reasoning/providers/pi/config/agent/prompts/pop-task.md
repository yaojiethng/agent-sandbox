---
description: Force a re-orientation from the active task tracker, before the operator issues the next instruction. pi provider only, because it pairs with pi's session tree.
argument-hint: "[the node to resume at]"
---

> $@

Re-orient from the tracker, then stop. Do not start the work. If you have an autopilot grant, consider it invalidated. Proceed with autonomy off until the operator explicitly re-grants it.

The tracker is the `active-tracker` skill: read `$AGENT_HOME/agent/skills/active-tracker/SKILL.md` first.

Run `active-tracker.mjs report`. It prints the tree diff, the pointer the traversal resumes at, the workspace delta and the `## Session memory` block. Report what it prints, unchanged. Read the tracker and nothing else: not the repository, not the work files, not the prompt that produced this call.

Do not act on the memory block; the operator's next instruction is the action. Expand a range only when you need the original, with `memory zoom <lo>-<hi>`.

Then stop. The operator issues the next instruction.
