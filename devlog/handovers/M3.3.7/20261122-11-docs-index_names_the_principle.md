---
date: 2026-11-22
milestone: M3.3.7 - The principle corpus admission
type: Documentation
status: Closed
---

# Handover - the index names the principle

## Objective

Make the naming rule bite, by changing what the index hands the agent rather than by reading its reply afterwards.

## Scope

The shape of `## Principles` in the shipped surface. Not in scope: a transcript check, which the measurement below retires, and flattening the nesting, which the operator rejected.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The naming rule is read before the list | it is the first paragraph under `## Principles` | Agent [x] |
| Every entry leads with the situation it fires on | 27 entries; none opens with a bare defect phrase | Agent [x] |
| Every entry carries a human label and its slug | `grep -cE '^ +- \*\*[A-Z][^*]+\*\* \(`'` reads 27 | Agent [x] |
| No entry runs past one line | each entry is a single line | Agent [x] |
| The nesting is unchanged | the group and sub-group headings are as before | Agent [x] |
| The corpus is untouched | `check_principle_frontmatter.sh` reads 27 principles, no finding | Agent [x] |
| Gates hold | `lint.sh` clean across 30 gates; `run_tests.sh` 1651 of 1651 | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The row is answered by the index shape, not by a check. | Measured on this session: 44 distinct principle-like names in replies, 36 skills opened, and one real violation, `organize-by-diataxis`, named from the index and never opened. A grep cannot separate a citation from a rename candidate, and it finds the symptom after the reply rather than causing the name at write time. | This record |
| Entries lead with the situation, carry a human label beside the slug, and state the rule no further than one line. | `poteto-mode`, whose wording this surface adopted, gets principles quoted because the name sits in the same line as the moment it fires: "**Attack the Premise** (principle-attack-the-premise). Two or more fixes that share one premise have failed the same gate." A slug alone is a path, and a defect phrase gives the agent nothing to apply. | This record; the surface |
| The naming rule moves above the list. | It is the instruction the list serves, and it was being read after the first entry. | The surface |
| The nesting stays. | The groups are the reader's index; flattening 27 entries into one list costs the grouping the corpus is organised by. | Rejected change |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| A grep over the transcript cannot tell a citation from a candidate name. | Design limit | 34 of this session's named slugs resolve to nothing: they are rename candidates and old names from design chat. As a gate it would fail on design-heavy iterations and be switched off. | Retired with the script |
| The surface states no reminder line, where `poteto-mode` repeats its first move in frontmatter. | Corpus | A per-turn reminder may carry more than the index does; the surface has no field for one. | The roadmap row for the surface's remaining map rows |
| The naming rule's sentence is `poteto-mode`'s, adopted verbatim. | Record | It stays verbatim, and this iteration moved it without changing a word. | This record |

## Completed

| File | One-line change summary |
|---|---|
| [`AGENTS.md`](../../../src/reasoning/agent-runtime/pi/config/agent/AGENTS.md) | The naming rule moves above the list; 27 entries gain a human label, a situation first and one line. |
| [`devlog/roadmap.md`](../../roadmap.md) | The row closes. |
| [`20261122-11-docs-index_names_the_principle.md`](20261122-11-docs-index_names_the_principle.md) | This record. |
