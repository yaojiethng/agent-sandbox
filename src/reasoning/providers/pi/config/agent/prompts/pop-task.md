---
description: Force a re-orientation from the active task tracker, before the operator issues the next instruction. pi provider only, because it pairs with pi's session tree.
argument-hint: "[the node to resume at]"
---

> $@

Re-orient from the tracker, then stop. Do not start the work. If you have an autopilot grant, consider it invalidated. Proceed with autonomy off until the operator explicitly re-grants it.

The tracker is the `active-tracker` skill: read `$AGENT_HOME/agent/skills/active-tracker/SKILL.md` first, then `view` the tracker with `active-tracker.mjs` beside it. Read the tracker and nothing else: not the repository, not the work files, not the prompt that produced this call.

Report exactly three lines.

1. The pointer node: the tracker's resume marker.
2. The path from the root to it, and the frontier still to visit.
3. The workspace delta, the tracker's recorded HEAD against the live one.

Report the `## Session memory` block after the three lines, or `steering: none`. Expand a range only when you need the original, with the `session-memory` skill's `zoom <lo>-<hi>`. Do not act on it; the operator's next instruction is the action.

Then stop. The operator issues the next instruction.
