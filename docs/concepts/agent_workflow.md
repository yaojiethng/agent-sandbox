# Agent Workflow

This document describes how work gets done in agent-sandbox — the principles the system is built on, the invariants it enforces, and the map of where each part of the workflow is governed. It is the conceptual entry point to the policy system.

The workflow is expressed through three layers: policy documents (authoritative rules), skill files (execution helpers), and prompt templates (session tooling). This document maps what each policy document owns and where the boundaries between them lie.

---

## Core Principles

### Isolation

Each agent session runs two containers: a capability layer (holds working content and produces diffs) and a reasoning layer (runs the agent). The host repository is never mounted — the agent works against a snapshot copied into a shared volume. The operator controls what enters and what leaves.

See [`two_layer_model.md`](two_layer_model.md) for the full architectural rationale.

### Staging

Agents do not modify the repository. All modifications are captured as a diff and staged for review. No change reaches the repository without human approval.

### Reproducibility

Each agent run is reproducible via a container image version, a specific project state, and the configuration used to start the run. Every change is traceable, every run can be replayed, and every decision can be audited.

---

## System Invariants

The system enforces a set of invariants by construction — constraints that hold across all agent runs regardless of configuration. These are defined authoritatively in [`../architecture/security.md`](../architecture/security.md#security-invariants).

In summary: no unreviewed output reaches the repository; no direct mutation of the host repository occurs from inside either container; every change is traceable to an agent run; the operator initiates every run and has final authority over all outputs.

---

## Agent Context Model

Agents are oriented at session start through two sources of context, injected at different points and owned by different parties.

### Provider layer

Each provider supplies an `AGENTS.md` at `providers/<n>/config/AGENTS.md`. This file is seeded into `AGENT_HOME` at container start by `provider-entrypoint.sh`. It orients the agent to its immediate environment: that it is running inside a sandbox container, what input and output channels are available, and what provider-specific tools or commands apply.

Provider-layer content is narrow and environment-specific. It does not carry project workflow, session conventions, or collaboration principles.

### Project layer

Each project commits an `AGENTS.md` at its repository root. This file is discovered by the agent through working-directory lookup at session start. It carries everything project-specific: session workflow, navigation instructions (what to read and in what order), durable operational decisions, and collaboration principles scoped to this project.

Project-layer content is stable across sessions. It is not per-session state — that is carried by the handover. It is not policy — that is carried by the policy documents in `docs/operations/`. It is the orienting layer between the two.

### Reference template

`providers/AGENTS.template.md` is a reference template for authoring provider-layer files. It is not injected, not enforced, and not universal. New providers should use it as a starting point to ensure consistent structure and baseline coverage across provider-layer files. Deviations are permitted where provider-specific behaviour warrants them.

### What this model does not include

There is no harness-level AGENTS.md injected across all providers and all projects. A candidate "universal" layer — content common to every provider-layer file — is captured in the reference template as a recommended baseline, not as a runtime injection. This decision is intentional: the boundary between universal and project-specific content cannot be drawn with confidence until the harness is used across multiple projects with different workflow conventions. The reference template will evolve toward a more precise universal set as that boundary becomes empirically testable.

The `~/workspace/input/brief.md` path was previously used to inject a stub file at session start. This stub carried no substantive content and has been removed. The input channel at `~/workspace/input/` remains available for operator-supplied files (task specs, reference documents); it is not used for agent orientation.

---

## How the Workflow is Expressed

The agent-sandbox workflow is expressed across three layers with a strict authority hierarchy.

### Policy documents

Policy documents are the authoritative source for workflow rules. They describe the current system reality — what the system does, how sessions run, what constraints hold. They are complete in themselves: an agent following only the policy documents should produce correct behaviour.

Rules live in the policy document where they will be read and are most valuable contextually. Duplicate rules across documents are a defect — one document is the canonical owner and the other links to it.

Policy documents live in `docs/operations/`, `docs/architecture/`, `docs/concepts/`, and `docs/development/`. The policy map below names the canonical owner for each area of the workflow.

### Skill files

Skill files are execution helpers. They are consumers of policy documents — they reference the rules defined there, or in specific cases inline a distillation of those rules for context efficiency. Inlining is a deliberate optimisation, not an alternative to documentation: the rule must still exist in a policy document; the inline is a fast path to it.

A constraint that exists only in a skill file is not authoritative. If an operator bypasses the skill, the constraint disappears. If the policy document changes, an inlined copy may become stale — this is acceptable because the inline is explicitly a convenience copy, not the source of truth.

### Prompt templates

Prompt templates are session tooling. Like skill files, they are consumers of policy documents. They structure operator input, reduce session startup cost, and direct the agent to the right policy sections at the right moment. They may reference policy sections by link or inline a distillation for context efficiency, under the same constraints as skill files.

Prompt templates do not contain authoritative rules.

---

## Policy Map

Maps each area of the workflow to its canonical governing document, what that document owns, and what it explicitly does not own. When two documents seem to cover the same area, this table names the canonical owner.

| Workflow area | Canonical document | Owns | Does not own |
|---|---|---|---|
| Session sequencing and loop structure | [`iteration_policy.md`](../operations/iteration_policy.md) | Step order, gate definitions, tag semantics, information gathering pass rules | Handover population rules, roadmap update mechanics |
| Handover lifecycle | [`handover_policy.md`](../operations/handover_policy.md) | Handover format, naming, population rules at each step, scope confirmation rules, pre-close verification | Step sequencing, roadmap update rules |
| Roadmap maintenance | [`roadmap_policy.md`](../operations/roadmap_policy.md) | Roadmap update sequence, task compaction, Trigger B, Trigger A, changelog format, milestone promotion | Handover format, session step definitions |
| Milestone planning (major loop) | [`milestone_policy.md`](../operations/milestone_policy.md) | Story and investigation process, scoping criteria, major loop closure | Minor loop session execution |
| Story lifecycle | [`story_policy.md`](../operations/story_policy.md) | Story creation, lifecycle states, graduation criteria, closure | Investigation evaluation, roadmap entry format |
| Investigation lifecycle | [`investigation_policy.md`](../operations/investigation_policy.md) | Investigation structure, lifecycle states, recommendation format, closure | Story framing, roadmap entry production |
| Documentation rules | [`documentation_policy.md`](../operations/documentation_policy.md) | Folder ownership, document depth and verbosity, linking conventions, read pass economics, policy-vs-skill separation | Workflow sequencing, file registry |
| File registry and index maintenance | [`project_index.md`](../development/project_index.md) | File registry, freeze status, temperature, maintenance trigger rules | Documentation rules, workflow sequencing |
| Security model and invariants | [`security.md`](../architecture/security.md) | Trust boundaries, security invariants, threat assumptions | Operational workflow, session sequencing |
| Execution mechanics | [`execution_model.md`](../architecture/execution_model.md) | Container lifecycle, snapshot pipeline, diff pipeline, provider interface | Security invariants, operator session workflow |
| External contract | [`tool_interface.md`](../architecture/tool_interface.md) | Command shapes, mount guarantees, image naming, execution modes, `.env` variables | Internal implementation, session sequencing |
| Provider AGENTS.md contract | [`provider_onboarding_guide.md`](../operations/provider_onboarding_guide.md) | Provider-layer AGENTS.md structure, authoring steps, reference template location | Project-layer AGENTS.md content, session workflow |

### Boundary notes

**iteration_policy.md and handover_policy.md** are the most adjacent pair. iteration_policy owns the step sequence and gate definitions — when steps run and what makes them complete. handover_policy owns what happens within each step from the handover's perspective — what to populate, what format to use, what constitutes a valid handover at each stage. An agent executing a step reads iteration_policy to know the step exists and what its exit condition is; it reads handover_policy to know how to produce a conforming handover for that step.

**roadmap_policy.md and iteration_policy.md** share the session boundary. Trigger B and compaction rules are defined in roadmap_policy; iteration_policy's step table references them by link. An agent updating the roadmap reads roadmap_policy; an agent opening a session reads iteration_policy, which directs it to roadmap_policy at the moments roadmap updates are required.

**documentation_policy.md and project_index.md** share index maintenance. documentation_policy owns the rules for how documents should be written and structured. project_index.md owns the registry of what documents exist and the rules for keeping it current. Neither owns the other's content.

**security.md and execution_model.md** are adjacent but non-overlapping. security.md defines what must be true — the invariants and trust boundaries. execution_model.md defines how the system achieves those properties — the mechanisms. A change to execution_model.md must be validated against security.md's invariants; a change to security.md's invariants may require changes to execution_model.md.

**provider_onboarding_guide.md and agent_workflow.md** share the agent context model. agent_workflow.md defines the two-layer model and the role of each layer — this is the canonical conceptual description. provider_onboarding_guide.md owns the authoring contract for provider-layer files and references this document for the model rationale.

When a rule appears to exist in two documents in this map, apply the canonical owner test from [`documentation_policy.md`](../operations/documentation_policy.md#audit-checks) to resolve which document is authoritative.

---

## References

| Topic | Document |
|---|---|
| Two-layer architectural model | [`two_layer_model.md`](two_layer_model.md) |
| Security invariants and trust boundaries | [`../architecture/security.md`](../architecture/security.md) |
| Container lifecycle and execution mechanics | [`../architecture/execution_model.md`](../architecture/execution_model.md) |
| External contract: commands, naming, guarantees | [`../architecture/tool_interface.md`](../architecture/tool_interface.md) |
| Session workflow (authoritative) | [`../operations/iteration_policy.md`](../operations/iteration_policy.md) |
| Provider AGENTS.md contract and reference template | [`../operations/provider_onboarding_guide.md`](../operations/provider_onboarding_guide.md) |
| Onboarding and running guide | [`../operations/quickstart.md`](../operations/quickstart.md) |
