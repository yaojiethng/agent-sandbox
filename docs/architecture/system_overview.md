# System Overview

This document describes the high-level architecture of the agent-sandbox system.

The system is a sandbox and execution harness for autonomous coding agents. It provides a controlled environment where agents can read, modify, and test code while maintaining strict boundaries between the agent's working copy and the host repository.

---

## Core Invariants

These guarantees hold across all agent runs. Defined authoritatively in [`security.md`](security.md#security-invariants):

- Agents execute inside isolated containers
- The host repository is never modified by an agent directly
- All agent output is staged as a diff and requires human approval before being applied
- Agent nesting depth is limited to two layers (parent + child)

---

## Architecture Layer Model

The implementation stack has three layers with a strict bottom-up stabilization rule: lower layers must stabilize before higher layers evolve, and refactors are always bottom-up.

| Layer | Name | Responsibility |
|---|---|---|
| 0 | Infrastructure | Docker runtime, filesystem, container environment |
| 1 | Execution Mechanics | How a single agent runs tasks and generates diffs |
| 2 | Orchestration | Coordination between multiple agents |

Two elements frame the stack without belonging to it:

**Security Model** — a design constraint applied to all implementation layers. The security spec is written before implementation and used to harden each layer against the threat model. It is not a build layer; it is a specification that the implementation must satisfy.

**Human Workflow** — the outer frame of the system. The operator initiates every run and has final authority over all outputs. No output reaches the repository without human review and approval. This is an invariant of the system design, not a layer that gets built in sequence.

Current layer freeze status is tracked in [`docs/development/project_index.md`](../development/project_index.md).

---

## Major Components

**Two-layer container runtime** — each session runs two containers: a capability layer (sandbox, snapshot pipeline, diff pipeline) and a reasoning layer (agent runtime, provider-specific). Both are ephemeral and discarded after each run. The capability layer starts first and owns the sandbox volume; the reasoning layer attaches to it via `--volumes-from`.

**`.snapshot/`** — a host-side directory rebuilt before each run by `start_agent.sh`. Contains a `baseline.tar` (from `git archive HEAD`) and an rsync copy of the operator's working tree. Mounted read-only into the capability layer. Never mounted into the reasoning layer.

**Sandbox** — a Docker anonymous volume owned by the capability layer. Initialised at container start from `.snapshot/`: baseline commit first (from `baseline.tar`), then working tree overlaid via rsync. The agent works exclusively in `sandbox/`. Destroyed on session teardown.

**`.workspace/`** — a host-side directory providing the I/O channels between containers and host. Subdirectories have distinct owners and trust levels: `input/` (operator-written, reasoning layer read-only), `output/` (agent-written, reasoning layer read-write), `session-diffs/` (harness-written, capability layer read-write — diff pipeline output).

**Diff and apply** — on capability layer exit, the diff pipeline produces per-commit `.diff` files under `patches/`, an `uncommitted.diff` (uncommitted working tree changes), and an `all-changes.diff` (net delta since session init), all in a session-scoped directory under `session-diffs/`. The operator runs `make draft` to apply patches to a working branch, reviews, then runs `make confirm` to merge. `make apply` applies a single `uncommitted.diff` directly to the working tree without creating commits.

**Per-project config** — each project has a `SANDBOX_DIR` alongside `PROJECT_DIR` containing a `Makefile`, `.env` (machine-specific, never committed), and a project-committed `AGENTS.md` at the repository root (project-layer agent context — session workflow, navigation, collaboration principles). Provider-specific agent context is supplied by `providers/<n>/config/AGENTS.md` and seeded into `AGENT_HOME` at container start. The two-layer agent context model is defined in [`../concepts/agent_workflow.md`](../concepts/agent_workflow.md#agent-context-model).

---

## Detailed References

| Topic | Document |
|---|---|
| Container lifecycle, snapshot pipeline, mount shape | [execution_model.md](execution_model.md) |
| Workflow expression model and policy map | [../concepts/agent_workflow.md](../concepts/agent_workflow.md) |
| Security guarantees and trust boundaries | [security.md](security.md) |
| STRIDE threat analysis | [threat_model_stride.md](threat_model_stride.md) |
| Standard operating procedures | [../operations/standard_operating_procedures.md](../operations/standard_operating_procedures.md) |
