---
description: Record the active task tracker. pi provider only, because it pairs with pi's session tree.
argument-hint: "[the node and its parent, as the active-tracker skill's push arguments]"
---

> $@

Record the active task tracker. If you have an autopilot grant, consider it invalidated. Proceed with autonomy off until the operator explicitly re-grants it.

The tracker is the `active-tracker` skill: read `$AGENT_HOME/agent/skills/active-tracker/SKILL.md` first, then use `active-tracker.mjs` beside it.

Recording is a checkpoint, not a prediction. It records the traversal as it stands, so recording it twice changes nothing. Make each change with the tool: `push` a node, `pop` one or more subtrees, move a state with `push --state`, and `view` to render. For a bulk change, import the module and drive it from one script, so the change is one script and one render.

The tool prints what it changed. Report that to the operator, naming every dropped node, because a prune the operator cannot see is a prune they cannot question.

Then carry the session memory, held by the `session-memory` skill: `$AGENT_HOME/agent/skills/session-memory/SKILL.md`. `note` the directives this recording produced, with `--home <path>` for a durable record and `--restates <n>` for a restatement, `merge` when `note` reports a merge due, and `render` the block last.

Change no other file.
