---
date: 2026-11-16
milestone: M3.3.7 - The principle corpus admission
type: Implementation
status: Closed
---

# Handover - The cut card becomes the metadiscourse rule

## Objective

Complete the D7 split. The old cut card keeps only the metadiscourse rule, its name says so, and its body states the deletion test the operator accepted.

## Scope

The `cut-what-serves-nothing` skill, its directory and name, the live references, the roadmap part 2 row, the map's D7 case, the principle body convention, the document-shape gate and its tests, and the shape record. In scope: the card, the references, the shape change and the case record.

Out of scope: the Diataxis card, the corpus field values, the card's `metadata.neighbours`, the operator-led `intent` and `mechanism`, and the historical records that cite the old name.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill is `communication-principle-cut-metadiscourse`, with the `metadiscourse` leitwort. | Read the frontmatter and the directory. | Agent [x] |
| The body carries the deletion test, the grain rule, the antipatterns and the signpost boundary. | Read the body; `check_document_shape.sh`. | Agent [x] |
| The rule part is the card's own label, and the other 26 cards pass the role-based gate. | `bash tests/test_document_shape.sh`; `bash scripts/lint.sh`. | Agent [x] |
| The convention and the ADR state the role-based body. | Read `## A principle skill` and the ADR entry. | Agent [x] |
| Every live reference uses the new name. | `grep -rn` the old name across the live trees. | Agent [x] |
| The roadmap part 2 row is `[x]`, and the map records the split complete. | Read both. | Agent [x] |
| The gates hold. | `bash scripts/lint.sh`; `check_principle_neighbours.sh`. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The rule part is the first bold lead-in, and the card names it. | The fixed `**The pattern.**` forced one card's label onto every card. The gate checks the role, not the label. | The convention; the ADR; the gate |
| The judgement is the deletion test. | The taxonomy needed counting, and the deletion test needs only reading. It is the original cut card's test. | The card; this record |
| The signpost is out of scope, and the flow is the scope. | The frame is cheap because the reader can skip it; the flow is a tax on the content. | The card |
| The grain rule replaces the proportion. | The cost is worth paying at the grain where the reader would lose the thread, which is Williams's judgement without the count. | The card; the citation record |
| The antipatterns are places to look, not verdicts. | The deletion test decides, and the three shapes find the candidates. | The card |
| The historical handovers keep the old name. | They record the state at their date. | This record |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| The card's `metadata.neighbours` value. | The admission field. | `[]` until the admission branch, or the Diataxis and clarity cards now. |
| The card's operator-led `intent` and `mechanism`. | The field completeness. | The operator supplies them. |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The fixed `**The pattern.**` label blocked the card's natural order. | convention | The gate is role-based, and the label is the card's. | The convention; the ADR; this record |
| The taxonomy required counting. | record | The deletion test replaces it, and the grain rule replaces the proportion. | The card; this record |
| The shape change needs an ADR entry, where the split's content change did not. | record | The role-based body is recorded in the shape ADR. | The ADR; this record |

## Completed

| File | One-line change summary |
|---|---|
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-cut-metadiscourse/SKILL.md` | Renames and rewrites the card as the metadiscourse rule. |
| `.agents/skills/instruction-authoring/references/skill-conventions.md` | States the role-based body. |
| `scripts/lint/document-shape.mjs` | Checks the rule role, not the label. |
| `tests/test_document_shape.sh` | Updates the order tests to the role-based body. |
| `docs/adr/principle_skill_shape.md` | Records the role-based body. |
| `src/reasoning/agent-runtime/pi/config/agent/AGENTS.md` | Updates the index line and its description. |
| `.agents/skills/project-documentation/SKILL.md` | Updates the cited name. |
| `workflow/coding-agent/prompts/scope.md` | Updates the cited name. |
| `src/reasoning/agent/skills/writing-for-agents/SKILL.md` | Updates the two cited names. |
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-write-for-the-reader/SKILL.md` | Updates the cited name. |
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-single-train-of-thought/SKILL.md` | Updates the cited name. |
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-show-dont-describe/SKILL.md` | Updates the cited name. |
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-maximize-conceptual-leverage/SKILL.md` | Updates the cited name. |
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-organize-by-diataxis/SKILL.md` | Updates the boundary to the new name. |
| `devlog/roadmap.md` | Closes the part 2 row and updates the open citations. |
| `devlog/discussions/20261116-report-concluded-principle_corpus_map.md` | Records the split complete. |
| `devlog/handovers/M3.3.7/20261116-18-impl-metadiscourse_rule.md` | This record. |
