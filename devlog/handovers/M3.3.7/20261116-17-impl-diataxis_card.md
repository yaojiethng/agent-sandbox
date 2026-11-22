---
date: 2026-11-16
milestone: M3.3.7 - The principle corpus admission
type: Implementation
status: Closed
---

# Handover - The mode boundary is its own Diataxis card

## Objective

Land part 1 of the cut split as a self-contained card, so the classification and tidying judgement has one rule-shaped carrier and the old card is left to part 2.

## Scope

The new `communication-principle-organize-by-diataxis` skill, the `AGENTS.md` index line, the roadmap's split row and the map's D7 note. In scope: the signpost, the judgement, the four modes, the meaning unit, the boundaries and the test.

Out of scope: part 2, the old card's edit and rename, the `metadata.neighbours` value and the operator-led `intent` and `mechanism`.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The card exists with the settled name, description and `diataxis` leitwort. | Read the frontmatter. | Agent [x] |
| The body carries the judgement, the four-mode table, the meaning unit, the two boundaries and the test. | Read the body; `check_document_shape.sh`. | Agent [x] |
| The metadiscourse boundary names `communication-principle-cut-what-serves-nothing` until it is renamed. | Read `**What it does not cover.**`. | Agent [x] |
| The `AGENTS.md` index carries the card. | Read the index line. | Agent [x] |
| The roadmap splits part 1 closed and part 2 open. | Read the two rows. | Agent [x] |
| The gates hold. | `bash scripts/lint.sh`. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The name is `communication-principle-organize-by-diataxis`. | E4 catches both entries, adding and maintaining, and carries the leitwort. | This record; the card |
| The description leads with both entries and names the four modes. | The signpost has to match an agent's search for a mode. | The card |
| The body is G1, the classification then the application. | The card is the classification authority, and the test is the application. | This record |
| The unit is a meaning unit, defined in the judgement and cited in `**The unit.**`. | Define before use, and borrow a term with a stated source rather than coin one. | This record; the card |
| The `**Why.**` is a motivation that leads with findability. | A skill is procedural, and an explanatory chain is not its job. | This record |
| The metadiscourse boundary keeps the old name until the part 2 edit. | The rename belongs to the edit that makes the name true. | This record; the roadmap |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| The card's `metadata.neighbours` value, starting with the SSOT edge. | The admission field. | `[]` until the admission branch, or `principle-single-source-of-truth` now. |
| The card's operator-led `intent` and `mechanism`. | The field completeness. | The operator supplies them, as with the five pilot cards. |
| Part 2, the old card's edit, rename and field. | The split's completion. | The part 2 roadmap row. |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The shape gate refuses a capitalised `Diataxis` after the first word of a title. | gate | The title is `Organize documentation by mode`, and the name, description and body carry the word. | This record |
| The old card still carries part 1's rules. | record | The duplicate is explicit, and the part 2 row owns its removal. | The roadmap; this record |
| The meaning unit is content-analysis vocabulary. | record | The citation sits in `**The unit.**`, and the literature stays out of the card. | This record |

## Completed

| File | One-line change summary |
|---|---|
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-organize-by-diataxis/SKILL.md` | Adds the Diataxis classification and tidying card. |
| `src/reasoning/agent-runtime/pi/config/agent/AGENTS.md` | Adds the card to the principle index. |
| `devlog/roadmap.md` | Splits the cut row into part 1 closed and part 2 open. |
| `devlog/discussions/20261116-report-concluded-principle_corpus_map.md` | Notes the part 1 landing on the D7 case. |
| `devlog/handovers/M3.3.7/20261116-17-impl-diataxis_card.md` | This record. |
