---
date: 2026-11-14
milestone: M3.3.7 - The principle corpus admission
type: Implementation
status: Closed
---

# Handover - The neighbour field, the admission pattern and the gate

## Objective

Land the admission mechanism's second half: a declared `metadata.neighbours` field, the admission pattern a proposer follows, the citations that reach it, and the gate that holds presence and liveness against a shrinking baseline.

## Scope

The M3.3.7 row **The neighbour field, the admission pattern and the gate**. The design is settled in [`20261114-design-concluded-principle_corpus_admission.md`](../discussions/20261114-design-concluded-principle_corpus_admission.md), and this iteration builds its mechanisms A and B: the field definition, the pattern, the citation from `instruction-authoring` step 1 and from `scope`'s `## Check the boundary`, the gate and its baseline.

The existing principle skills are not populated here; the baseline holds all 25, and the migration row shrinks it. The passthrough principle is the later row that lands through the pattern. Out of scope: the field migration, the passthrough principle, and M3.3.6's corpus map, budget and record layer.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `skill-conventions.md` defines `metadata.neighbours`: full skill names, `[]` declares none, an absent field is undeclared, the list is neighbours only, and the admission pattern decides it. | Read the frontmatter section. | Agent [x] |
| `patterns/admission.md` carries the question, the neighbour search, the case and the operator decision, names the judgement and its modal strength, and contains no "point". | `rg -n "point" .agents/skills/instruction-authoring/patterns/admission.md` returns nothing; read the pattern. | Agent [x] |
| `instruction-authoring` step 1 and `scope`'s `## Check the boundary` cite the admission pattern. | `rg -n "admission.md" .agents/skills/instruction-authoring/SKILL.md workflow/coding-agent/prompts/scope.md`. | Agent [x] |
| The gate fails an unbaselined missing field, an unresolved declared name, a duplicate, a self name and a malformed value; passes an explicit `[]`; fails a baseline entry that now declares the field until `--update` clears it. | `bash tests/test_principle_neighbours.sh`. | Agent [x] |
| The baseline names the 25 existing principle skills, sorted, and the gate is clean on the tree. | `bash scripts/check_principle_neighbours.sh` reports 0 findings; `grep -vc "^#" scripts/lint/principle-neighbours.baseline` is 25. | Agent [x] |
| The gate is registered in `lint.sh` and the umbrella runs it. | `rg -n check_principle_neighbours scripts/lint.sh`; `bash scripts/lint.sh` is clean. | Agent [x] |
| The registry's `## principle skill` entry names the neighbour field and points to the admission pattern. | Read the entry's Relationships. | Agent [x] |
| Every decision this iteration records is realized in the files. | Read the Decisions table against the carriers. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The field is defined in `skill-conventions.md`, the admission pattern lives at `patterns/admission.md`, and the gate is `scripts/check_principle_neighbours.sh` with `scripts/lint/principle-neighbours.baseline`. | The convention owns the frontmatter shape; the pattern owns the decision; the gate owns the mechanical half. The baseline follows the `scripts/lint/code-snippets.baseline` form, a gated copy with one consumer. | This record |
| The gate baselines only `missing-field`; every other structural finding fails, and a baseline entry that gains the field is stale and fails until `--update`. | The baseline makes the check enforceable before the migration; the stale rule forces it to shrink. A duplicate, a self name, a malformed value or an unresolved name is a defect now, not a migration fact. | This record |
| The pattern names the judgement and its modal strength, not a "point". | The signpost iteration settled the word; the admission pattern is the first prose that states what a principle carries, so it says a judgement with a modal strength rather than reusing the retired placeholder. | This record |
| No new ADR. | The concluded design record holds the decision; the field is a convention shape with a gate, not a new architecture decision. | This record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The registry and `scope` linked the admission pattern at a project path, and the linking gate rejected both because `.agents` is outside the image. | record | The shipped reader cannot open the target; the fix names the path in the text and links nothing. | This record |
| The new gate test ended without `test_done`, so the suite read 11 passing units as a crash. | record | The harness's `UNIT:` report is the file contract; `test_done` is added. | This record |
| The explicit-empty fixture also carried an unbaselined missing principle, so it asserted the baseline's presence rather than the empty-list state. | record | The test measured the wrong cause; its baseline now names the missing principle. | This record |
| The closed row still linked the concluded design record, and the record lifecycle gate requires a concluded record to be named by an open row. | record | The record's owner is the open migration row; the link moved there. | This record |
| The first `--update` rewrote the baseline from the tree, so it could grandfather a new principle. | record | The baseline must only shrink; `--update` now refuses to add a name and only drops stale entries. | This record |

## Completed

| File | One-line change summary |
|---|---|
| `devlog/roadmap.md` | Roadmap maintenance check before the handover: no finding; no edit. The row is closed with its handover link, and the design record's owner moved to the migration row. |
| `.agents/skills/instruction-authoring/references/skill-conventions.md` | Defines `metadata.neighbours`: full names, `[]` none, absent undeclared, neighbours only, and the pattern decides the list. |
| `.agents/skills/instruction-authoring/patterns/admission.md` | New pattern: the question, the neighbour search, the case and the operator decision; names the judgement and its modal strength. |
| `.agents/skills/instruction-authoring/SKILL.md` | Step 1 cites the admission pattern where the purpose is settled. |
| `workflow/coding-agent/prompts/scope.md` | `## Check the boundary` cites the pattern when the unit is a principle. |
| `docs/reference/terminology.md` | `## principle skill` names the field and the pattern; "not yet built" is gone. |
| `scripts/lint/principle-neighbours.mjs` | New gate: presence, liveness, duplicates, self names, malformed values, stale baseline; `--update`. |
| `scripts/check_principle_neighbours.sh` | New wrapper. |
| `scripts/lint/principle-neighbours.baseline` | The gated copy: 25 existing principles. |
| `scripts/lint.sh` | Registers the gate; the umbrella runs 28. |
| `tests/test_principle_neighbours.sh` | Eleven cases: baseline, missing, unresolved, duplicate, self, malformed, empty, stale-drop, new-principle refusal, absent baseline, structural refusal. |
| `devlog/handovers/M3.3.7/20261114-05-impl-neighbour_field_admission_gate.md` | This record. |
