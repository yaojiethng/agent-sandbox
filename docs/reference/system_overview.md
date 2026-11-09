---
reader: [agent, operator]
---

# System Overview

This document describes the high-level architecture of the agent-sandbox system.

The system is a sandbox and execution harness for autonomous coding agents. It provides a controlled environment where agents can read, modify, and test code while maintaining strict boundaries between the agent's working copy and the host repository.

## Core Invariants

These guarantees hold across all agent runs. Defined authoritatively in `docs/development/security.md#security-invariants`:

- Agents execute inside isolated containers
- The host repository is never modified by an agent directly
- All agent output is staged as a diff and requires human approval before being applied
- Agent nesting depth is limited to two layers (parent + child) -- stated here as an architectural guarantee; no operational enforcement exists yet

---

## Architecture Domain Model

The system is described by its domain model. The decision is recorded in the ADR `container_execution_model.md`. The domain is agentic engineering. It divides into sub-domains by execution extent, and each sub-domain divides into planes by environment ownership. A strict bottom-up stabilization rule applies: a plane stabilizes before the next plane above it evolves, and a sub-domain stabilizes before the next sub-domain evolves.

**Sub-domains** divide the domain by how much executes under the harness.

| Sub-domain | Execution extent |
|---|---|
| Infrastructure | the runtime substrate; no agent executes |
| Single-agent execution | one agent runs and produces a diff |
| Multi-agent orchestration | agents coordinate; not started |

**Planes** are the ownership slices within a sub-domain. Each plane owns one concern and has exactly one owner.

| Plane | Responsibility | Owner |
|---|---|---|
| Host substrate | Docker runtime, host filesystem, host tooling | operator |
| Session guarantee | sandbox volume, snapshot, diff pipeline, session record | harness |
| Environment declaration | image, toolchain, dependencies, mounts, volumes, services, lifecycle | contested; the project is the target owner |
| Project data and caches | source, virtual environment, node modules, build cache, logs, database data | project |
| Verification surface | launch, drive, observe, isolate, cleanup, evidence | project, enabled by the harness |

The planes resolve in the order listed. The session guarantee is the invariant boundary of the single-agent sub-domain: it must hold while the planes above and below it change. The environment declaration is the plane the current work moves to project ownership, under that guarantee.

Two elements frame the model without belonging to it:

**Security Model** -- a design constraint applied to every sub-domain and plane. The security requirements are written before implementation and used to harden each part against the threat model. It is not a plane; it is a constraint the implementation must satisfy.

**Human Workflow** -- the outer frame of the system. The operator initiates every run and has final authority over all outputs. No output reaches the repository without human review and approval. This is an invariant of the system design, not a sub-domain that gets built in sequence.

The freeze status is scoped to a plane, never to a file and never to a whole sub-domain once a plane inside it changes. `documentation_policy.md` applies it: architecture documents must not describe what a stable plane does not yet do.

An unfinished plane above is a reason to leave a low plane alone. Settled never means finished for good: it means you can build on the plane today.

### What going around it costs

A low-plane change looks locally correct: tests pass, the diff is small. Four things follow.

1. Changing a plane out of order invalidates the interface that future work relies on, so that work has to be replanned or rescoped.
2. The review cannot catch it: everyone who uses the interface today gets updated in the same change, and the future work is not in the tree to read.
3. Nothing records the crossing, so the rework shows up two milestones on with no account of why.
4. Every document, handover and fixture that describes the old interface goes stale at once, and each one has to be found by hand.

### Which situation you are in

Editing a low plane to get on with the work above it is one of three situations. Each has a test, and a different fix.

1. **The lower plane is not finished.** The work needs a contract the lower plane does not yet state. Finish the lower plane; the higher-plane task waits.
2. **The task belongs to the lower plane.** The change makes sense without reference to the work above it. Rescope the task to the lower plane, and move its roadmap position with it.
3. **The lower plane is being rewritten deliberately.** The rewrite changes an interface that everything above depends on. Make it a task of its own, name what it invalidates, and sequence it against the work above.

A task whose first edit lands below the plane it names is the signal, and it is cheaper to catch before the work starts.

How a document states a plane's state is the `project-documentation` convention's. Which plane work is in flight is the task list's.

## Major Components

**Two-layer container runtime** -- each session runs two containers: a capability layer (sandbox, seed pipeline, diff pipeline) and a reasoning layer (agent runtime, provider-specific). Both are ephemeral and discarded after each run. The capability layer starts first and owns the sandbox volume; the reasoning layer attaches to it via `--volumes-from`.

**Host-side volume seed** -- before the sandbox container starts, a one-shot seeder service (the sandbox image) fills the sandbox volume: repository with index, git-enumerated working tree, and `SESSION_STATE`; the seeder self-verifies and its exit code gates the start. No staging directory and no snapshot mount exist at any point. Details: [copy_delivery.md](../reference/copy_delivery.md).

**Sandbox** -- a named Docker volume owned by the capability layer. Seeded before first use by the helper-container transport. The agent works exclusively in `sandbox/`. Survives stop/resume; removed by prune.

**`.workspace/`** -- a host-side directory providing the I/O channels between containers and host. Subdirectories have distinct owners and trust levels: `input/` (operator-written, reasoning layer read-only), `output/` (agent-written, reasoning layer read-write), `session-diffs/` (harness-written, capability layer read-write -- diff pipeline output).

**Diff and apply** -- on capability layer exit, the diff pipeline produces per-commit `.diff` files, `uncommitted.diff`, `all-changes.diff`, and `changed-files/` into a session-scoped directory under `session-diffs/{session,autosave}/`. The operator runs `make draft` to apply patches to a working branch, or `make apply DIFF=<path>` to apply a diff file directly (unstaged). Host-side `make package-branch` provides equivalent export capability outside the container.

**Per-project config** -- each project has a `SANDBOX_DIR` alongside `PROJECT_DIR` containing a `Makefile`, `.env` (machine-specific, never committed), and a project-committed `AGENTS.md` at the repository root (project `AGENTS.md` agent context -- session workflow, navigation, collaboration principles). Provider-specific agent context is supplied by `src/reasoning/agent-runtime/<n>/config/agent/AGENTS.md` and seeded into `AGENT_HOME` at container start. The provider and project `AGENTS.md` context model is defined in [`../reference/agent_workflow.md`](../reference/agent_workflow.md#agent-context-model).

## Detailed References

| Topic | Document |
|---|---|
| Container lifecycle, seed pipeline, mount shape | [execution_model.md](execution_model.md) |
| Workflow expression model and policy map | [../reference/agent_workflow.md](../reference/agent_workflow.md) |
| Model routing, dispatch state and failure vocabulary | [dispatch.md](dispatch.md) |
| Security guarantees and trust boundaries | `docs/development/security.md` |
| STRIDE threat analysis | `docs/development/threat_model_stride.md` |
| Standard operating procedures | `docs/development/standard_operating_procedures.md` |
