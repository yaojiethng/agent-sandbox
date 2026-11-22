---
date: 2026-11-16
milestone: M3.3.7 - The principle corpus admission
type: Implementation
status: Closed
---

# Handover - The vendored skill carries the refined two-load definitions

## Objective

Correct the `writing-for-agents` two-loads section so it states the definitions the map settled, with the citations and the umbrella words, and stop calling cognitive load a cost that is not to be minimised.

## Scope

The vendored skill's `## The two loads` section and the map's document-load paragraph. In scope: the two definitions, the party each bears on, the failure and benefit words, the three Sweller citations, the retrieval literature and the corrected pointer sentence.

Out of scope: the load-level terms' ownership, the card leitworts, and the vendored skill's other sections.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Context load is the retrieval and volume cost, with `overload`, `findability` and the three moves. | Read the section. | Agent [x] |
| Cognitive load is the reasoning cost, with `extraneous load` and the clarity moves. | Read the section. | Agent [x] |
| Both loads bear on the person and the agent. | Read the section. | Agent [x] |
| The three Sweller citations and the retrieval literature are stated. | Read the section. | Agent [x] |
| The map's link points at the corrected skill. | Read the map paragraph. | Agent [x] |
| The gates hold. | `bash scripts/lint.sh`. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The two loads are distinguished by what they tax, not by which party pays. | The old split gave context load to the agent and cognitive load to the human. The map found both bear on both. | This record; the map |
| The old sentence "Not a cost to minimise" is removed. | It treated cognitive load as a price to spend rather than a cost the clarity rules reduce. | This record |
| The citations are stated once, at the section. | The map already holds them; the reader of the skill needs the source beside the definition. | This record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The section's old pointer sentence said in-file material rides on cognitive load. | record | Material with no pointer stays loaded, which is context load, so the sentence now says that. | This record |
| The load terms are umbrella words, not card leitworts. | record | The section names them while the cards keep `colocation` and `SSOT`; a future card that claims one defines it in its body. | The map; the load-level-terms row |

## Completed

| File | One-line change summary |
|---|---|
| `src/reasoning/agent/skills/writing-for-agents/SKILL.md` | Replaces the two-loads section with the refined definitions, the party note, the citations and the corrected pointer sentence. |
| `devlog/roadmap.md` | Marks the two-loads row complete. |
| `devlog/handovers/M3.3.7/20261116-16-impl-writing_for_agents_two_loads.md` | This record. |
