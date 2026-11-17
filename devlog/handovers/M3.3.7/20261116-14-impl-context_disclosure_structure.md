---
date: 2026-11-16
milestone: M3.3.7 - The principle corpus admission
type: Implementation
status: Closed
---

# Handover - The context disclosure structure lands on its carriers

## Objective

Land the confirmed `context disclosure` structure so the six principle skills carry it, and an agent reading one card sees the umbrella and its position without the survey map.

## Scope

The six reader-context principles, their `metadata.neighbours` and bodies, and the map's edge section. In scope: the `context disclosure` umbrella, the `correct disclosure` and `sentence context` NTs, the two RT neighbours, the field values and the body paragraphs.

Out of scope: the other families' field values, the 20 unratified `intent` and `mechanism` values, and the link normalisation. The field is populated per family as each landing iteration closes.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The six cluster skills declare the other five in `metadata.neighbours`. | Read the six frontmatter blocks; run `scripts/check_principle_neighbours.sh`. | Agent [x] |
| The six bodies name `context disclosure` and the card's position, NT or RT. | Read the six bodies. | Agent [x] |
| The map records the cluster as landed on its carriers. | Read `## The edges` in the map. | Agent [x] |
| The shape gate holds with no exception list. | `scripts/check_principle_neighbours.sh`; `bash scripts/lint.sh`. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The field carries adjacency, and the map carries the relation kind. | `metadata.neighbours` is a list of full skill names, so it cannot hold BT, NT or RT. The map is the authority for the kind. | The convention; the map; this record |
| The six cards name each other. | The confirmed structure is one connected component, and RT is symmetric, so every card's judgement touches the other five. The field is the admission search's index, and the clique is the honest index of the component. | This record |
| The body gains `**The family.**` beside the scope parts. | The agent reads the card, not the map, so the umbrella and the card's position belong in the body. | This record |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Whether the field should carry the full component or the pair-local edge only. | The precedent for the other six families. | The clique, as landed, or a sparse pair-local declaration. The operator reviews at the close. |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The survey's field rule leaves the landing to the admission decision. | record | The cluster row is that admission, so the field lands here and the survey map stays the edge record. | This record; the convention |
| The body already names neighbours in `**What it does not cover.**` | record | The new paragraph names the umbrella, which the existing prose does not. No prose link is promoted to the field on its own. | This record |

## Completed

| File | One-line change summary |
|---|---|
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-define-terminology-before-use/SKILL.md` | Declares the five neighbours and names the `correct disclosure` position. |
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-write-for-the-reader/SKILL.md` | Declares the five neighbours and names the `correct disclosure` position. |
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-link-what-the-reader-can-open/SKILL.md` | Declares the five neighbours and names the `correct disclosure` position. |
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-attach-as-you-read/SKILL.md` | Declares the five neighbours and names the `sentence context` position. |
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-single-train-of-thought/SKILL.md` | Declares the five neighbours and names the RT position. |
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-keep-a-subject-near/SKILL.md` | Declares the five neighbours and names the RT position. |
| `devlog/discussions/20261116-report-concluded-principle_corpus_map.md` | Records the cluster as landed on its carriers. |
| `devlog/roadmap.md` | Marks the cluster row complete. |
| `devlog/handovers/M3.3.7/20261116-14-impl-context_disclosure_structure.md` | This record. |
