---
date: 2026-11-22
milestone: M3.3.7 - The principle corpus admission
type: Documentation
status: Closed
---

# Handover - the metaphor case and its home

## Objective

Resolve the metaphor row that stood in two principles, and give the aphorism case a literal phrase to replace.

## Scope

The metaphor row in `provide-evidence` and `align-the-mental-model`, the edge between `align-the-mental-model` and `maximize-conceptual-leverage`, and the aphorism row. Not in scope: the personification half of the old row, held out of the corpus for now.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| One principle states the metaphor case. | `provide-evidence` has no metaphor row; `align-the-mental-model` has it. | Agent [x] |
| The other side keeps its own case. | `maximize-conceptual-leverage` still reads "a metaphor standing in for the mechanism \| the mechanism, or the leitwort that names it". | Agent [x] |
| The two principles are neighbours. | Each lists the other; the frontmatter gate reads 28 principles, 0 findings. | Agent [x] |
| The aphorism row shows its fix. | The row quotes "wire it or delete it" against "connect it to the entry point, or delete the file". | Agent [x] |
| The gates hold. | `check_principle_frontmatter.sh`, `lint.sh`. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The metaphor row lands in `align-the-mental-model`. | A metaphor is a second name for a thing that already has one, which is that principle's failure. | The skill |
| `maximize-conceptual-leverage` keeps its row unchanged. | A metaphor with no name behind it is the one case that earns a place, and only as a leitwort, defined once. | The skill |
| The `**Voice.**` clause that took the personification case is reverted. | It framed flourish as an agency fault; the concern is the flourish, and the surface keeps only the active-voice rule. | Reverted |

## Decisions pending

| Decision | Options | Where it will land |
|---|---|---|
| Where personification goes. | Beside the metaphor in `align-the-mental-model`, a personified artifact being a second name for the part that acts, or nowhere for now. | `communication-principle-align-the-mental-model` |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The personification half of the old row is out of the corpus. | Content | "the plan holds it" has no stated owner; the metaphor row does not cover it cleanly. | The pending decision above. |
| The three unslop items are stated in no principle as a rule. | Content | Rules 27, 32 and 33 reach the corpus as table rows and one moved case, not as a stated rule. | `communication-principle-provide-evidence` |

## Completed

| File | One-line change summary |
|---|---|
| [`communication-principle-align-the-mental-model/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-align-the-mental-model/SKILL.md) | Gains the metaphor row and its first neighbour edge. |
| [`communication-principle-maximize-conceptual-leverage/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-maximize-conceptual-leverage/SKILL.md) | Gains the reciprocal edge. |
| [`communication-principle-provide-evidence/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-provide-evidence/SKILL.md) | Drops the metaphor row; the aphorism row is quoted. |
| [`devlog/roadmap.md`](../../roadmap.md) | The iteration row closes. |
| [`20261122-09-docs-metaphor_home.md`](20261122-09-docs-metaphor_home.md) | This record. |
