---
date: 2026-10-14
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Design
status: Closed
---

# Handover - The default-convention surface in the module

## Objective

Settle the seam between the coding-agent workflow's fixed maintenance surface and the bindable mechanics behind it, and formalize the maturity chain that guides a convention along that seam.

## Scope

The M3.3.1 row `Establish the default-convention surface in the module`, continuing the binding-surface design at handover `20261014-02`. The scope was re-scoped from implementation to Design on operator direction (2026-10-14): the row's build cannot fix a seam the design left implicit, so this iteration fixes the seam and defers the build.

The settled model: the workflow's fixed unit is the **maintenance surface**, the maintenance skills the prompts invoke, and the bindable unit is the **mechanics** behind it, its storage and format. A convention matures along the chain `rule -> skill -> gate -> binding`, and every stage coexists. The skill is the carrier of all four stages, and the binding contract and the gate stay workflow-owned. The skill specification's four gaps, and the `metadata` / `compatibility` assessment, are recorded in the ADR.

In scope: the ADR section that records the chain, the seam, the three seams and the gaps, and the design document's revised vocabulary, policy split, binding list and consequences.

Deferred with its row: the build - the interface, the `initialize` skill and the completeness gate - stays on the open row. The reserved-terminology carry stays with the T8 vocabulary row, and stopping `bootstrap.md` from copying the policy set rides with the policy retirement.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The maturity chain is recorded with its four stages, its direction, and the coexistence requirement | reading the ADR's new section | Operator [x] |
| The surface/mechanics seam is stated for every maintenance surface, and each surface names no file | `grep -n "devlog/\|docs/"` finds no path in the surface table | Agent [x] |
| The three seams are recorded, each with what stays fixed and what adjusts | reading the ADR section | Operator [x] |
| The skill specification's support and its four gaps are recorded, with the `metadata` / `compatibility` assessment | reading the ADR section | Operator [x] |
| The design document's binding-list and policy-split sections carry the corrected model | reading both; the ADR no longer presents a per-operation interface | Operator [x] |
| Architecture documents in scope describe the system as built | reading the changed sections | Operator [x] |
| `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are clean | run both | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/adr/coding_agent_project_bindings.md`](../../../docs/adr/coding_agent_project_bindings.md) | the fixed surface and bound mechanics decision, the maturity chain, the three seams, and the skill specification's gaps |
| [`devlog/discussions/20261014-design-settled-coding_agent_binding_surface.md`](../../discussions/20261014-design-settled-coding_agent_binding_surface.md) | the corrected model in its vocabulary, policy split, binding list and consequences |
| [`devlog/roadmap.md`](../../roadmap.md) | the row's landing note and write-back at close |
| `devlog/handovers/archive/20261014-04-design-default_convention_surface.md` | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The design record is revised in place, not duplicated | it is the same subsystem, and the ADR links it as the live exploration | this handover |
| No resolution-time defaults: a required binding that is absent fails fast, and the workflow's own values are what the initializer proposes | a silent fallback answers for a project that never decided and masks drift | this handover; the ADR |
| The bindable unit is the mechanics behind a maintenance surface, not a per-operation interface | T5 and T6 change the storage and format behind the surface, so the surface stays fixed and the mechanics adjust | this handover; the ADR |
| The maturity chain `rule -> skill -> gate -> binding` is formalized, with coexistence required | it names the direction of travel and keeps every stage a valid workflow | the ADR |
| The binding contract and its values are our own data file; `metadata` carries at most a lightweight annotation | the skill specification's `metadata` is untyped string-to-string and unvalidated, and `compatibility` is a 500-character environment string; neither can enforce | the ADR |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| `tests/test_model_refresh.sh` invariant M8, recorded out of scope at handover `20261014-02`, is fixed by handover `20261014-03`. The suite's only pre-existing failure is gone. | reference, measured | none - resolved; Triaged to: no destination, fixed by handover `20261014-03` |
| Operator steering (2026-10-14): the surface should not carry lazy runtime defaults; a missing or failed binding should fail fast. Where the workflow needs proposed values, an `initialize` skill populates a project's bindings and ships the default implementations as references. This changes the design's `default corpus` from a resolution-time fallback to the initializer's proposals, and it names `workflow/coding-agent/prompts/bootstrap.md` (which today copies the policy set) as the reframing target. | steering | this iteration; Triaged to: this handover's Decisions table and the ADR |
| Operator steering (2026-10-14): the unit of binding is an **operation and its contract**, not a path or a format. A handover is one fulfilment of `log a work unit`; a date, a monotonic sequence, or no identity (parallel work cannot deconflict a sequence), and a file, stdout, a webhook, or email, are all valid. The "universal mechanics" proposed above were agent-sandbox's fulfilment, not universal. | steering | this iteration; Triaged to: this handover's Decisions table and the ADR |
| Operator steering (2026-10-14): the operation table is the wrong binding granularity; it over-optimizes for variation with no evidence (two implementations of `read_work_unit`). The evidence that exists, T5 (linear-style task tracking, append-only changelog, handover rotation) and T6 (structured task logs), changes the storage and format **behind** the maintenance surface, not the surface. The coming revamp's granularity is the surface as a whole, so the bindable unit is the mechanics behind a maintenance skill, and the maintenance surface stays fixed as a set. The surface must be stated without naming a file, or `roadmap-maintenance`'s dependence on `devlog/roadmap.md` fuses the two and T5 cannot move the file without moving the surface. | steering | this iteration; Triaged to: this handover's Decisions table and the ADR |
| Operator steering (2026-10-14): the design is progressively converting discretion-heavy agent workflows into interface- and contract-heavy ones, toward an end state where a module's skill invokes deterministic scripts. The interface need not abstract in advance; the requirement is that the seams stay open for that adjustment. The one instance already open is `handover-maintenance` (judgement skill) plus `scripts/check_handover_format.sh` (deterministic gate); `roadmap-maintenance` and `doc-maintenance` are judgement only. Seams to leave open: surface vs mechanics; judgement vs determinism within a surface; binding value vs implementation (a mechanics value is a parameter now and a script later, without changing the surface). State the surface's contract so a script could implement it, and keep the mechanics declarative so a script can read them. The script layer itself is out of scope for now. | steering | this iteration; Triaged to: this handover's Decisions table and the ADR |
| Operator steering (2026-10-14): formalize the progression `rule (prose) -> skill (judgement) -> gate (deterministic script) -> binding (project parameters)` as a durable model, and require that workflows at every stage coexist. Measured against `pi`'s skills spec (`docs/skills.md`, the Agent Skills specification): a skill carries all four stages (prose, judgement, a bundled `scripts/` file, and untyped `metadata`), and is project-scoped via `.agents/skills/`, but it supplies no typed input contract, no enforcement (`Most invalid fields produce warnings`), no non-agent execution, and no override (name collisions keep the first discovered). So the skill is the carrier; the binding contract and the gate stay workflow-owned. | steering | this iteration; Triaged to: this handover's Decisions table and the ADR |
| The reserved term `maintenance surface` collides with the idiomatic use in two existing ADRs: `harness_iterative_improvement_loop.md:19` ("the two-pointer maintenance surface") and `interface_contract_compatibility.md:131` ("grows the maintenance surface"). Both are the ordinary "surface area" sense, not the reserved sense. Triaged to: the T8 terminology row, which carries the reserved set. | contradiction, measured | roadmap |
| The ADR's reserved terminology table is not yet carried into [`docs/reference/terminology.md`](../../../docs/reference/terminology.md); the carry has been pending since handover `20261014-02`, and this iteration adds `maintenance surface`, `mechanics` and `maturity chain`. Triaged to: the T8 `layer` vocabulary row, which already names the same carry. | obstacle, measured | roadmap |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../../roadmap.md) | roadmap maintenance check: the roadmap reflects the prior handovers; M3.3.1 is `In progress`, and T12's M8 rows are closed. No maintenance edit was needed. |
| [`docs/adr/coding_agent_project_bindings.md`](../../../docs/adr/coding_agent_project_bindings.md) | new dated section: the fixed maintenance surface and the bound mechanics, the maturity chain, the three seams, and the skill specification's four gaps with the `metadata` / `compatibility` assessment; R2 amended and R3 superseded; the reserved glossary gains `maintenance surface`, `mechanics` and `maturity chain` |
| [`devlog/discussions/20261014-design-settled-coding_agent_binding_surface.md`](../../discussions/20261014-design-settled-coding_agent_binding_surface.md) | the vocabulary, the policy split, the binding list and the consequences carry the corrected model: the surface is fixed, the mechanics are bound, and no run-time default remains |
| `devlog/handovers/archive/20261014-04-design-default_convention_surface.md` | this handover |
