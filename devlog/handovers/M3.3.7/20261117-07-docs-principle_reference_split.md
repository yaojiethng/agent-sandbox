---
date: 2026-11-17
milestone: M3.3.7 - The principle corpus admission
type: Documentation
status: Closed
---

# Handover - One reference for a principle skill, and one runbook for a change

## Objective

Split the corpus's rules by mode, so one reference owns what a principle skill carries and one runbook owns the change, the general skill file states no principle rule, and the two records that outlived their tasks retire with their conclusions in the ADR.

## Scope

The M3.3.7 row, the principle corpus's rules are split across two documents and a general skill file. Row 390, the just-in-time judgement, stays parked as the change runbook's first application.

Both records die here, on the operator's release, with the admission design's conclusion written into the ADR first.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `skill-conventions.md` states no principle rule. | Read its two principle lines: one pointer, and the leitwort principle's name. | [x] Accepted. The frontmatter paragraphs and the `## A principle skill` section are gone; the pointer replaces them. |
| The reference exists and carries the six fields, the body and the five questions. | Read `references/principle-skills.md` against the frontmatter gate's required set. | [x] Accepted. Six rows, one per field, with the gate's half stated. |
| The gate's header and the lint module point at the reference. | `grep -n "principle-skills" scripts/check_principle_frontmatter.sh scripts/lint/principle-frontmatter.mjs`. | [x] Accepted. Both name the reference; the gate reports 26 principles, 0 findings. |
| The runbook points at the reference and names the inventory as the index. | Read `runbooks/principle-change.md`; `grep "corpus_map" .agents`. | [x] Accepted. The map paragraph is replaced by the inventory call and the reference. |
| Both records are deleted and no live file links them. | `git status --short`; `bash scripts/lint.sh`. | [x] Accepted. Lint clean across 29 gates; the roadmap's sub-milestone intro names the runbook instead. |
| The ADR records the runbook as the mechanism and carries the replay evidence. | Read the 2026-11-17 entry. | [x] Accepted. It names the two files, the four replay cases, the two later admissions, and the record disposition. |
| The roadmap carries the row closed and row 390 parked without the deleted records. | `git diff <iteration-base> -- devlog/roadmap.md`. | [x] Accepted. |
| Every decision this iteration records is realized in the files. | Read each `## Decisions` row against the tree. | [x] Accepted. |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The split is by mode: one how-to and one reference, both under `instruction-authoring`. | A procedure and a reference are two modes of one subject, which the organization principle asks for. The alternative, holding the rules inside the runbook, buries the field rules behind a procedure a reader may not be running. | This record; the ADR's 2026-11-17 entry. |
| `skill-conventions.md` stops carrying any principle rule, including the `disable-model-invocation` sentence. | A rule about principle skills in a file about every skill is the split responsibility the operator named. One pointer sentence replaces it. | This record; the file. |
| Both concluded records are deleted now, with the admission design's conclusion in the ADR. | The operator's release. The map's index role passed to `scripts/principle_inventory.mjs`, and the design's operating content is the runbook, so no task was left for either record. | This record; the ADR; the two deletions. |
| The record lifecycle's gap has a disposition here, not a new rule. | A concluded record that becomes standing reference is deleted once its conclusion is in the ADR, which is what the design concluded into. | This record; the ADR's edge cases. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The `## A principle skill` section was cited by two script headers and one lint module, so the move had three code carriers a document-only split would have missed. | propagation | The gate and the lint module name the reference now; the section name is gone from the tree. | The two scripts and the deleted section. |
| `skill-conventions.md` still names `communication-principle-maximize-conceptual-leverage`, because the leitwort rule is general and that principle supplies the word. | boundary | One principle name survives in the general file, and it is a citation rather than a rule. | Accepted as it stands. |
| The roadmap's sub-milestone intro pointed at the admission design as M3.3.7's mechanism. | drift | Deleting the record would have left the sub-milestone naming a dead file. | The intro line, which names the runbook now. |
| `card` is gone from the live surface, finishing the term's removal that iteration 06 began. | record | The two ADRs and the general skill file no longer carry the word. | This record. |

## Completed

| File | One-line change summary |
|---|---|
| `.agents/skills/instruction-authoring/references/principle-skills.md` | New: the six fields with the gate's half, the body, the exemplar and the five questions. |
| `.agents/skills/instruction-authoring/references/skill-conventions.md` | The principle paragraphs and section are gone, replaced by one pointer. |
| `.agents/skills/instruction-authoring/runbooks/principle-change.md` | Points at the reference; the map paragraph becomes the inventory call. |
| `.agents/skills/instruction-authoring/SKILL.md` | Step 2 and the carries table name the reference. |
| `docs/adr/principle_skill_shape.md` | New entry: the runbook is the mechanism, the reference owns the fields, both records retire, and the replay is the evidence. |
| `scripts/check_principle_frontmatter.sh` | Its header names the reference. |
| `scripts/lint/principle-frontmatter.mjs` | Its header names the reference. |
| `devlog/discussions/20261116-report-concluded-principle_corpus_map.md` | Deleted. |
| `devlog/discussions/20261114-design-concluded-principle_corpus_admission.md` | Deleted, its conclusion in the ADR. |
| `devlog/roadmap.md` | The row closes, row 390 is parked without the records, and the sub-milestone intro names the runbook. |
| `devlog/handovers/M3.3.7/20261117-07-docs-principle_reference_split.md` | This record. |
