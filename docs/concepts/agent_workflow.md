# Agent Workflow

This document defines the conceptual model for how agents and operators interact with the system. It covers design principles, structural constraints, and the guarantees the system provides.

This is a design document, not an operational guide. For concrete commands and onboarding steps, see the references at the end.

---

## Core Principles

### Isolation

Each agent session runs two containers: a capability layer (holds working content and produces diffs) and a reasoning layer (runs the agent). The host repository is never mounted — the agent works against a snapshot copied into a shared volume. The operator controls what enters and what leaves.

### Staging

Agents do not modify the repository. All modifications are captured as a diff and staged for review. No change reaches the repository without human approval.

### Reproducibility

Each agent run is reproducible via a container image version, a specific project state, and the configuration used to start the run. Every change is traceable, every run can be replayed, and every decision can be audited.

---

## Write-Back Rules

The system enforces a strict boundary between agent output and repository state:

- Both containers must have exited before any output is applied.
- The diff must be reviewed and approved by the operator.
- The operator applies the patch on the host — the agent never executes `git commit`, `git push`, or writes directly to the host repository.

All repository mutation occurs outside the containers, initiated by the operator.

---

## Agent Nesting

Agents may operate in a parent/child hierarchy for complex tasks. The maximum nesting depth is two layers: a parent agent may spawn child agents, but child agents cannot spawn further children. All child outputs are staged and validated before the parent merges them.

---

## Operator UX Flows

The system has two distinct operator workflows. Each has dedicated operational documentation.

**Onboarding** — setting up agent-sandbox on a new machine and registering a project for the first time. This is a one-time setup per project covering CLI installation, Makefile creation, brief authoring, and image building. Covered by the quickstart guide and onboarding scripts.

**Running** — the repeating cycle of preparing inputs, starting a session, reviewing output, and applying or discarding changes. Covered by the quickstart guide, provider-specific documentation, and the tool interface spec.

---

## Core Invariants

- No unreviewed output reaches the repository.
- No direct mutation of the host repository occurs from inside either container.
- Every change is traceable to an agent run.
- The operator initiates every run and has final authority over all outputs.

---

## References

| Topic | Document |
|---|---|
| Container lifecycle and mount shape | [`../architecture/execution_model.md`](../architecture/execution_model.md) |
| External contract: commands, naming, guarantees | [`../architecture/tool_interface.md`](../architecture/tool_interface.md) |
| Security model and trust boundaries | [`../architecture/security.md`](../architecture/security.md) |
| Two-layer conceptual model | [`two_layer_model.md`](two_layer_model.md) |
| Onboarding and running guide | [`../operations/quickstart.md`](../operations/quickstart.md) |
