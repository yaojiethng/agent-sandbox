---
date: 2026-11-16
milestone: M3.3.7 - The principle corpus admission
type: Implementation
status: Closed
---

# Handover - The colocation card is re-signposted around its concept

## Objective

Make `colocation` the card's leading word and keep `proximity` as the effect it produces, so the signpost, the body and the map agree on one concept.

## Scope

`communication-principle-keep-a-subject-near` and the map's D8 entry. In scope: the leitwort, title, description, opening, table header, the `**Where it sits.**` part and the map note.

Out of scope: a file rename or a change to the skill's name, the cut split, the load terms' ownership, and the other cards' fields.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill's `metadata.leitwort` is `colocation`. | Read the frontmatter. | Agent [x] |
| The title, description and body carry `colocation`; `proximity` names the effect. | Read the signpost and the body. | Agent [x] |
| The skill's name is decided and recorded. | Read this record. | Agent [x] |
| The map's entries naming the card record the landing. | Read the map's D8 row and card row. | Agent [x] |
| The gates hold. | `bash scripts/lint.sh`. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Keep the name `communication-principle-keep-a-subject-near`. | The signposting pattern names the act, and `keep a subject near` is its exemplar. The leitwort is the concept the act serves, not a second name. | This record; the map |
| `colocation` is the leitwort and the concept; `proximity` is the effect. | D8 decided the relation. The body states the placement and the effect it produces. | The map; this record |
| `**Where it sits.**` names the information hierarchy, `progressive disclosure`, `findability` and `overload`. | The row places the card in the load concern. The terms stay umbrella words, and the card does not claim one. | This record; the map |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The signposting pattern already uses this card's old word as its bad example. | record | The pattern and D8 agree: name the act, record the concept as the leitwort. | This record |
| A file rename would touch every neighbour list, the map, the roadmap and the index. | record | The name states the act and already matches the pattern, so the rename buys nothing. | This record |

## Completed

| File | One-line change summary |
|---|---|
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-keep-a-subject-near/SKILL.md` | Sets the leitwort, title, description and body to `colocation`, with `proximity` as the effect. |
| `devlog/discussions/20261116-report-concluded-principle_corpus_map.md` | Records the D8 landing. |
| `devlog/roadmap.md` | Marks the colocation row complete. |
| `devlog/handovers/M3.3.7/20261116-15-impl-colocation_leitwort.md` | This record. |
