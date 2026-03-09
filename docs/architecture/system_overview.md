# System Overview

This document describes the high-level architecture of the agent-sandbox system.

The system is a sandbox and execution harness for autonomous coding agents. It provides a controlled environment where agents can read, modify, and test code while maintaining strict boundaries between the agent's working copy and the host repository.

---

## Core Invariants

These guarantees hold across all agent runs:

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

Current layer freeze status is tracked in [`docs/development/doc-status.md`](../development/doc-status.md).

---

## Major Components

**Container runtime** — each agent runs inside a Docker container built from a minimal Ubuntu image with Node, Git, and the OpenCode agent installed. The container is ephemeral and discarded after each run.

**`.bootstrap/`** — a read-only input channel mounted into the container before the agent starts. Contains the pre-built project snapshot and the agent brief. The snapshot is constructed on the host by `start_agent.sh` before the container launches; the container never has direct access to `PROJECT_ROOT`.

**Sandbox** — a writable, container-local copy of the project snapshot. The entrypoint copies `.bootstrap/snapshot/` into `sandbox/` on startup. The agent works exclusively in the sandbox.

**`.workspace/`** — a read-write directory mounted from the host. The sole persistent output channel between container and host. Agent changes are written here as `staged.diff` on exit; `autosave.diff` is written periodically during a session if autosave is enabled.

**Diff and apply** — the entrypoint records a git baseline in `sandbox/` before the agent runs. On exit, it produces `staged.diff` capturing all agent changes. The operator applies this diff to the host repository manually using `apply_workspace_inplace.sh` or `apply_workspace_to_branch.sh`.

**Per-project config** — each project has a config directory under `projects/<project>/` containing machine-agnostic settings, machine-specific overrides, and a `.env` for runtime variables. This allows the same harness to run against different projects and machines without modifying core scripts.

---

## Detailed References

| Topic | Document |
|---|---|
| Container lifecycle, snapshot pipeline, mount shape | [execution_model.md](execution_model.md) |
| End-to-end operator workflow | [../concepts/agent_workflow.md](../concepts/agent_workflow.md) |
| Security guarantees and trust boundaries | [security.md](security.md) |
| STRIDE threat analysis | [threat_model_stride.md](threat_model_stride.md) |
| Standard operating procedures | [../operations/standard_operating_procedures.md](../operations/standard_operating_procedures.md) |