---
description: Record the active task tracker. pi provider only, because it pairs with pi's session tree.
argument-hint: "[the node and its parent, as the active-tracker skill's push arguments]"
---

> $@

Record the active task tracker. If you have an autopilot grant, consider it invalidated. Proceed with autonomy off until the operator explicitly re-grants it.

The tracker is the `active-tracker` skill: read `$AGENT_HOME/agent/skills/active-tracker/SKILL.md` first. One tool holds the task tree and the steering memory, so there is one entry point.

Make each change with `active-tracker.mjs`: `push` a node, `pop` one or more subtrees, move a state with `push --state`, and note a steering directive with `push --note`. Retire the directives this recording invalidated, with `memory retire <lo>-<hi>`. For a bulk change, import the module and drive it from one script.

Then run `report` and relay it. The report is a pure function of the two logs and the two views, so the same events always produce the same text. Do not compose one by hand.

Change no other file.
