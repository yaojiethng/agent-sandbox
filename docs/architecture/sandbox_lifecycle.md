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

**Checkpoint tag** — a lightweight tag `agent-checkpoint/YYYYMMDD-HHMMSS` is created in `PROJECT_DIR` before the snapshot begins. This serves as the base for the draft workflow. The last 5 checkpoint tags are preserved; older tags are pruned. The current tag name is written to `.workspace/checkpoint-latest.ref`.

**`snapshot_copy_worktree`** uses `rsync` to replicate the project state into `.snapshot/`. It mirrors the current working tree directly, including untracked non-ignored files, but excluding files matched by `.gitignore`, global gitignore (`core.excludesFile`), and `.git/info/exclude`.

The rsync approach ensures the snapshot reflects the on-disk state even if the git index is stale (e.g. uncommitted deletes or moves). Files excluded by global or exclude rules (but not local `.gitignore`) emit a warning to `stderr` to alert the operator of potential missing dependencies.

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

1. Any uncommitted changes in `sandbox/` are staged and committed with a "sweep" message.
2. `diff_format_patch` runs `git format-patch` to produce one numbered `.patch` file per agent commit since the baseline.
3. `git diff <baseline>..HEAD` is computed for a single-file summary.
4. All artefacts are written to a session-scoped directory: `workspace/changes/<session-name>/`.
   - `staged.diff` — full session diff
   - `patches/` — per-commit `.patch` files
   - `autosave.diff` — (if present) last incremental save

The `SESSION_NAME` is derived from the branch name and session timestamp (e.g., `main-20260408-112344`) and is injected into the container environment at startup.

The diff runs in the capability layer container against `sandbox/` — not in the reasoning layer. The reasoning layer exits first; the harness then stops the capability layer, triggering the EXIT trap and diff generation.

An autosave loop writes `autosave.diff` into the session directory on a configurable interval (`AUTOSAVE_INTERVAL`, default 60s), providing incremental checkpoints during a session.

`workspace/changes/` accumulates session directories over time; they are not automatically pruned by the harness.

### Apply workflow

On the host, `scripts/apply_workspace.sh` provides a three-stage draft workflow:

1. **`draft`** — creates a working branch `agent/draft/<session-name>` from the session's checkpoint tag and applies all `.patch` files via `git am --3way`. All commits are reset to the operator's author identity.
2. **`confirm`** — rebases the draft branch onto the target branch (defaults to the source branch), fast-forward merges it, and deletes the draft branch. This ensures a linear history.
3. **`reject`** — deletes the draft branch and returns to the source branch.

A legacy **`apply`** mode is retained for applying `staged.diff` directly to the working tree without creating commits.

---

## References

| Topic | Document |
|---|---|
| Reasoning layer lifecycle | [provider_lifecycle.md](provider_lifecycle.md) |
| Mount shape and container wiring | [execution_model.md](execution_model.md) |
| Operator run workflow | [../concepts/agent_workflow.md](../concepts/agent_workflow.md) |
| Mount shape guarantees | [tool_interface.md](tool_interface.md#mount-shape-guarantees) |
| Project onboarding | [../operations/project_onboarding_guide.md](../operations/project_onboarding_guide.md) |
