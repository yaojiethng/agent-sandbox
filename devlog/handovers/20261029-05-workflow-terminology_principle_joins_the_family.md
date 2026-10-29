---
status: Closed
milestone: M3.2.2
type: Workflow
date: 2026-10-29
---

# Handover - the terminology principle joins the communication family

## Objective

Give `define-terminology-before-use` the family prefix its subject belongs to, so the index lists one kind of thing rather than sixteen of one kind and one of another.

## Scope

The rename of one principle skill and every live carrier of its name. It follows the index row: the section that lists the principles is now name-first, and the odd name out became visible in that list.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill lives at its new path | `ls src/reasoning/providers/pi/config/agent/skills/communication-principle-define-terminology-before-use/SKILL.md` | Agent [x] Agent run: present |
| No skill lives at the old path | `ls src/reasoning/providers/pi/config/agent/skills/principle-define-terminology-before-use` fails | Agent [x] Agent run: no such file or directory |
| The frontmatter name matches the directory | `head -3` on the skill, and `bash scripts/check_document_shape.sh` accepts the corpus | Agent [x] Agent run: `name:` carries the family prefix; document shape clean, corpus counted |
| The shape gate still sees the skill | the gate keys on a directory name carrying `principle-`, so the longer name keeps it | Agent [x] Agent run: clean across the instruction files, the shipping documents and the principle skills |
| Every live carrier carries the new name | a tree scan for the old token that excludes the family prefix lists nothing outside the history | Agent [x] Agent run: only `devlog/handovers/` and `devlog/discussions/` remain |
| The index entry points at the new path | the bullet in the provider layer `AGENTS.md`, and `bash scripts/check_reach.sh` | Agent [x] Agent run: reach clean |
| The installed copy matches the tree | `diff` on the layer file and on each skill file under `$AGENT_HOME/agent/skills/` | Agent [x] Agent run: identical, and the old directory is gone from the runtime |
| The roadmap row names the rename and closes with this handover | the row is `- [x]` and cites this record | Agent [x] Agent run: filed and ticked |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The prefix joins rather than the corpus splitting | The subject is a sentence's wording, and its two nearest neighbours, `maximize-conceptual-leverage` and `align-the-mental-model`, already carry the prefix. The alternative, leaving the name short and explaining the exception, is the copy of a rule that goes stale | this record |
| The link text in the authoring convention stays the short form | That list spells every member by its short name, so changing one entry to the long form would assert a distinction the list does not draw | this record |
| The historical records keep the old name | A closed record is a log of what was true then, not a pointer that must resolve now | this record |

## Decisions pending

None.

## Findings

- **The installed copy is a second thing to update on every rename**, and nothing reports when it lags: it holds the layer file and its own copy of each skill. It is synced here by hand, which is the same class as the row filed for the layer copy's missing gate.
- **The rename reaches three sibling skills by code span**, not by link, so the reach gate would not have caught them. The tree scan did.

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-define-terminology-before-use/SKILL.md` | Moved from the short name; frontmatter name follows |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | The index entry names and links the new path |
| `docs/development/prompt-authoring-conventions.md` | The member list's link target follows |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-align-the-mental-model/SKILL.md` | Cross-reference follows |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-attach-as-you-read/SKILL.md` | Cross-reference follows |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-maximize-conceptual-leverage/SKILL.md` | Cross-reference follows |
| `$AGENT_HOME/agent/skills/` and `$AGENT_HOME/agent/AGENTS.md` | Installed copy synced, old skill directory removed |
| `devlog/roadmap.md` | Row filed and ticked |
