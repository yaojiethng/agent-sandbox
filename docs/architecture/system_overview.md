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

The system is organized into five layers. Lower layers must stabilize before higher layers evolve — refactors are always bottom-up.

| Layer | Name | Responsibility |
|---|---|---|
| 0 | Infrastructure | Docker runtime, filesystem, container environment |
| 1 | Execution Mechanics | How a single agent runs tasks and generates diffs |
| 2 | Security Model | Isolation rules, filesystem access restrictions |
| 3 | Human Workflow | Task release, review loop, diff approval |
| 4 | Orchestration | Coordination between multiple agents |

Current layer freeze status is tracked in [`docs/development/doc-status.md`](../development/doc-status.md).

---

## Major Components

**Container runtime** — each agent runs inside a Docker container built from a minimal Ubuntu image with Node, Git, and the OpenCode agent installed. The container is ephemeral and discarded after each run.

**Project mount** — the host project repository is mounted into the container read-only. The agent cannot write to the host filesystem.

**Sandbox** — on startup, the entrypoint copies project files into an isolated `sandbox/` directory inside the container. The agent works exclusively in the sandbox. Files excluded by `.gitignore` are never copied in.

**Workspace** — `.workspace/` is a read-write directory mounted from the host. It is the only persistent output channel between the container and the host. Agent changes are written here as `patch.diff` on exit.

**Diff and apply** — the entrypoint records a git baseline in the sandbox before the agent runs. On exit, it produces a `patch.diff` capturing all agent changes. The operator applies this diff to the host repository manually using `apply_workspace_inplace.sh` or `apply_workspace_to_branch.sh`.

**Per-project config** — each project has a config directory under `projects/<project>/` containing machine-agnostic settings, machine-specific overrides, and a `.env` for runtime variables. This allows the same harness to run against different projects and machines without modifying core scripts.

---

## Detailed References

| Topic | Document |
|---|---|
| Container lifecycle and sandbox preparation | [agent_runtime.md](agent_runtime.md) |
| End-to-end operator workflow | [../concepts/agent_workflow.md](../concepts/agent_workflow.md) |
| Security guarantees and trust boundaries | [security.md](security.md) |
| STRIDE threat analysis | [threat_model_stride.md](threat_model_stride.md) |
| Standard operating procedures | [../operations/standard_operating_procedures.md](../operations/standard_operating_procedures.md) |
| Term definitions | [../references/glossary.md](../references/glossary.md) |
