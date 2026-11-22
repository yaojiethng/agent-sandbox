---
date: 2026-11-21
milestone: M3.3.7 - The principle corpus admission
type: Implementation
status: Closed
---

# Handover - The bare `unit` qualifiers and the retired `metadata.unit` row

## Objective

Retire the `metadata.unit` field-and-gate row and qualify every bare `unit` in the work, test and table senses across the files that row named.

## Scope

Two halves in one iteration. The rescope removes the field-and-gate child and its parent from M3.3.7, leaving the bare-noun sweep as a single top-level row. The implementation qualifies the bare head-noun uses in the `testing` convention, `test_harness_mechanism.md`, `dispatch`, `guard-the-context-window`, `git-discipline`, `change_pipeline.md`, `workflow_statechart.md` and `justify-materialization-cost`. The provenance of the retired row is commit `6e11d93a` and handover `20261119-05`; its parent merge is `2da3b6fd` and handover `20261120-04`.

Out of scope: writing `metadata.unit` on the 28 principle cards, any W2 work, and the allowed compounds `unit test`, `unit suite`, `unit-test` and `test unit`, which the terminology Usage rule says stand as they are.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The field-and-gate row is absent from the roadmap. | `grep -c 'Declare the language unit on each principle' devlog/roadmap.md` reads 0. | Agent [x] |
| No live roadmap row names `metadata.unit`. | `grep -c 'metadata.unit' devlog/roadmap.md` reads 0. | Agent [x] |
| The qualification sweep is one top-level row and is marked complete with its outcome. | `grep -n '^- \[x\] \*\*Qualify the bare' devlog/roadmap.md` reads 1. | Agent [x] |
| The parent row no longer names the field or the two halves. | `grep -c 'and the field that declares which unit a card inspects' devlog/roadmap.md` reads 0. | Agent [x] |
| Every bare `unit` in the work and test senses is qualified in the eight named files, and the table sense names the column. | A `grep -n '\bunit\b'` read over each file shows only the allowed compounds and the qualified terms. | Agent [x] |
| The record gates pass. | `bash scripts/check_handover_format.sh` and `bash scripts/lint.sh` are clean. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The `metadata.unit` field and its gate are dropped. | No procedure reads the field; the gate can read presence and closed-list membership but not whether the declared unit matches the body; W2's leitwort row already declined the same shape; and the unit is already stated in the mechanism prose. | This record, and the roadmap. |
| The bare-noun qualification sweep lands as a single top-level row and closes with this iteration; its parent is removed. | With the field half gone, a parent plus one child would state one row twice. The sweep is work in its own right with a named file set and a record outcome. | [`devlog/roadmap.md`](../../roadmap.md). |
| The test sense takes `test unit`, the work sense takes `work unit`, and the table sense names the column. | Those are the qualifiers the terminology Usage rule names for the work and test senses; the table sentence was saying the column is the unit, so leading with the column states it directly. `unit test`, `unit suite`, `unit-test` and `test unit` are allowed compounds and stay unchanged. | The eight edited files, and `docs/reference/terminology.md` `## Usage`. |
| No ADR. | A record decision with no interface, gate or contract. The standing rule against a metadata field whose only reader is its gate is already carried by `principle-justify-materialization-cost` and `[O] 2026-10-24`. | This record. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The field-and-gate row was opened by the agent in `6e11d93a`, not by an operator directive. Handover `20261119-05` records the split as the agent's: "The field and its gate are deferred to their own row... a required field over 27 principles is a rollout and not a definition." The operator later directed only the parent's merge, in `20261120-04`. | Record | No operator ask stands behind the field itself, so its necessity rests on the agent's rollout argument alone. | This record. |
| No procedure reads `metadata.unit`. The only named consumer is the gate that would hold its presence, and that gate can read presence and membership in a closed list, never whether the declared unit matches the unit the body inspects. | Record | A stored value whose only reader is its own gate is the registry-nobody-reads class named by `[O] 2026-10-24` and priced by `principle-justify-materialization-cost`; it can be wrong with nothing reporting it. | This record. |
| W2's row on `metadata.leitwort` already settles the same shape: "A gate over the field is unfiled, because presence is all a gate can read and no gate sees a thinking trace." The unit field is the same kind of metadata and the same argument applies. | Record | The project has already declined a gate over a per-principle metadata field for this reason, so the field row contradicts a live ruling without naming it. | This record. |
| M3.3.7's `Not in scope` excludes "W2's communication-domain taxonomy and leitwort population, which own the controlled vocabulary", while the field assigns a controlled-vocabulary term to every principle. | Record | The row sits in a milestone that has excluded the class it belongs to; either the row or the exclusion is wrong. | This record. |
| The row's count is uncited and internally inconsistent: it reads "19 of the 28 principles" but its mechanism still says "`metadata.unit` on the 18". The count moved from 18 of 27 to 19 of 28 in `2da3b6fd` when the act rule landed, and the mechanism was not updated. | Record | A row whose premise is a count cites no command, and its two numbers disagree. | This record. |
| The unit is already stated in the body's mechanism wording, so a declared `metadata.unit` restates it. | Record | The stored field is a second source for a fact the leaf already carries. | This record. |

## Completed

| File | One-line change summary |
|---|---|
| [`devlog/roadmap.md`](../../roadmap.md) | The `metadata.unit` field-and-gate child and its parent are removed; the bare-noun qualification sweep becomes a single top-level row and closes with its outcome. |
| [`.agents/skills/testing/SKILL.md`](../../.agents/skills/testing/SKILL.md) | The test-unit contract and harness are qualified, and the sweep and assertion advice read `test unit`. |
| [`.agents/skills/testing/patterns/assertions.md`](../../.agents/skills/testing/patterns/assertions.md) | Every bare test-sense `unit` in the assertion rules reads `test unit`. |
| [`.agents/skills/testing/patterns/structure.md`](../../.agents/skills/testing/patterns/structure.md) | The per-behaviour count and its heading read `test unit`. |
| [`.agents/skills/testing/patterns/mutation-evidence.md`](../../.agents/skills/testing/patterns/mutation-evidence.md) | The mutation questions read `test unit`. |
| [`.agents/skills/testing/references/test-homes.md`](../../.agents/skills/testing/references/test-homes.md) | The test-unit harness is qualified; the allowed `unit suite` and `unit test` compounds stay. |
| [`docs/development/test_harness_mechanism.md`](../../docs/development/test_harness_mechanism.md) | Every bare test-sense `unit` in the runner, suite and result contract reads `test unit`. |
| [`dispatch/SKILL.md`](../../src/reasoning/agent-runtime/pi/config/agent/skills/dispatch/SKILL.md) | The work unit the caller commits and lands is named. |
| [`principle-guard-the-context-window/SKILL.md`](../../src/reasoning/agent-runtime/pi/config/agent/skills/principle-guard-the-context-window/SKILL.md) | The capacity rule names the work unit each pass counts. |
| [`git-discipline/SKILL.md`](../../workflow/coding-agent/skills/git-discipline/SKILL.md) | The atomic and blameable rules name the work unit. |
| [`docs/reference/change_pipeline.md`](../../docs/reference/change_pipeline.md) | The recovery clause names a work unit's claim. |
| [`docs/reference/workflow_statechart.md`](../../docs/reference/workflow_statechart.md) | The partial-recovery transition names the work unit. |
| [`principle-justify-materialization-cost/SKILL.md`](../../src/reasoning/agent-runtime/pi/config/agent/skills/principle-justify-materialization-cost/SKILL.md) | The table is classified by column, and the prose value belongs to another artifact. |
| [`20261121-01-impl-unit_qualification_sweep.md`](20261121-01-impl-unit_qualification_sweep.md) | The ruling, its provenance, the sweep and the evidence. |
