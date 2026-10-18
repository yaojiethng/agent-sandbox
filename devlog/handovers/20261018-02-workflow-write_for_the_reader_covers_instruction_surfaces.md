---
date: 2026-10-18
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - Extend write-for-the-reader to instruction surfaces

## Objective

Extend `communication-principle-write-for-the-reader` so it covers skills and prompts, because an instruction surface is read by an agent that never saw its earlier version.

## Scope

Continues the M3.3.4 row **Settle the split criterion and prove the template**, which files the principles that row asks for, and the closed row `communication-principle-write-for-the-reader` it produced. The judgement this iteration adds is the instruction-surface case: a skill, a prompt, or either `AGENTS.md` layer holds only current text, so a clause that rebuts a sentence the file no longer contains has no referent. The trigger was an operator review of a skill edit that carried three such clauses and a stopgap note.

The same unit carries the allowed-form rule, the other half of the instruction-surface judgement. A reader told only what not to write invents a replacement, which is how the original defect arrived, so the principle states the permitted form and names the action. The section and the test question that checks it are one unit with the skill that holds them. The policy line that pointed at the rule moves in its own unit, because a pointer is a different kind of change from the judgement it points at.

Ruled out of scope, with reasons. The rewrite of `principle-guard-the-context-window` is applied in the agent config home, not in the tree, so it appears in `## Completed` as a config-home change with no repository file. Naming the `principle-*` set and importing those skills is a separate iteration, because it opens a placement question the task list has not settled. The pre-existing markdown failure at `devlog/AGENT_FEEDBACK.md:33` is untouched; it is committed state unrelated to this work.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The principle covers skills and prompts, not only documents and records | `SKILL.md` `description` names a skill and a prompt; `## The same judgment on a prompt` states the case | Agent [x] |
| The editor-facing case carries a positive counterpart, not a prohibition alone | second table, one row per anti-pattern, each row's right column states what to write | Agent [x] |
| The closing test covers the reader who lacks an earlier version of the file | `## The test`, third question | Agent [x] |
| The principle states the permitted form where a sentence names only a prohibition | `## Where the sentence names only the prohibition`, one reason clause, the action and both worked examples | Agent [x] |
| The closing test covers the prohibition case | `**The test.**` asks four questions | Agent [x] |
| The repository source and the installed copy agree | `diff -q` on both paths exits 0 | Agent [x] |
| The instruction-surface gates accept the file | `scripts/check_frontmatter.sh`, `scripts/check_markdown.sh` | Agent [x] |
| A skill payload carries no note about what an earlier version said | `grep` for `finite and non-renewable`, `turn budget`, `Stopgap` over the config-home skill returns nothing | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| State the instruction-surface case as its own section rather than a table row | The other rows are about a session's vocabulary. This one is about the reader's ignorance of a prior file version, which is a different reason for the same failure and needs its own statement. | the skill `## Where the editor is the reader` |
| Give every anti-pattern a positive counterpart in the same row | A list of prohibitions leaves the writer to invent the replacement, and an invented replacement is how the original defect arrived. The right column is the artifact. | the skill, second table |
| Keep the principle's existing name and prefix | The judgement is not confined to communication. It governs implementation prose, commits, records, skills and prompts, so the general `principle-` namespace scopes it correctly; `communication-principle-` would narrow it to one surface. Operator direction. | this record |
| Carry the allowed-form section here rather than with the policy fold | The section and the test question that checks it are one unit. Landing the question first would leave the skill asserting a test about a section it does not contain; landing the section later would write the test twice inside one range. | this record |
| Move the stopgap note out of the skill payload | A note that a file will be overwritten is addressed to the editor. The reading agent holds current text only, and the note consumes its attention on a fact it cannot act on. The durable home is the record layer. | this record; the skill now carries no such note |
| Correct the earlier claim that a package owns the upstream `principle-*` skills | Checked: 24 `principle-*` directories exist only in the agent config home, and no package root, manifest or seed script names them. Nothing overwrites them, so the stopgap condition was wrong as well as misplaced. | this record |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| The skill naming convention for the fourth bucket, the operational skills that are neither a judgement nor communication | Importing the `principle-*` set, and any new skill's name | the operator's three buckets, plus a class for procedure skills such as `check-in`, `doc-maintenance` and `pi-bump`, which number 10 installed skills and fit none of the three |
| Whether the import lands before or after the **Skill maintenance record** row decides naming and placement | The import, since that row states the decision is made there and not by the first skill to land | settle that row first, or land the import as its test run |

## Findings

| Finding | Type | Impact |
|---|---|---|
| A skill that rebuts text it no longer contains is unreadable to its reader, and this is a class defect rather than one instance | operator experience | fixed in the principle, which now names the class; six instances found across two files and corrected |
| The `principle-*` skills have no provenance. 24 directories, no package root, no manifest, no seed script, and no record of which are upstream and which are the project's own | agent experience | routed to this record and to the pending question; the **Skill maintenance record** row in M3.3.5 is the durable fix |
| The instruction-surface fix for one orphaned skill is not a note but a home. A skill in the config home with no source of truth cannot be corrected durably | agent experience | routed to the import finding and the pending placement question |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-write-for-the-reader/SKILL.md` | description names a skill and a prompt; `## Where the editor is the reader` added with a second anti-pattern table carrying positive counterparts; `## The same judgment on a prompt` added; `## Where the sentence names only the prohibition` added with both worked examples; the test gains its third and fourth questions |
| `$AGENT_HOME/skills/communication-principle-write-for-the-reader/SKILL.md` | installed copy, byte-identical to the source |
| `$AGENT_HOME/skills/principle-guard-the-context-window/SKILL.md` | config-home only, no repository file: the three clauses that rebut removed text and the stopgap block are gone, four rules stated positively |
| `$AGENT_HOME/skills/principle-guard-the-context-window/context.sh` | config-home only: prints tokens used, the declared window, the percentage and the remainder from `$PI_SESSION_FILE` |
| `devlog/AGENT_FEEDBACK.md` | a blank line above the `## [A] 2026-10-17` heading, required to clear the blocking markdown gate; flagged rather than fixed silently |
| `devlog/handovers/20261018-02-workflow-write_for_the_reader_covers_instruction_surfaces.md` | this record |
