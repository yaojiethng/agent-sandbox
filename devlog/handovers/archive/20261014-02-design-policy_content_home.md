---
date: 2026-10-14
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Design
status: Closed
---

# Handover - Where the policy content lives

## Objective

Settle where the policy content lives once the policy form is retired, what the repository copy becomes, and which path form each instruction root reads.

## Scope

The opening row of the ten the M3.3.1 goal was split into (handover `20261006-04`): `Decide where the policy content lives, and what the repository copy becomes`. The row carries three questions and two named blockers, and this iteration resolves them in one design document. It changes no policy's content, moves no reader, and edits no dockerfile or manifest row; the follow-on rows execute the decision.

The design widened on an operator direction (2026-10-14): the coding-agent module is a portable workflow, run against projects other than agent-sandbox, and a host project may keep its own record layout and formats. A live host project is the evidence: it derived its own policies from the shipped procedures, keeps a sparser handover and ADR format, and runs one roadmap rather than the roadmap, roadmap-future and changelog split.

The decision is framed by the split of every policy into a **mechanism** (how to do it correctly, a core procedure) and a **convention** (the values this project chose, a project binding). The mechanism already exists as a skill or prompt; the policy document duplicates it as prose. The policy form is retired, the mechanism moves into its procedure, and the convention becomes a binding value with a workflow default.

The design document is the deliverable. The row closes when the document resolves, not when a file moves.

Out of scope: the `tests/test_model_refresh.sh` node suite fails at HEAD, before this iteration, on invariant M8 (`anthropic-messages` expected, `openai-completions` returned). It is reproduced at HEAD, recorded in handover `20261014-01`, and outside the surface this iteration changed; it is new work if pursued, not a gap in this close.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The design document exists in `devlog/discussions/` at draft status | `ls devlog/discussions/20261014-design-settled-coding_agent_binding_surface.md` | Agent [x] |
| The ownership split is stated with the placement rule | reading `### The ownership split` | Operator [x] |
| The module map names every unit and places `git` as a tool | reading `### Modules` | Operator [x] |
| All seven policies have their mechanism and convention halves named, one row each | reading `### The policy split` | Operator [x] |
| The binding list is complete and every point is a value or `default` | reading `### The binding list` | Operator [x] |
| The consequences on the M3.3.1 task list are stated, and the deferred binding mechanism is named | reading `## Consequences` | Operator [x] |
| The settled structure is recorded as an ADR, with this feature's terminology reserved in it | `ls docs/adr/coding_agent_project_bindings.md` and its `### Reserved terminology` section | Agent [x] |
| The layer-terminology finding is recorded with its roadmap destination | this handover's Findings table | Agent [x] |
| The design row is closed at the settled document, and the superseded move rows are recorded | `grep -n "Decide where the policy content" devlog/roadmap.md` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/discussions/20261014-design-settled-coding_agent_binding_surface.md`](../../discussions/20261014-design-settled-coding_agent_binding_surface.md) | the deliverable: the design discussion document |
| [`devlog/roadmap.md`](../../roadmap.md) | the design row closes, and the seven move rows are superseded by the split |
| [`docs/policies/`](../../../docs/policies/) | the seven documents whose mechanism and convention halves are separated, read and not moved |
| [`src/build/container-interface.json`](../../../src/build/container-interface.json) | the manifest the default-convention surface must fit |
| [`docs/development/instruction-surface-conventions.md`](../../../docs/development/instruction-surface-conventions.md) | the surface shape a default-convention surface must follow |
| [`docs/adr/module_instruction_payload.md`](../../../docs/adr/module_instruction_payload.md) | the standing payload decision this design extends or amends |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The coding-agent module is a portable workflow, and a host project may keep its own record layout and record formats | operator direction, 2026-10-14; a live host project already runs this way | this handover and the design document |
| The workflow defines a binding surface; the procedure stays fixed and only the values vary | determinism is preserved where it matters and the project keeps its conventions | the design document, `## Decision` |
| Project management is a mandatory capability; the form it takes is modular | the loop cannot run without logging its units, so the ledger is not optional, but its form is a binding | the design document, `### Modules` |
| Every policy splits into a mechanism (core procedure) and a convention (project binding); the policy form is retired | the mechanism already exists as a skill or prompt, and the duplicate prose is the weight | the design document, `### The policy split` |
| Records fall into three persistence classes: work ledger (prunable), project knowledge (durable), rules | losing ledger history loses operational data, losing knowledge loses project context | the design document, `### Persistence classes` |
| `git` is an available tool, not a module or a binding; the workflow is git-native | the core loop's operations are git-shaped, so a delivery-swap interface would buy nothing | the design document, `### Modules` |
| The host interface is two-way: how the tree enters, and how changes leave | operator direction, 2026-10-14 | the design document, `### The binding list` |
| The design defines the binding points; the binding mechanism and its completeness gate are deferred | the host project's own form stands until then; the mechanism is a later row | the design document, `## Consequences` |
| The settled structure is recorded as an ADR, under development until the structural moves land | a principle whose consequences reach beyond the change that introduced it earns an ADR; the design link is removed when the moves complete | `docs/adr/coding_agent_project_bindings.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The provider `AGENTS.md` `## Scope` table names `/opt/sandbox/docs/policies/` as a reachable root and deep-links `documentation_policy.md` at its image path. Both stop resolving when the policy form is retired. | contradiction, measured | next iteration |
| A live host project runs this workflow with its own record layout and formats. It is the evidence that the workflow's structure is a default rather than law, and it names the binding points. | steering, measured | this iteration |
| `record-correction` is referenced only by `devlog/roadmap.md`; no prompt or skill calls it. It is a mechanism with no entry point. | obstacle, measured | roadmap |
| The three direct-git procedures (`merge`, `rebase`, `record-correction`) and the core loop's git use (`wrapup`, `iter`, `check-in`) are the whole git coupling in the instruction surface; `make` appears only as `make test`. | reference, measured | roadmap |
| `tests/test_model_refresh.sh` node suite fails at invariant M8 (`anthropic-messages` expected, `openai-completions` returned). Reproduced at HEAD and recorded in handover `20261014-01`, before this iteration's surface. | obstacle, reproduced | out of scope - new work if pursued |
| The term `layer` carries seven distinct senses across the live tree (container architecture, implementation stack, `AGENTS.md` scope, instruction roots, record dependency, agent nesting, Docker build). Recommended resolution: reserve bare `layer` for the container architecture and qualify or replace the rest. Filed under T8 - Documentation, with the reserved replacements carried in `docs/adr/coding_agent_project_bindings.md`. | contradiction, measured | roadmap |

## Completed

| File | Change |
|---|---|
| [`devlog/discussions/20261014-design-settled-coding_agent_binding_surface.md`](../../discussions/20261014-design-settled-coding_agent_binding_surface.md) | new: the binding-surface design, at draft - the ownership split, the module map, the persistence classes, the policy split, and the binding list |
| [`docs/adr/coding_agent_project_bindings.md`](../../../docs/adr/coding_agent_project_bindings.md) | new: the ADR for the binding surface, under development, with the reserved terminology |
| [`devlog/roadmap.md`](../../roadmap.md) | the design row closed; the six per-policy move rows replaced by the default-convention surface and the policy-form retirement; the readers-outside row replaced by the binding mechanism; the own-tree and bundle rows re-scoped; the `layer` vocabulary row filed under T8 |
| `devlog/handovers/archive/20261014-02-design-policy_content_home.md` | this handover |
