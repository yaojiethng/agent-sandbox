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

**Checkpoint tag** — a lightweight tag `agent-checkpoint/<worktree-id>/YYYYMMDD-HHMMSS` is created in `PROJECT_DIR` before the snapshot begins. The worktree ID is a short hash of the project path, namespacing tags per-worktree. This tag serves as the base for the draft workflow. The last 5 checkpoint tags per worktree are preserved; older tags are pruned. The current tag name is written to `.workspace/checkpoint-latest.ref`.

**`snapshot_copy_worktree`** uses `rsync` to replicate the operator's working tree into `.snapshot/`. It copies what is on disk, including untracked non-ignored files, and excludes files matched by `.gitignore`, global gitignore (`core.excludesFile`), and `.git/info/exclude`. rsync enumerates directly from the filesystem — it does not consult the git index — so it correctly handles uncommitted deletions, moves, and new files.

Files excluded by global gitignore or `.git/info/exclude` (but not local `.gitignore`) emit a warning to `stderr` to alert the operator of potential missing dependencies.

**`snapshot_archive_head`** produces a tar archive of the committed state at HEAD:

```bash
git -C "$PROJECT_DIR" archive HEAD > "$SNAPSHOT_DIR/baseline.tar"
```

This runs on the host where `PROJECT_DIR` is available. The tar contains exactly the files as they exist in the HEAD commit — no working tree changes, no untracked files. It is written into `.snapshot/` alongside the rsync copy and is used by the container to construct the baseline commit.

**`snapshot_validate` (gate 1)** runs after both copy and archive, before the containers start. Checks that `.snapshot/` is non-empty, structurally sound, and contains `baseline.tar`. Non-zero exit aborts the run before Docker is invoked.

### Stage 2 — Capability layer side (capability layer entrypoint)

**`snapshot_validate` (gate 2)** runs first, against the mounted `.snapshot/`. Catches mount failures or transfer corruption before the sandbox is prepared.

**`snapshot_init_git`** initialises the sandbox git repository in two steps:

1. **Baseline commit from archive** — unpacks `baseline.tar` into `sandbox/`, stages all files, and commits as "baseline". This commit represents exactly `HEAD` in `PROJECT_DIR`. The baseline SHA is stored in `.git/BASELINE_SHA` for the diff pipeline.

2. **Working tree overlay** — rsync copies `.snapshot/` (the operator's working tree) over `sandbox/` with `--delete`, without touching the git index. The index now reflects the baseline commit (HEAD); the working tree reflects the operator's current on-disk state. The result is a sandbox whose `git status` matches what the operator would see in `PROJECT_DIR`.

The two-step design ensures all four working tree states are handled correctly:

| Operator state | git status in sandbox |
|---|---|
| Untracked file | `??` untracked |
| Tracked file with unstaged edits | `M` unstaged modification |
| Tracked file deleted without staging | `D` unstaged deletion |
| No changes | Clean |
| Gitignored file | Not visible |

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
4. All artefacts are written to a session-scoped directory: `workspace/session-diffs/<session-name>/`.
   - `staged.diff` — full session diff
   - `patches/` — per-commit `.patch` files
   - `autosave.diff` — (if present) last incremental save

The `SESSION_NAME` is derived from the branch name and session timestamp (e.g., `main-20260408-112344`) and is injected into the container environment at startup.

An autosave loop writes `autosave.diff` into the session directory on a configurable interval (`AUTOSAVE_INTERVAL`, default 60s).

`workspace/session-diffs/` accumulates session directories over time; they are not automatically pruned by the harness.

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
