# Agent Workflow

This document describes the principles and operator-facing workflow for agent-sandbox runs. It covers the three core design principles, what the operator does before and after a run, and the rules governing how outputs move from the container back into the repository.

Container internals — mount shape, snapshot pipeline, entrypoint sequence — are in [`../architecture/execution_model.md`](../architecture/execution_model.md).

---

## Core Principles

### 1. Isolation

Agents run inside containers. The host repository is mounted as a read-only snapshot; agents cannot modify host files directly. Only `.workspace/` is writable inside the container, and only the operator can apply its contents to the repository.

This prevents uncontrolled mutation of the repository.

### 2. Staging

Agents perform all modifications inside a container-local sandbox. On exit, changes are captured as a diff and written to `.workspace/changes/patch.diff`. No changes are applied directly to the working tree.

All modifications must pass through a human review and approval step before reaching the repository. `patch.diff` is the primary artifact for proposed source changes.

### 3. Reproducibility

Each agent run is reproducible via a container image version, a specific project state, and the configuration used to start the run. This ensures every change is traceable, every run can be replayed, and every decision can be audited.

---

## Host Directory Structure

```
PROJECT_ROOT/
├── (project files)
├── .bootstrap/          ← input channel: snapshot and brief (read-only mount)
│   ├── snapshot/
│   └── brief.md
└── .workspace/          ← output channel: patch and logs (read-write mount)
    └── changes/
        └── patch.diff
```

`.bootstrap/` and `.workspace/` are managed by the harness. They should be gitignored and must not be committed to the repository.

---

## Mount Rules

| Host path | Container path | Mode | Purpose |
|---|---|---|---|
| `PROJECT_ROOT/.bootstrap/` | `/home/agentuser/.bootstrap/` | read-only | Snapshot and brief |
| `PROJECT_ROOT/.workspace/` | `/home/agentuser/.workspace/` | read-write | Agent output |

`PROJECT_ROOT` itself is not mounted at container runtime. The agent never has direct access to the host repository.

---

## Operator Workflow

### Before a run

1. Ensure `PROJECT_ROOT` is a git repository with at least one commit.
2. Ensure `.gitignore` is present and covers secrets, build artifacts, and `.workspace/`.
3. Optionally prepare a `brief.md` and reference it via `AGENT_BRIEF` in the project config.
4. Run `start_agent.sh <project> <mode>`. The harness builds the snapshot, validates it, and starts the container.

### During a run

The agent works inside the container. `.workspace/changes/patch.diff` is updated periodically via the autosave loop and on container exit. The operator does not need to intervene unless the run needs to be stopped.

### After a run

1. Inspect `.workspace/changes/patch.diff`.
2. Review the proposed changes.
3. If approved: apply using `apply_workspace_inplace.sh` or `apply_workspace_to_branch.sh`, then commit.
4. If rejected: discard `.workspace/` contents. The host repository is unchanged.

---

## Write-Back Rules

Changes are written back to the repository only when:

- The container has exited.
- `patch.diff` has been reviewed and approved.
- The operator applies the patch manually on the host.

The agent never executes `git commit`, `git push`, or writes directly to the host repository. All repository mutation occurs outside the container, initiated by the operator.

---

## Agent Nesting

Agents may operate in a parent/child hierarchy for complex tasks. The maximum nesting depth is two layers: a parent agent may spawn child agents, but child agents cannot spawn further children. All child outputs are staged and validated before the parent merges them.

Naming conventions: `parent_<task_id>`, `child_<task_id>_<child_id>`.

---

## Core Invariants

- No unreviewed output reaches the repository.
- No direct mutation occurs from inside the container.
- Every change is traceable to an agent run.
- The operator initiates every run and has final authority over all outputs.
