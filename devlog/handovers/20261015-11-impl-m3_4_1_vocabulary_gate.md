---
date: 2026-10-15
milestone: M3.4.1 - The container execution model and the controlled vocabulary
type: Implementation
status: Closed
---

# Handover - M3.4.1: the vocabulary gate

## Objective

Hold the shipping instruction surfaces to the reserved vocabulary with a check that derives its subjects, so a replaced sense of `layer` fails a gate rather than a review.

## Scope

Targets M3.4.1's row `The vocabulary gate` (U2).

In: the check `scripts/check_vocabulary.sh`, its test, the lint registration, the convention note, and the three provider `AGENTS.md` carriers the check found after U1's commit.

Out: none. Historical records are not retro-renamed.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The gate is registered and clean | `bash scripts/lint.sh` reports 9 gates, the vocabulary gate among them | Agent [x] |
| The gate derives its subjects from the manifest | `scripts/check_vocabulary.sh` reads `container-interface.json`; the test's fixture manifest drives the set | Agent [x] |
| A replaced sense fails, the container-architecture sense passes | `bash tests/test_vocabulary.sh`, 5 cases | Agent [x] |
| The gate fails closed on a missing manifest, no source, or an absent surface | the test cases | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The gate derives its subjects from the manifest's shipped sources, not a hand list | `[A] 2026-10-15 A gate that hand-lists its subject set misses a live root`; derivation makes a new surface scanned without editing the gate | this handover; `docs/development/instruction-surface-conventions.md` |
| The denylist is the replaced senses bound to the noun `layer` | the reserved-terms table is a closed set of senses, so the pattern is total over what must fail | this handover |
| The Docker build use in `tool_interface.md` reads "Provider image", not "Provider layer" | the reserved table keeps Docker's own term, but the image row is clearer without it and the denylist stays unambiguous | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The gate found three carriers in `src/reasoning/providers/pi/config/agent/AGENTS.md` that U1's manual grep missed, because the sweep set omitted the provider config root | defect, measured | fixed here; this is the gap the gate exists to close, and it is why the subject set is derived rather than listed | this record |

## Completed

| File | Change |
|---|---|
| `scripts/check_vocabulary.sh` | the new gate, deriving its subjects from the manifest |
| `tests/test_vocabulary.sh` | five cases: conforming, a replaced sense, the allowed sense, an absent surface, a manifest with no source |
| `scripts/lint.sh` | the gate registered, header updated |
| `docs/development/instruction-surface-conventions.md` | the gate documented, and the intro gate count softened |
| `docs/reference/tool_interface.md` | the Docker build row reads "Provider image" |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | "this layer" to "this surface", "project layer" to the project `AGENTS.md`, "reference layer" to "reference tree" |
| `devlog/roadmap.md` | the U2 marker |
