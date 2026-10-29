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

## Architecture Layer Model

The stack has three layers. Each builds on the one below it.

| Layer | Name | Holds |
|---|---|---|
| 0 | Infrastructure | the Docker runtime, the filesystem, the container environment a session runs in |
| 1 | Execution Mechanics | how a single agent runs a task and produces a diff |
| 2 | Orchestration | how several agents coordinate |

**Security Model** -- states the threat model the implementation is hardened against.

**Human Workflow** -- the constraint on how the operator works within agent-sandbox.

### The stabilization rule

Layer 0 is finished before layer 1 is built on it, and layer 1 before layer 2. That order is the rule. A change to a low layer breaks the work already built on it, so the change waits until that work is finished.

An unfinished layer above is a reason to leave a low layer alone. Settled never means finished for good: it means you can build on the layer today.

### What going around it costs

A low-layer change looks locally correct: tests pass, the diff is small. Four things follow.

1. Changing a layer out of order invalidates the interface that future work relies on, so that work has to be replanned or rescoped.
2. The review cannot catch it: everyone who uses the interface today gets updated in the same change, and the future work is not in the tree to read.
3. Nothing records the crossing, so the rework shows up two milestones on with no account of why.
4. Every document, handover and fixture that describes the old interface goes stale at once, and each one has to be found by hand.

### Which situation you are in

Editing a low layer to get on with the work above it is one of three situations. Each has a test, and a different fix.

1. **The lower layer is not finished.** The work needs a contract the lower layer does not yet state. Finish the lower layer; the higher-layer task waits.
2. **The task belongs to the lower layer.** The change makes sense without reference to the work above it. Rescope the task to the lower layer, and move its roadmap position with it.
3. **The lower layer is being rewritten deliberately.** The rewrite changes an interface that everything above depends on. Make it a task of its own, name what it invalidates, and sequence it against the work above.

A task whose first edit lands below the layer it names is the signal, and it is cheaper to catch before the work starts.

How a document states a layer's state is the `project-documentation` convention's. Which layer work is in flight is the task list's.

## Major Components

**Two-layer container runtime** -- each session runs two containers: a capability layer (sandbox, seed pipeline, diff pipeline) and a reasoning layer (agent runtime, provider-specific). Both are ephemeral and discarded after each run. The capability layer starts first and owns the sandbox volume; the reasoning layer attaches to it via `--volumes-from`.

**Host-side volume seed** -- before the sandbox container starts, a one-shot seeder service (the sandbox image) fills the sandbox volume: repository with index, git-enumerated working tree, and `SESSION_STATE`; the seeder self-verifies and its exit code gates the start. No staging directory and no snapshot mount exist at any point. Details: [copy_delivery.md](../reference/copy_delivery.md).

**Sandbox** -- a named Docker volume owned by the capability layer. Seeded before first use by the helper-container transport. The agent works exclusively in `sandbox/`. Survives stop/resume; removed by prune.

**`.workspace/`** -- a host-side directory providing the I/O channels between containers and host. Subdirectories have distinct owners and trust levels: `input/` (operator-written, reasoning layer read-only), `output/` (agent-written, reasoning layer read-write), `session-diffs/` (harness-written, capability layer read-write -- diff pipeline output).

**Diff and apply** -- on capability layer exit, the diff pipeline produces per-commit `.diff` files, `uncommitted.diff`, `all-changes.diff`, and `changed-files/` into a session-scoped directory under `session-diffs/{session,autosave}/`. The operator runs `make draft` to apply patches to a working branch, or `make apply DIFF=<path>` to apply a diff file directly (unstaged). Host-side `make package-branch` provides equivalent export capability outside the container.

**Per-project config** -- each project has a `SANDBOX_DIR` alongside `PROJECT_DIR` containing a `Makefile`, `.env` (machine-specific, never committed), and a project-committed `AGENTS.md` at the repository root (project-layer agent context -- session workflow, navigation, collaboration principles). Provider-specific agent context is supplied by `src/reasoning/providers/<n>/config/AGENTS.md` and seeded into `AGENT_HOME` at container start. The two-layer agent context model is defined in [`../reference/agent_workflow.md`](../reference/agent_workflow.md#agent-context-model).

## Detailed References

| Topic | Document |
|---|---|
| Container lifecycle, seed pipeline, mount shape | [execution_model.md](execution_model.md) |
| Workflow expression model and policy map | [../reference/agent_workflow.md](../reference/agent_workflow.md) |
| Model routing, dispatch state and failure vocabulary | [dispatch.md](dispatch.md) |
| Security guarantees and trust boundaries | `docs/development/security.md` |
| STRIDE threat analysis | `docs/development/threat_model_stride.md` |
| Standard operating procedures | `docs/development/standard_operating_procedures.md` |
