---
date: 2026-10-14
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Design
status: Closed
---

# Handover - The handoff contract

## Objective

Settle how a workflow step names the convention it needs and hands off to the project's convention-skill, and what the agent does when that skill is absent or still a stub.

## Scope

The design stage of the roadmap row **Wire the handoff into each workflow step**. The convention-skill corpus landed at handover `20261014-05`; nothing consumes it yet. This iteration settles the handoff contract and the step-to-convention mapping, and records both. The wiring of the twelve prompts and five maintenance skills is the row's implementation stage and stays out of scope here.

In scope: the form a step uses to name its convention; how the agent resolves the project's convention-skill; the failure modes, being an absent skill, a stub, and a name collision with a shipped skill; the mapping from each workflow prompt and maintenance skill to the convention it needs; and the ADR entry that records the contract.

Out of scope, each with its row: the prompt and skill rewiring (the implementation stage of this row); moving the conventions out of the shipped maintenance skills (`Retire the policy form`); the instruction-root reference gate; dropping the policy bundle.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The handoff form is settled and recorded | reading the design document | Operator [x] |
| Every workflow prompt and maintenance skill is mapped to the convention it needs | the mapping table in the design document | Operator [x] |
| The three failure modes are specified with the agent's action | the design document | Operator [x] |
| The contract is recorded in the ADR | the ADR section | Operator [x] |
| Architecture documents in scope describe the system as built | read the changed sections | Operator [x] |
| `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are clean | run both | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`workflow/coding-agent/prompts/`](../../../workflow/coding-agent/prompts/) | twelve prompts carrying the workflow's own record paths; their convention mapping is settled here |
| [`workflow/coding-agent/skills/`](../../../workflow/coding-agent/skills/) | five maintenance skills carrying the workflow's own record paths |
| [`workflow/coding-agent/skills/initialize/SKILL.md`](../../../workflow/coding-agent/skills/initialize/SKILL.md) | it installs the corpus the handoff resolves against |
| [`docs/adr/coding_agent_project_bindings.md`](../../../docs/adr/coding_agent_project_bindings.md) | the handoff contract is recorded here |
| [`devlog/discussions/20261014-design-settled-handoff_contract.md`](../../discussions/20261014-design-settled-handoff_contract.md) | the design document |
| [`devlog/roadmap.md`](../../roadmap.md) | the row is re-scoped into its design and implementation stages |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The handoff names the convention and its resolution path `.agents/skills/<convention>/SKILL.md` | deterministic; pi keeps the first discovered skill on a name collision, so a name alone would let load order decide | this handover; the ADR |
| When the skill is absent or a stub, the step states the failure and hands control to the agent; the workflow prescribes neither stop nor continue | at that step control has already passed to the agent, which reasons over the failure with its steering | this handover; the ADR |
| The workflow keeps the procedure; the project's convention-skill holds the structure | the workflow imposes nothing | this handover; the ADR |
| The design and implementation stages are separated | the row spans fourteen prompts and six skills, more than one slice | this handover; the roadmap |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The roadmap row is larger than one slice: six skills and fourteen prompts carry the workflow's own record paths. The design stage is separated from the wiring stage per the unit rule. | scope change | current iteration |
| The devlog's `AGENT_FEEDBACK.md` record has no convention in the seven-convention corpus, yet five steps carry it. The fit is a third `work-log` structure, `assets/feedback.md`. | contradiction | next iteration; Triaged to: the ADR and the roadmap |
| [`20261014-design-settled-coding_agent_binding_surface.md`](../../discussions/20261014-design-settled-coding_agent_binding_surface.md) carries `**Status:** settled` while its filename says `draft`, which the discussion naming rule forbids. | contradiction | roadmap |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../../roadmap.md) | roadmap maintenance check: the roadmap reflects the close of handover `20261014-05`; M3.3.1 is `In progress`. No maintenance edit was needed. |
| [`devlog/discussions/20261014-design-settled-handoff_contract.md`](../../discussions/20261014-design-settled-handoff_contract.md) | new: the handoff contract, the step-to-convention mapping, and the failure modes |
| [`docs/adr/coding_agent_project_bindings.md`](../../../docs/adr/coding_agent_project_bindings.md) | new dated section: the handoff names a convention and its path |
| [`devlog/roadmap.md`](../../roadmap.md) | the row is re-scoped into its design and implementation stages |
