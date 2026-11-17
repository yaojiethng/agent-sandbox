---
date: 2026-11-16
milestone: M3.3.7 - The principle corpus admission
type: Documentation
status: Closed
---

# Handover - The empty neighbour field means none declared

## Objective

Make `[]` mean "no neighbour declared" in the live carriers, so the existing corpus can carry the field without asserting a neighbour set it has not surveyed.

## Scope

The M3.3.7 row **The neighbour field's empty value means "none declared"**. In scope: the field definition in `instruction-authoring`'s `references/skill-conventions.md` and `patterns/admission.md`, and the shape record's matching sentence in `docs/adr/principle_skill_shape.md`. The design record and the plan handover already carry the meaning.

Out of scope: the `[]` declaration on the 25 skills, the baseline deletion, and the survey, which are the following rows. The gate needs no code change: it treats `[]` as a present field.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `skill-conventions.md`, `patterns/admission.md` and `principle_skill_shape.md` say `[]` means "no neighbour declared", and name the survey map as where "surveyed, none" is carried. | Read the three lines; `rg -n "has no neighbour\|declares that the principle has none" .agents/skills/instruction-authoring docs/adr/principle_skill_shape.md`. | Agent [x] |
| The design record and the three live carriers agree on the meaning. | `rg -n "no neighbour" .agents/skills/instruction-authoring docs/adr/principle_skill_shape.md devlog/discussions/20261114-design-concluded-principle_corpus_admission.md`. | Agent [x] |
| The neighbour gate and its test are still green. | `bash scripts/check_principle_neighbours.sh`; `bash tests/test_principle_neighbours.sh`. | Agent [x] |
| Every decision this iteration records is realized in the files. | Read the Decisions table against the three carriers. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `[]` means "no neighbour declared"; "surveyed, none" is carried by the survey map. | The field is a machine index for admission, not a claim that the corpus is mapped. Declaring `[]` on the 25 otherwise asserts a falsehood. | This record; the design record; roadmap P0 |
| The field gets no third value. | A third state would need a gate, a reader and a migration of its own. The distinction lives on the survey map, which is where the corpus's edges are read. | This record |
| The gate's code stays unchanged. | The change is semantic. The gate already treats `[]` as a present, valid declaration; only the words that define it change. | This record |

## Decisions pending

None.

## Findings

None.

## Completed

| File | One-line change summary |
|---|---|
| `.agents/skills/instruction-authoring/references/skill-conventions.md` | `[]` states that no neighbour is declared; the survey map carries "surveyed, none". |
| `.agents/skills/instruction-authoring/patterns/admission.md` | `[]` declares that no neighbour is declared; the survey map carries "surveyed, none". |
| `docs/adr/principle_skill_shape.md` | The shape record's `[]` clause reads "no neighbour declared" and names the survey map. |
| `devlog/roadmap.md` | Marks the `[]` definition row done with its handover. |
| `devlog/handovers/M3.3.7/20261116-08-impl-neighbour_field_empty_meaning.md` | This record. |
