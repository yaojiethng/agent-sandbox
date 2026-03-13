# Agent Workflow

This document describes the principles and operator-facing workflow for agent-sandbox runs. It covers the three core design principles, what the operator does before and after a run, and the rules governing how outputs move from the container back into the repository.

Container internals — mount shape, snapshot pipeline, entrypoint sequence — are in [`../architecture/execution_model.md`](../architecture/execution_model.md).

---

## Core Principles

### 1. Isolation

Agents run inside containers. The host repository is mounted as a read-only snapshot; agents cannot modify host files directly. Only `.workspace/` is writable inside the container, and only the operator can apply its contents to the repository.

This prevents uncontrolled mutation of the repository.

### 2. Staging

Agents perform all modifications inside a container-local sandbox. On exit, changes are captured as a diff and written to `.workspace/changes/staged.diff`. No changes are applied directly to the working tree.

All modifications must pass through a human review and approval step before reaching the repository. `staged.diff` is the primary artifact for proposed source changes.

### 3. Reproducibility

Each agent run is reproducible via a container image version, a specific project state, and the configuration used to start the run. This ensures every change is traceable, every run can be replayed, and every decision can be audited.

---

## Host Directory Structure

The harness uses two sibling directories under a common working directory. The project repository is kept clean — no harness files are placed inside it.

```
WORKDIR/
├── project-dir/              ← PROJECT_DIR (git repo, clean)
└── project-dir-sandbox/      ← SANDBOX_DIR (harness workspace, not committed)
    ├── Makefile
    ├── .env
    ├── .agent-input/         ← input channel (managed by harness and operator)
    │   ├── snapshot/         ← project snapshot, built at run time
    │   ├── brief.md          ← agent brief, copied from --brief path
    │   └── input/            ← operator-placed task files
    └── .workspace/           ← output channel
        └── changes/
            └── staged.diff
```

`SANDBOX_DIR` is set explicitly in the project Makefile. By convention it is named `<project-dir-name>-sandbox` and lives alongside `PROJECT_DIR`, but any absolute path is valid.

`.agent-input/` and `.workspace/` are managed by the harness. They should not be committed.

---

## Mount Rules

| Host path | Container path | Mode | Purpose |
|---|---|---|---|
| `SANDBOX_DIR/.agent-input/` | `/home/agentuser/.agent-input/` | read-only | Snapshot, brief, operator input files |
| `SANDBOX_DIR/.workspace/` | `/home/agentuser/.workspace/` | read-write | Agent output |

`PROJECT_DIR` itself is not mounted at container runtime. The agent never has direct access to the host repository.

---

## Operator Workflow

### Before a run

1. Ensure `PROJECT_DIR` is a git repository with at least one commit.
2. Ensure `.gitignore` is present in `PROJECT_DIR` and covers secrets and build artifacts.
3. Ensure `SANDBOX_DIR` exists alongside `PROJECT_DIR`.
4. Optionally prepare a brief and place it at the path referenced by `AGENT_BRIEF` in the Makefile (relative to `SANDBOX_DIR`).
5. Optionally place task files, path lists, or additional context in `SANDBOX_DIR/.agent-input/input/`. The agent will read these alongside the project snapshot.
6. Run `make start` (or `make serve`). The harness builds the snapshot, validates it, and starts the container.

### During a run

The agent works inside the container. `SANDBOX_DIR/.workspace/changes/staged.diff` is updated periodically via the autosave loop and on container exit. The operator does not need to intervene unless the run needs to be stopped.

### After a run

1. Inspect `SANDBOX_DIR/.workspace/changes/staged.diff`.
2. Review the proposed changes.
3. If approved: run `make apply` (optionally with `BRANCH=<name>`), then commit.
4. If rejected: discard `SANDBOX_DIR/.workspace/` contents. The host repository is unchanged.
5. Clear or update `SANDBOX_DIR/.agent-input/input/` before the next run if task files are no longer relevant.

---

## Input Channel Lifecycle

`SANDBOX_DIR/.agent-input/input/` is the operator input channel. It is:

- **Written by the operator** before the run — task files, file path lists, supplementary briefs, or any files the agent should read during the session.
- **Read by the agent** during the run — contents are copied into `sandbox/` at container startup and available as ordinary files.
- **Managed by the operator** between runs — the operator clears, replaces, or leaves files in `input/` as appropriate before the next run. The harness does not clear it automatically.

---

## Write-Back Rules

Changes are written back to the repository only when:

- The container has exited.
- `staged.diff` has been reviewed and approved.
- The operator applies the patch manually on the host using `make apply`.

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
