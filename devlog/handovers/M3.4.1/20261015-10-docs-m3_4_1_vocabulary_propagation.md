---
date: 2026-10-15
milestone: M3.4.1 - The container execution model and the controlled vocabulary
type: Documentation
status: Closed
---

# Handover - M3.4.1: the vocabulary propagation sweep

## Objective

Carry the reserved vocabulary into the live instruction surfaces so `layer` names the container architecture only, leaving the vocabulary gate as the next unit.

## Scope

Targets M3.4.1's row `The vocabulary propagation sweep` (U1).

In: every live instruction surface where `layer` carried a sense the reserved-terms table replaces, which is the implementation stack, `AGENTS.md` scope, instruction roots, record dependency and agent nesting.

Out: U2, the gate, which is the next unit. Historical records are not retro-renamed.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The instruction-root and `AGENTS.md`-scope senses are gone from the live instruction surfaces | `grep -rinE "(provider\|project\|sandbox\|user\|universal\|workflow)[ -]layer"` returns only the Docker build sense | Agent [x] |
| The record-dependency, nesting, delivery and reference senses are replaced | the same grep set | Agent [x] |
| No renamed heading leaves a dead link | `bash scripts/lint.sh` record-links gate | Agent [x] |
| The container-architecture sense is untouched | the capability and reasoning uses, and `two_layer_model.md`, are unchanged | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Instruction roots use "surface" | the repository already uses "instruction surface" | this handover |
| `AGENTS.md` scope names the file | the reserved-terms table in `coding_agent_project_bindings.md` | this handover |
| Record dependency uses "record class" or "record" | the reserved-terms table | this handover |
| Agent nesting uses "levels" | the table reserves "depth"; "two levels" reads cleanly | this handover |
| Delivery uses "boundary" or "paths", and the docs folder is the "reference tree" | neither sense is in the table; both were chosen to free `layer` | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The heading `#skills-and-prompts-layer-model` was renamed to `#skills-and-prompts-surfaces`, and `provider_lifecycle.md` linked it | defect, measured | the link was re-pathed; the record-links gate confirms no other carrier | this record |

## Completed

| File | Change |
|---|---|
| `docs/reference/agent_workflow.md` | the primary carrier: instruction roots and `AGENTS.md` scope moved to surfaces and file names |
| `docs/reference/provider_lifecycle.md` | the skills and prompts surfaces, and the renamed heading's link |
| `docs/reference/system_overview.md` | the project `AGENTS.md` context and the nesting depth |
| `docs/reference/tool_interface.md` | provider state, not a provider layer |
| `docs/reference/execution_model.md` | provider prompts and skills |
| `docs/reference/documentation_taxonomy.md` | record documents, and the rule link |
| `docs/policies/documentation_policy.md` | provider `AGENTS.md` files, and the record-documents heading |
| `docs/policies/iteration_policy.md` | the project `AGENTS.md` inventory |
| `docs/development/prompt-authoring-conventions.md` | the three-surface model, and the reference tree |
| `docs/development/instruction-surface-conventions.md` | the provider and project `AGENTS.md` scope tables |
| `docs/development/provider_onboarding_guide.md` | provider `AGENTS.md` context and model |
| `docs/development/context_resolution.md` | the three-part interface seam |
| `docs/development/standard_operating_procedures.md` | the nesting levels |
| `docs/development/security.md` | the nesting levels |
| `docs/adr/single_source_model_recommendations.md` | the provider and project `AGENTS.md` home |
| `docs/adr/sandbox_delivery_model.md` | the delivery boundary and paths |
| `docs/adr/interface_contract_compatibility.md` | the record-class version |
| `workflow/coding-agent/prompts/bootstrap.md` | the project context |
| `workflow/coding-agent/prompts/document.md` | the provider `AGENTS.md` |
| `.agents/skills/task-list/SKILL.md` | the record class |
| `devlog/roadmap.md` | `active-milestone` set to M3.4.1, and the U1 marker |
