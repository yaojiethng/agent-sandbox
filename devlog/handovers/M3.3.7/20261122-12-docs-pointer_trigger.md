---
date: 2026-11-22
milestone: M3.3.7 - The principle corpus admission
type: Documentation
status: Closed
---

# Handover - the pointer's description half lands in signposting

## Objective

Answer what can be answered where the corpus already owns it: a skill's description is a pointer, and `signposting` was stating that job in one sentence with a global test. The general pointer rule moves to M3.3.8, whose subject it is.

## Scope

`signposting`'s description paragraph and its test. Not in scope: the principle, the `linking` application and the vendored section, all sliced to M3.3.8.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The description states the pointer's job | the paragraph names the situations, one per branch, in its first words | Agent [x] |
| The test can fail a thin description | it asks per situation, and whether a second phrase names the same one | Agent [x] |
| The slice is written back | the open row sits under M3.3.8 with its mechanism delegated | Agent [x] |
| The gates hold | `lint.sh` clean across 30 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The row's premise is falsified, and the residual is signposting's description half. | `signposting` already stated the rule for a skill's name and description; what it lacked was the branch rule, the first-words order and a test that can fail. | This record |
| The general pointer rule slices to M3.3.8. | M3.3.8 owns the reference and reach layer, and `linking`'s structure applies to it there. | The roadmap |
| The vendored `writing-for-agents` is untouched. | Its context-pointer bullets restate the rule, and the divergence is settled at the next upstream sync rather than by a fork patch today. | This record |

## Decisions pending

| Decision | Options | Where it will land |
|---|---|---|
| None. | None. | This record |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `writing-for-agents`'s context-pointer section restates the rule the corpus will own. | Fork | Two statements of one judgement until the next upstream sync. | `writing-for-agents` |
| The name paragraphs still carry most of the pattern's depth while the description carries three rules. | Content | The seam is stated now (name is identity, description is a pointer), and a later pass can rebalance. | `instruction-authoring` |

## Completed

| File | One-line change summary |
|---|---|
| [`patterns/signposting.md`](../../../.agents/skills/instruction-authoring/patterns/signposting.md) | The description is stated as the pointer, with the branch rule and a per-situation test. |
| [`devlog/roadmap.md`](../../roadmap.md) | The M3.3.7 row closes; the general rule opens under M3.3.8. |
| [`20261122-12-docs-pointer_trigger.md`](20261122-12-docs-pointer_trigger.md) | This record. |
