# Sandbox Lifecycle

This document describes the capability layer session arc: how project content enters the sandbox, how the agent works, and how changes are returned to the host.

The reasoning layer lifecycle — provider config copy-in, input channels, copy-out — is in [`provider_lifecycle.md`](provider_lifecycle.md). How the two layers are wired together — mount shape, compose generation, start/stop sequencing — is in [`execution_model.md`](execution_model.md).

The sandbox is the unit of isolation. The current implementation uses git for baseline tracking and diff generation — this is an implementation choice, not an architectural constraint.

All snapshot and diff functions are defined in `libs/snapshot.sh` and sourced by both `scripts/start_agent.sh` and the capability layer entrypoint.

---

## Overview

A capability layer session has three phases:

1. **Fork** — the host project state is replicated into the sandbox before the containers start. The host repository is never modified.
2. **Work** — the agent operates exclusively inside the sandbox. The host is untouched.
3. **Join** — the agent's changes are captured as a diff and written to the host for operator review.

---

## Phase 1 — Fork (Snapshot Pipeline)

The snapshot pipeline replicates the host repository state into the capability layer sandbox. It runs in two stages separated by the container boundary.

### Stage 1 — Host side (`scripts/start_agent.sh`)

**`snapshot_enumerate_files`** runs `git ls-files --cached --others --exclude-standard` inside `PROJECT_DIR`. This covers tracked files and untracked non-ignored files. Gitignored files — including secrets and `.env` — are excluded by definition. A warning is emitted if no `.gitignore` is present.

The `git ls-files` approach was chosen over alternatives (e.g. git bundle, rsync) because it respects `.gitignore` without requiring any mutation of the host repository. A git bundle approach was evaluated and rejected: it required a temporary commit on the host (`git add -A && git commit --no-verify`), which mutated HEAD, the staging area, and commit history — violating the invariant that the harness must not modify the host repo.

**`snapshot_copy_files`** reads the file list and copies files into `.snapshot/` using `cp --parents` to preserve directory structure.

**`snapshot_validate` (gate 1)** runs after copy, before the containers start. Checks that `.snapshot/` is non-empty and structurally sound. Non-zero exit aborts the run before Docker is invoked.

### Stage 2 — Capability layer side (capability layer entrypoint)

**`snapshot_validate` (gate 2)** runs first, against the mounted `.snapshot/`. Catches mount failures or transfer corruption before the sandbox is prepared.

**`snapshot_copy_to_sandbox`** copies `.snapshot/` into `sandbox/` — the Docker volume shared with the reasoning layer. This is the working content the agent accesses.

**`snapshot_init_git`** initialises a git repository in `sandbox/` and records a baseline commit. The baseline SHA is stored for diff generation on exit. This is the connecting artefact between fork and join — the diff is always computed against this SHA.

### Harness directory lifecycle

`.snapshot/` is overwritten on each run — rebuilt from `PROJECT_DIR` before the containers start. It is not archived or cleaned up between runs.

---

## Phase 2 — Work

The agent works exclusively inside `sandbox/`. The host repository is never mounted and cannot be reached from inside the container.

---

## Phase 3 — Join (Diff Pipeline)

On capability layer container exit, an EXIT trap runs the diff pipeline:

1. Any uncommitted changes in `sandbox/` are staged and committed.
2. `git diff <baseline>..HEAD` is computed against the baseline SHA recorded at startup.
3. The result is written to `workspace/changes/staged.diff`.

The diff runs in the capability layer container against `sandbox/` — not in the reasoning layer. The reasoning layer exits first; the harness then stops the capability layer, triggering the EXIT trap and diff generation.

An autosave loop writes `autosave.diff` on a configurable interval (`AUTOSAVE_INTERVAL`, default 60s), providing incremental checkpoints during a session.

`workspace/changes/` is overwritten on each run by the diff pipeline.

### Apply workflow

On the host, `scripts/apply_workspace.sh` applies `staged.diff` to `PROJECT_DIR` on the current branch or a named branch via `--branch=<n>`. It uses `git apply --3way` to handle conflicts and validates that `PROJECT_DIR` is a git repository with at least one commit before applying.

The operator reviews `staged.diff` before applying. If rejected, `.workspace/changes/` contents are discarded — the host repository is unchanged.

---

## References

| Topic | Document |
|---|---|
| Reasoning layer lifecycle | [provider_lifecycle.md](provider_lifecycle.md) |
| Mount shape and container wiring | [execution_model.md](execution_model.md) |
| Operator run workflow | [../concepts/agent_workflow.md](../concepts/agent_workflow.md) |
| Mount shape guarantees | [tool_interface.md](tool_interface.md#mount-shape-guarantees) |
| Project onboarding | [../operations/project_onboarding_guide.md](../operations/project_onboarding_guide.md) |
