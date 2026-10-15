---
date: 2026-10-14
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Implementation
status: Closed
---

# Handover - The convention-skill corpus

## Objective

Replace the bespoke binding artifacts with the model the operator settled: the workflow ships a default convention-skill corpus, and a handoff to a project convention-skill is the seam.

## Scope

The course correction to the binding-surface work at handover `20261014-04`, on operator direction (2026-10-14). An earlier build in this iteration produced an interface, a project value file and a gate; this iteration replaces them. The settled model:

- A **convention** is a structure over a subset of content. The total list of conventions is the list of subsets a skill must be provisioned for, and a missing provision degrades only the workflows that depend on that subset.
- The workflow ships a **default convention-skill corpus**, not a default convention corpus. Each shipped convention-skill is a stub: a skill is expected here, what was found is a stub, optionally a list of open questions offered without direction. That stub is a specific failure mode for the agent to reason over.
- The workflow imposes nothing. It is a procedural layer; the agent reasons over a failure with the steering it has loaded.
- The workflow-level declaration, kept for maintenance, is the corpus itself: the list of convention-skills the workflow expects.
- `initialize` installs and updates the corpus into the project.

In scope: recording the supersession; withdrawing `workflow/coding-agent/bindings.json`, `.agents/bindings.json`, `scripts/check_bindings.sh`, its test and its lint wiring; adding the stub corpus under the `initialize` skill's `assets/`; reshaping `initialize` to install and update it; and documenting the model.

Out of scope, deferred with their rows: moving the conventions out of the shipped maintenance skills (the conventions/procedure split), which rides with `Retire the policy form`; and any deterministic check over the corpus, which is a later maturity-chain step.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The supersession is recorded: the default convention corpus becomes a default convention-skill corpus, and the handoff is the seam | the ADR's new dated section | Operator [x] |
| The four bespoke artifacts are withdrawn, and no live reference to them survives | the paths are absent, and the reference grep is empty | Agent [x] |
| `scripts/lint.sh` runs its original eight gates | `bash scripts/lint.sh` reports the count | Agent [x] |
| The corpus holds seven conventions, each a stub stating the failure mode and offering questions without direction; `work-log` carries two structures | the directory listing, and reading one stub | Operator [x] |
| `initialize` installs and updates the corpus into `.agents/skills/` | reading the skill | Operator [x] |
| The `communication` standard is recorded as a standard, not a convention, with its home in the project's steering | the ADR | Operator [x] |
| The model is documented, replacing the binding-interface section | reading `instruction-surface-conventions.md` | Operator [x] |
| Architecture documents in scope describe the system as built | read the changed sections | Operator [x] |
| `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are clean | run both | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| `workflow/coding-agent/bindings.json` | withdrawn |
| `.agents/bindings.json` | withdrawn |
| `scripts/check_bindings.sh` | withdrawn |
| `tests/test_check_bindings.sh` | withdrawn |
| [`scripts/lint.sh`](../../scripts/lint.sh) | the bindings gate leaves the umbrella |
| [`workflow/coding-agent/skills/initialize/SKILL.md`](../../workflow/coding-agent/skills/initialize/SKILL.md) | reshaped: it installs and updates the convention-skill corpus |
| [`workflow/coding-agent/skills/initialize/assets/`](../../workflow/coding-agent/skills/initialize/assets/) | the default convention-skill corpus, one stub per convention |
| [`docs/development/instruction-surface-conventions.md`](../../docs/development/instruction-surface-conventions.md) | the model replaces the binding-interface section |
| [`docs/adr/coding_agent_project_bindings.md`](../../docs/adr/coding_agent_project_bindings.md) | the supersession is recorded |
| [`devlog/roadmap.md`](../roadmap.md) | the row write-back at close |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The bindable unit is a project convention-skill, and the seam is a handoff; the interface, the project value file and the gate are withdrawn | a gate is a lint, and a lint over a project's bindings cannot run, because the workflow does not control the project's hooks; a handoff states the need and the failure and leaves the reasoning to the agent | this handover; the ADR |
| The workflow ships stubs, not conventions; each stub states a skill is expected, that what was found is a stub, and offers questions without direction | a run-time default would answer for a project that never chose; the stub is a failure mode for the agent to reason over | this handover; the ADR |
| The corpus is seven conventions: `task-list`, `work-log`, `decision-records`, `docs`, `git-discipline`, `testing`, `evals`, of which `evals` is optional | the list is the set of subjects that carry a maintenance surface; `iteration_policy` is the protocol, not a convention; `verification` and the host interface are core behaviour with no maintenance surface | this handover |
| A convention may cover more than one structure; `work-log` carries the work-unit record and the exploration record | both are ledger records, and the skill's `assets/` holds a file per structure | this handover |
| `documentation_policy`'s two objects split: `docs` is a convention, `communication` is a standard | a convention is a structure over a content subset; the writing rules have no structure and no provision, and they govern all communicated text, so they are a standard read from the project's always-loaded steering | this handover; the ADR |
| `initialize` installs and updates the corpus into `.agents/skills/` | the workflow imposes nothing and seeds the project's own skills | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The design's default-corpus decision is superseded: the workflow ships convention-skill stubs, not convention values, and a handoff to a project skill is the seam. | steering, measured | this iteration; Triaged to: the ADR and the Decisions table |
| `scripts/check_bindings.sh` was wired as a lint gate, but a lint over a project's bindings is not viable: the workflow does not control the project's hooks. The gate is withdrawn. | obstacle, measured | this iteration; Triaged to: the Decisions table |
| `documentation_policy` mixes a convention and a standard: its `## Folder Structure`, `## Format` and `## Document Types` are a structure over the docs subset, while `## Communication Standards` is a practice that reaches chat and code comments, yet the policy's frontmatter scopes it to `docs/` and `devlog/` alone. Split into the `docs` convention and the `communication` standard. | contradiction, measured | this iteration; Triaged to: the ADR and the Decisions table |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../roadmap.md) | roadmap maintenance check: the roadmap reflected the state at this iteration's open; M3.3.1 is `In progress`. No maintenance edit was needed. |
| `workflow/coding-agent/bindings.json`, `.agents/bindings.json`, `scripts/check_bindings.sh`, `tests/test_check_bindings.sh` | withdrawn |
| [`scripts/lint.sh`](../../scripts/lint.sh) | the bindings gate leaves the umbrella, back to eight |
| [`workflow/coding-agent/skills/initialize/SKILL.md`](../../workflow/coding-agent/skills/initialize/SKILL.md) | reshaped: it installs and updates the corpus from `assets/conventions/` |
| [`workflow/coding-agent/skills/initialize/assets/conventions/`](../../workflow/coding-agent/skills/initialize/assets/conventions/) | new: seven convention stubs, each with the failure mode and questions; `work-log` carries `assets/handover.md` and `assets/discussion.md` |
| [`docs/development/instruction-surface-conventions.md`](../../docs/development/instruction-surface-conventions.md) | the binding-interface section becomes `## A module's conventions` |
| [`docs/adr/coding_agent_project_bindings.md`](../../docs/adr/coding_agent_project_bindings.md) | new dated section: the convention-skill corpus and the handoff seam; the reserved glossary gains `convention`, `convention-skill`, `provision` and `default convention-skill corpus` |
| `devlog/handovers/20261014-05-impl-convention_skill_corpus.md` | this handover |
