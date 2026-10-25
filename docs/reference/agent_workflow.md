---
reader: [agent]
---

# Agent Workflow

This document describes how work gets done in agent-sandbox -- the principles the system is built on, the invariants it enforces, and the map of where each part of the workflow is governed. It is the conceptual entry point to the policy system.

The workflow is expressed through three layers: policy documents, skill files (execution helpers), and prompt templates (iteration tooling). This document maps what each policy document owns and where the boundaries between them lie.

## Core Principles

### Isolation

Each agent session runs two containers: a capability layer (holds working content and produces diffs) and a reasoning layer (runs the agent). The host repository is never mounted -- the agent works against a snapshot copied into a shared volume. The operator controls what enters and what leaves.

See [`two_layer_model.md`](two_layer_model.md) for the full architectural rationale.

### Staging

Agents do not modify the repository. All modifications are captured as a diff and staged for review. No change reaches the repository without human approval.

### Reproducibility

Each agent run is reproducible via a container image version, a specific project state, and the configuration used to start the run. Every change is traceable, every run can be replayed, and every decision can be audited.

## System Invariants

The system enforces a set of invariants by construction -- constraints that hold across all agent runs regardless of configuration. These are defined authoritatively in `docs/development/security.md#security-invariants`.

In summary: no unreviewed output reaches the repository; no direct mutation of the host repository occurs from inside either container; every change is traceable to an agent run; the operator initiates every run and has final authority over all outputs.

## Agent Context Model

Agents are oriented at iteration start through two sources of context, injected at different points and owned by different parties.

### Provider layer

Each provider supplies an `AGENTS.md` at `src/reasoning/providers/<n>/config/AGENTS.md`. This file is seeded into `AGENT_HOME` at container start by `provider-entrypoint.sh`. It orients the agent to its immediate environment: that it is running inside a sandbox container, what input and output channels are available, and what provider-specific tools or commands apply.

Provider-layer content is narrow and environment-specific. It does not carry project workflow, iteration conventions, or collaboration principles.

### Project layer

Each project commits an `AGENTS.md` at its repository root. This file is discovered by the agent through working-directory lookup at iteration start. It carries everything project-specific: iteration workflow, navigation instructions (what to read and in what order), durable operational decisions, and collaboration principles scoped to this project.

Project-layer content is stable across iterations. It is not per-iteration state -- that is carried by the handover. It is not a rule set -- that is carried by the convention corpus under `.agents/skills/`. It is the orienting layer between the two.

### Model recommendations

The role-to-model recommendations are committed with the project at `.agents/model-recommendations.md`, so a change to which model a role names is a reviewable edit. A container also carries a copy at `${AGENT_HOME:-~/.pi}/model-recommendations.md`, seeded at onboard and read only when the project copy is absent. The project and provider layers name the role vocabulary and the resolution order; the `setup-model-recommendations` skill populates the values, and a role the table does not name is refused by name rather than resolved to a default. [`dispatch.md`](dispatch.md) states the resolution and the launch sites. The decision's source of truth is the ADR `single_source_model_recommendations.md`.

### Reference template

`providers/AGENTS.template.md` is a reference template for authoring provider-layer files. It is not injected, not enforced, and not universal. New providers should use it as a starting point to ensure consistent structure and baseline coverage across provider-layer files. Deviations are permitted where provider-specific behaviour warrants them.

### What this model does not include

There is no harness-level AGENTS.md injected across all providers and all projects. A candidate "universal" layer -- content common to every provider-layer file -- is captured in the reference template as a recommended baseline, not as a runtime injection. This decision is intentional: the boundary between universal and project-specific content cannot be drawn with confidence until the harness is used across multiple projects with different workflow conventions. The reference template will evolve toward a more precise universal set as that boundary becomes empirically testable.

The `~/workspace/input/brief.md` path was previously used to inject a stub file at session start. This stub carried no substantive content and has been removed. The input channel at `~/workspace/input/` remains available for operator-supplied files (task specs, reference documents); it is not used for agent orientation.

### Skills and Prompts Layer Model

Skills and prompt templates follow a parallel three-layer model with distinct loading mechanisms per layer:

| Layer | Source | Loaded via | Update mechanism |
|---|---|---|---|
| **Provider layer** | `src/reasoning/providers/<n>/config/agent/skills&#124;prompts/` | Pi auto-discovery from `~/.pi/agent/skills&#124;prompts/` (config-seeded, survives image rebuild) | `onboard.sh --refresh` or edit `$SANDBOX_DIR/.<provider>/` |
| **Sandbox (workflow) layer** | `agent/skills/`, `agent/prompts/`, and a module's `workflow/<module>/skills&#124;prompts/` | Image-baked at `/opt/workflow/agent/skills&#124;prompts/` and `/opt/workflow/agent/modules/<module>/skills&#124;prompts/`; the `settings.json` `packages` key names both payload roots, and each entry contributes its `skills/` and `prompts/` subdirectories | Image rebuild (`make build`) -- stable baseline independent of working tree |
| **User layer** | `$SANDBOX_DIR/.<provider>/agent/skills&#124;prompts/` | Pi auto-discovery from `~/.pi/agent/skills&#124;prompts/` | Direct filesystem placement by operator |

**Why the sandbox layer is image-baked.** When dogfooding a project, there are potentially two copies of skills and prompts -- one in the working tree (`agent/`) and one baked into the image at `/opt/workflow/agent/`. The image-baked copy provides a stable baseline: even if the working tree is broken mid-development, the core sandbox workflow (session startup, diff/branch packaging, sandbox-awareness) remains functional. This decoupling also ensures portability -- a project using agent-sandbox as a harness inherits these workflow files regardless of what the project's working tree contains.

**Why the sandbox layer cannot rely solely on auto-discovery.** Pi auto-discovers skills from `~/.pi/agent/skills/` and prompts from `~/.pi/agent/prompts/`, and the sandbox-layer files are not seeded there by default because the image bakes them at `/opt/workflow/`. The `settings.json` `"packages"` key bridges the gap: it names the harness payload root `/opt/workflow/agent` and the module root beside it, and pi loads each package's `skills/` and `prompts/` subdirectories as roots, one entry per payload. The sandbox layer therefore depends on that key surviving across sessions, per [Config Flow and Fragility Notes](../reference/provider_lifecycle.md#config-flow-and-fragility-notes).

## How the Workflow is Expressed

The agent-sandbox workflow is expressed across three layers with a strict authority hierarchy.

### Where the rules live

The policy form is retired: no document holds a rule set for the whole workflow. A rule is stated where its procedure enforces it, a convention is stated in the project's convention-skill under `.agents/skills/`, and a judgement used by more than one document is stated in a skill; `### Norm kinds` gives the test for which one a sentence is. Duplicate rules across documents are a defect still -- one place is the source of truth and every other links to it.

The convention corpus is `.agents/skills/`, the reference layer is `docs/reference/`, and the contributor and maintenance documents are `docs/development/`. The protocol that binds the loop's runbooks to each other is [`iteration_protocol.md`](iteration_protocol.md), the one document of the retired form that survived, and the policy map below names the place that specifies each area of the workflow.

The map is the mechanism's, and two of its subjects name this repository's own tree: the three documents under `docs/development/`, and `devlog/AGENT_FEEDBACK.md`. A provisioned project maps the same subjects to the documents it keeps, and `docs/reference/documentation_taxonomy.md` `## Reach` states which folders reach a session.

### Skill files

Skill files are execution helpers, and one of them may be the source of truth for a judgement that more than one document uses; `### Norm kinds` below places it there so one source serves them all. A skill may also inline a distillation of a rule whose source of truth is elsewhere, for context efficiency. Inlining is a deliberate optimisation, not an alternative to documentation: the inline is a fast path to that source, and it names the source of truth. The authoring bar for skill files is in `docs/development/prompt-authoring-conventions.md`.

An inline may become stale when its source of truth changes -- this is acceptable because the inline is explicitly a convenience copy, not the source of truth.

### Prompt templates

Prompt templates are iteration tooling. They structure operator input, reduce iteration startup cost, and direct the agent to the right section at the right moment. A prompt holds the rules its procedure runs, and points at the source of truth of every rule it borrows. The authoring bar for prompt templates is in `docs/development/prompt-authoring-conventions.md`.

### Norm kinds

Every prose sentence in the policy set has one kind and one source of truth. The kind answers whether anything detects a breach. The source of truth answers who produces the content.

**The kind.** Classify in this order.

1. Does the sentence instruct, or does it describe? A sentence that asks the reader to do nothing is a description.
2. If it instructs, name the artifact that fails when the sentence is broken, and resolve it. That artifact is a gate in `scripts/lint.sh`, a file under `scripts/lint/`, a skill directory a prompt dispatches, or a named step in a prompt file. If it resolves, the sentence is a rule and the artifact is its observer.
3. If no artifact resolves, the sentence is a judgement. A guessed observer is not an observer.

| Kind | Does | Detected by |
|---|---|---|
| rule | instructs | an artifact that resolves today, and fails on a breach |
| judgement | instructs how to decide a case | nothing |
| description | states what is | nothing |

**The source of truth.** The document whose workflow produces the content owns it. That does not vary with kind, so a policy holding judgements is normal, because the policy's workflow produces them.

A judgement used by more than one document lives in a principle skill, so one source of truth serves them all. That is the only case where a judgement leaves the document that produces it.

This is the one place the kinds are defined. A document that states one locally links here instead.

### Persistent devlog records (interim)

`devlog/AGENT_FEEDBACK.md` records the agent's feedback and gotchas -- a non-authoritative living record populated at the close review/publish step, distinct from policy documents (authoritative) and from ephemeral per-iteration handovers. Entries are tagged `[A]` (raised by the agent) or `[O]` (raised by the operator). The record is **interim** rather than a durable fixture: a long record signals that a durable fix is due, not an index, and the trim it belongs to is held by the `devlog/roadmap.md#t5---archival` task.

## Policy Map

Maps each area of the workflow to the document that specifies it, what that document owns, and what it explicitly does not own. When two documents seem to cover the same area, this table names the source of truth.

| Workflow area | Document | Owns | Does not own |
|---|---|---|---|
| Iteration sequencing and loop structure | [`iteration_protocol.md`](../reference/iteration_protocol.md) | Step order, gate definitions, tag semantics, information gathering pass rules | Handover population rules, roadmap update mechanics |
| Handover lifecycle | the project's `.agents/skills/work-log/SKILL.md` convention | Handover format, naming, population rules at each step, scope confirmation rules, pre-close verification | Step sequencing, roadmap update rules |
| Roadmap maintenance | the `roadmap-maintenance` skill and the project's `task-list` convention | Roadmap update sequence, task compaction, roadmap maintenance, top-level milestone close, changelog format, milestone promotion | Handover format, iteration step definitions |
| Milestone planning | the project's `task-list` convention and the `/milestone-start` and `/plan` prompts | Milestone states, the record shape, scoping criteria, and the close rules | Iteration execution |
| Agent feedback and gotchas | routing: [`iteration_protocol.md`](../reference/iteration_protocol.md) (close review/publish invariants); record: `devlog/AGENT_FEEDBACK.md` | Entry classification (A/B/C, tagged `[A]`/`[O]`), routing at close, record format and lifecycle (declared in the record file) | Rule authoring, iteration-step sequencing |
| Discussion record types | the `work-log` convention, `.agents/skills/work-log/SKILL.md` | The four types, their statuses, their names and their closure | Iteration sequencing, roadmap entry format, ADR authoring |
| Documentation rules | the `docs` convention, `.agents/skills/docs/SKILL.md` | Folder ownership, the header, the content rules, grep navigation, the per-type obligations | Workflow sequencing |
| Document references | `communication-principle-link-what-the-reader-can-open`, and the project's reference convention where it states one | What to link and what to name, where a link resolves, handoff links, link form | Documentation rules |
| Security model and invariants | `docs/development/security.md` | Trust boundaries, security invariants, threat assumptions | Operational workflow, iteration sequencing |
| Execution mechanics | [`execution_model.md`](../reference/execution_model.md) | Container lifecycle, snapshot pipeline, diff pipeline, provider interface | Security invariants, operator iteration workflow |
| External contract | [`tool_interface.md`](../reference/tool_interface.md) | Command shapes, mount guarantees, image naming, execution modes, `.env` variables | Internal implementation, iteration sequencing |
| Provider AGENTS.md contract | `docs/development/provider_onboarding_guide.md` | Provider-layer AGENTS.md structure, authoring steps, reference template location | Project-layer AGENTS.md content, iteration workflow |

Every cell names its document in the form its reader can open. A document under `docs/reference/` ships beside this one, so its cell is a link. A cell naming a project-only root -- `.agents/skills/`, `devlog/`, `docs/development/` -- names it in a code span, because this document ships into the image at `/opt/sandbox/docs/reference/` and those roots do not travel with it; the rule is the project's linking convention under `.agents/skills/`, and [`documentation_taxonomy.md`](documentation_taxonomy.md) `## Reach` states which roots ship. A cell naming a skill or a prompt names it in a code span for the same reason: it is read at its own image path, not from this document's.

### Boundary notes

**iteration_protocol.md and the record's shape** are the most adjacent pair. iteration protocol owns the step sequence and gate definitions -- when steps run and what makes them complete. The project's `work-log` convention owns the handover's shape, and together they own what happens within each step from the handover's perspective: what to populate, what format to use, what constitutes a valid handover at each stage. An agent executing a step reads iteration protocol to know the step exists and what its exit condition is; it reads the convention to know how to produce a conforming handover for that step.

**The roadmap's rules and the iteration protocol** share the iteration boundary. The transition procedures -- compaction, the top-level close and the promotion invariant -- live in the `roadmap-maintenance` skill. The record's shape, its states, its numbering, its filing rules and its changelog form live in the project's `task-list` convention. The close invariants live in `iteration_protocol.md`. An agent updating the roadmap reads the convention and the maintenance skill; an agent opening an iteration reads `iteration_protocol.md`, which directs it to both at the moments a roadmap update is required.

**The `docs` convention** owns the rules for how documents should be written and structured. It does not maintain a file registry; the docs tree itself is the authoritative list of what exists. Layer freeze status is owned by system_overview.md.

**security.md and execution_model.md** are adjacent but non-overlapping. security.md defines what must be true -- the invariants and trust boundaries. execution_model.md defines how the system achieves those properties -- the mechanisms. A change to execution_model.md must be validated against security.md's invariants; a change to security.md's invariants may require changes to execution_model.md.

**provider_onboarding_guide.md and agent_workflow.md** share the agent context model. agent_workflow.md defines the two-layer model and the role of each layer -- this is the canonical conceptual description. provider_onboarding_guide.md owns the authoring contract for provider-layer files and references this document for the model rationale.

When a rule appears to exist in two documents in this map, decide its source of truth by the kind, per `### Norm kinds`: a resolving observer makes it a rule, and the document that produces the content owns it.

## References

| Topic | Document |
|---|---|
| Two-layer architectural model | [`two_layer_model.md`](two_layer_model.md) |
| Security invariants and trust boundaries | `docs/development/security.md` |
| Container lifecycle and execution mechanics | [`../reference/execution_model.md`](../reference/execution_model.md) |
| External contract: commands, naming, guarantees | [`../reference/tool_interface.md`](../reference/tool_interface.md) |
| Iteration workflow (authoritative) | [`../reference/iteration_protocol.md`](../reference/iteration_protocol.md) |
| Provider AGENTS.md contract and reference template | `docs/development/provider_onboarding_guide.md` |
| Onboarding and running guide | `docs/development/quickstart.md` |
