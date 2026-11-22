---
date: 2026-11-16
milestone: M3.3.7 - The principle corpus admission
type: Implementation
status: Closed
---

# Handover - The existing corpus declares no neighbour

## Objective

Declare `metadata.neighbours: []` on every existing principle and delete the baseline, so the gate holds the corpus with no exception list.

## Scope

The M3.3.7 row **The existing principle skills declare `[]`, and the baseline is deleted**. In scope: the 25 principle `SKILL.md` files under `src/reasoning/agent-runtime/pi/config/agent/skills/`, the gate, its wrapper and its test, the baseline's deletion, and the two records that state the baseline's purpose.

Out of scope: the survey rows. No edge is proposed or declared; the field stays `[]`.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every principle declares `metadata.neighbours`, and the inventory reports 25 principles and 0 findings. | `node scripts/principle_inventory.mjs`. | Agent [x] |
| The baseline is gone and the gate has no baseline or `--update` handling. | `test ! -e scripts/lint/principle-neighbours.baseline`; `rg -n "Baseline" scripts/lint/principle-neighbours.mjs scripts/check_principle_neighbours.sh`; `rg -n -- "--update" scripts/lint/principle-neighbours.mjs scripts/check_principle_neighbours.sh`. | Agent [x] |
| The gate fails a missing field with no baseline present, passes an explicit `[]`, and fails an unresolved, duplicate, self or malformed declaration. | `bash tests/test_principle_neighbours.sh`. | Agent [x] |
| The ADR and the design record state that the baseline is deleted and `[]` means "no neighbour declared". | Read the new ADR entry and the design record's mechanism; `rg -n "baseline" docs/adr/principle_skill_shape.md`. | Agent [x] |
| The lint umbrella and the neighbour test pass. | `bash scripts/lint.sh`; `bash tests/test_principle_neighbours.sh`. | Agent [x] |
| Every decision this iteration records is realized in the files. | Read the Decisions table against the gate, the test and the records. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The existing corpus declares `[]`; the gate has no exception list. | The migration is withdrawn, so the corpus cannot declare real neighbours yet. `[]` is the honest state, and it lets the presence rule hold today. | This record; roadmap P1 |
| The baseline and the gate's `--update` are deleted. | Their only purpose was the pre-migration corpus. With every principle carrying the field, the exception list has nothing left to hold and would hide a future missing field. | This record; the ADR's 2026-11-16 entry |
| The gate keeps presence, liveness and the structural findings; the test becomes the no-baseline suite. | The mechanical half is unchanged. The exception path is the only part removed, and the test asserts its removal by refusing `--update`. | This record; `tests/test_principle_neighbours.sh` |
| A new ADR entry records the change; the 2026-11-14 entry stays historical. | The ADR holds the live decision and its history. The earlier entry's baseline clauses describe a superseded decision, not the current rule. | This record; `docs/adr/principle_skill_shape.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The 2026-11-14 ADR entry still carries its baseline clauses, now historical. | record | A reader who stops at the older entry reads the baseline as live. The new entry at the top states the current decision. | This record; the ADR |
| The P0 handover's scope said the gate needed no code change; P1 removes the gate's exception path, which is a code change. | record | The two rows have different subjects: P0 changed the meaning of `[]`, P1 removes the baseline mechanism. | This record; roadmap P1 |

## Completed

| File | One-line change summary |
|---|---|
| `src/reasoning/agent-runtime/pi/config/agent/skills/*/SKILL.md` | The 25 principle skills declare `metadata.neighbours: []`. |
| `scripts/lint/principle-neighbours.mjs` | Removes the baseline and `--update`; a missing field always fails. |
| `scripts/check_principle_neighbours.sh` | Drops the baseline and `--update` from the wrapper. |
| `tests/test_principle_neighbours.sh` | The no-baseline suite: 7 units, including the refusal of `--update`. |
| `scripts/lint/principle-neighbours.baseline` | Deleted. |
| `docs/adr/principle_skill_shape.md` | Adds the 2026-11-16 entry; the 2026-11-14 entry becomes historical. |
| `devlog/discussions/20261114-design-concluded-principle_corpus_admission.md` | The mechanism states the baseline is deleted and every principle carries the field. |
| `devlog/roadmap.md` | Marks the `[]` declaration row done with its handover. |
| `devlog/handovers/M3.3.7/20261116-09-impl-neighbour_field_empty_declaration.md` | This record. |
