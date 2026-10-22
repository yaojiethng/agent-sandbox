---
date: 2026-10-18
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - Import the context-window principle

## Objective

Give `principle-guard-the-context-window` a home in the tree, so a skill that lived only in the agent config home gains a source of truth, a maintenance record and an executable check.

## Scope

Continues the M3.3.3 row **Skill maintenance record**, which the previous iteration settled, and continues handover `20261018-03`. This is the first record written under the shape that row defines, ahead of the row's designated test run, which distils operator-supplied skills. The skill is now sourced from `src/reasoning/providers/pi/config/agent/skills/` and installed to `$AGENT_HOME/skills/`, the path its `SKILL.md` names for `context.sh`.

Ruled out of scope. The other 22 `principle-*` skills stay in the config home. Importing them is one decision each, under the same convention, and doing them in one pass would hide a bad record shape behind volume. The convention still has no observer, which is the previous record's pending question and is not settled here.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill has a repository source of truth | `src/reasoning/providers/pi/config/agent/skills/principle-guard-the-context-window/` holds `SKILL.md`, `context.sh`, `MAINTENANCE.md` | Agent [x] |
| The record carries the three sections the row requires | `MAINTENANCE.md` `## Source`, `## Adapted`, `## Name` | Agent [x] |
| The installed copy matches the source | `diff -r` on both directories exits 0 | Agent [x] |
| The check the skill names runs from any working directory | `bash "$HOME/.pi/agent/skills/principle-guard-the-context-window/context.sh"` prints tokens, window, percentage and remainder | Agent [x] |
| The skill payload carries no text addressed to an editor | `grep` for a stopgap note, or for a sentence rebutting a removed clause, returns nothing | Agent [x] |
| Every gate passes | `scripts/lint.sh`, 10 gates, frontmatter now across 89 files | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Import this skill first, out of the 24 `principle-*` skills | It is the one with a measured defect and an executable check, so it proves the record shape against a real adaptation rather than a copy | this record; `MAINTENANCE.md` |
| Install `MAINTENANCE.md` beside the skill, not only in the repo | The row says the record is one a skill carries beside its `SKILL.md`. Pi loads only `SKILL.md`, so the record is inert to the reading agent and costs the context nothing. | `MAINTENANCE.md`; the install path |
| Rewrite the `disable-model-invocation` sentence rather than increment its count | It named two repo skills that set the field while four already did. A prose count of files drifts on every import, so the sentence now states the condition instead of the membership. | `prompt-authoring-conventions.md` `**Skill frontmatter.**` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Whether to gate the skill naming convention | Carried from handover `20261018-03`; a fifth skill now depends on it | add a name check to `scripts/check_frontmatter.sh`; or leave it a judgement |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The `disable-model-invocation` sentence was already wrong before this iteration. It named two repo skills; `check-in` and `eval` also set the field | document defect | sentence rewritten to state the condition, so it no longer goes stale on the next import |
| A count of files inside prose is a stale line waiting to happen. This is the second incorrect membership claim found in the same document in two iterations | agent experience | state the condition, not the membership; the same test to apply to the next such sentence |
| The record shape survives its first real use, with one amendment worth noting: `## Adapted` needs four labelled parts, kept, rewritten, added and dropped, because an adaptation that omits one reads as complete when it is not | process | recorded here; the row's "adaptation as prose" already admits the shape, so no amendment to the row |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/principle-guard-the-context-window/SKILL.md` | the principle, with four executable rules and no editor-facing text |
| `src/reasoning/providers/pi/config/agent/skills/principle-guard-the-context-window/context.sh` | prints tokens used, the declared window, the percentage and the remainder from `$PI_SESSION_FILE` |
| `src/reasoning/providers/pi/config/agent/skills/principle-guard-the-context-window/MAINTENANCE.md` | the first maintenance record: source, adaptation in four parts, and the name |
| `docs/development/prompt-authoring-conventions.md` | the `disable-model-invocation` membership claim replaced with the condition that decides it |
| `scripts/lint/norm-ownership.tsv` | regenerated; the edited sentence reclassified `rule-gated` against `gate:check_frontmatter.sh` |
| `$AGENT_HOME/skills/principle-guard-the-context-window/` | all three files installed, byte-identical to the source |
| `devlog/handovers/archive/20261018-04-workflow-import_context_window_principle.md` | this record |
