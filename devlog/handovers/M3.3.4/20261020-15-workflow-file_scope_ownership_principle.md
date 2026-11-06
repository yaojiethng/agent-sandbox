---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - file the scope-ownership principle

## Objective

File `principle-own-the-scope-you-declare` as the judgement's only home, and leave the conventions pointing at it.

## Scope

The roadmap row **File `principle-own-the-scope-you-declare`**. One landing, with its own propagation.

Out of scope: the three other landings and the four undecided candidates.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Both copies are byte-identical | `diff -q` over the two `SKILL.md` files | Agent [x] |
| The skill reads the unit off the declared scope, not an invented one | read it: a prompt's `Scope`, a skill's `description`, a record's `## Scope` | Agent [x] |
| The section that stated it now points at it | the heading and one pointer paragraph remain; the five prose lines are gone | Agent [x] |
| The top-down-view rule survives the move | it appears in the skill, and the pointer paragraph keeps its one-line summary | Agent [x] |
| The ledger and the map agree with the sources | `--check` and `--groups` clean | Agent [x] |
| The gates are clean | `bash scripts/lint.sh` | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The heading changed from "owns one step" to "owns the scope it declares" | the word step was the ambiguous unit the review rejected; the heading now names the unit the rule reads | the heading |
| The five obligations became a numbered list in the skill | they are a checklist a writer runs, so a list reads better than the sentence the conventions carried | the skill, `## The pattern` |
| The top-down-view rule moved into the skill rather than staying behind | it is the same judgement seen from the other side, and it was stated in the section being replaced | the skill, `## The pattern` |
| The worked case `diff_packaging.md` was not carried into the skill | it is evidence about one flow, and evidence belongs in the record rather than in the rule's home | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The markdown gate caught a doubled blank line my block replacement left behind | result | the gate is doing the work the review would otherwise do by eye | fixed in place before the commit |
| The replaced section ended with a link anchor that the previous landing had already removed | carrier of a removed anchor | the anchor reference went with the paragraph, so no dead link remains | this record |
| The ledger fell from 157 to 152 rows and the judgement count from 71 to 67 | result | the judgement now lives in one skill rather than in four policy lines, which is the milestone's purpose in numbers | this record |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/principle-own-the-scope-you-declare/SKILL.md` | new: the pattern, the three responses, why, and the test |
| `~/.pi/agent/skills/principle-own-the-scope-you-declare/SKILL.md` | the installed copy, byte-identical |
| `docs/development/prompt-authoring-conventions.md` | the section retitled and reduced to one pointer paragraph |
| `scripts/lint/norm-ownership.tsv` | regenerated: 152 rows |
| `scripts/lint/norm-judgements.tsv` | regrouped: five rows dropped, one added |
| `devlog/handovers/20261020-15-workflow-file_scope_ownership_principle.md` | this record |
