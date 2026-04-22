# Sandbox Lifecycle

This document describes the capability layer session arc: how project content enters the sandbox, how the agent works, and how changes are returned to the host.

The reasoning layer lifecycle — provider config copy-in, input channels, copy-out — is in [`provider_lifecycle.md`](provider_lifecycle.md). How the two layers are wired together — mount shape, compose generation, start/stop sequencing — is in [`execution_model.md`](execution_model.md).

The sandbox is the unit of isolation. The current implementation uses git for baseline tracking and diff generation — this is an implementation choice, not an architectural constraint.

All snapshot and diff functions are defined in `libs/snapshot.sh` and `libs/diff.sh`, sourced by both `scripts/start_agent.sh` and the capability layer entrypoint.

---

## Overview

A capability layer session has three phases:

1. **Fork** — the host project state is replicated into the sandbox before the containers start. The host repository is never modified.
2. **Work** — the agent operates exclusively inside the sandbox. The host is untouched.
3. **Join** — the agent's changes are packaged as diffs and written to the host for operator review.

---

## Phase 1 — Fork (Snapshot Pipeline)

The snapshot pipeline replicates the host repository state into the capability layer sandbox. It runs in two stages separated by the container boundary.

### Stage 1 — Host side (`scripts/start_agent.sh`)

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

1. **Baseline commit from archive** — unpacks `baseline.tar` into `sandbox/`, stages all files, and commits as "baseline". This commit represents exactly `HEAD` in `PROJECT_DIR`. After the commit is created, the root commit SHA is written to `sandbox/.git/INIT_SHA`:

```bash
git rev-list --max-parents=0 HEAD > sandbox/.git/INIT_SHA
```

`INIT_SHA` is set once and never updated. It is the fixed lower boundary for `package-branch` throughout this container lifetime.

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
2. `package_branch` produces one numbered `.diff` file per agent commit since `INIT_SHA`, written to `workspace/session-diffs/<branch-name>/`. Git index lines (`index <sha>..<sha>`) are stripped from all output.
3. A flat `staged.diff` (net delta `INIT_SHA..HEAD`) is written alongside the numbered series as a human-readable session summary.

All artefacts land in `workspace/session-diffs/<branch-name>/`:
- `staged.diff` — full session diff, single file, human-readable overview
- `0001.diff`, `0002.diff`, ... — per-commit diffs, applied in order by `make draft`

The branch name (e.g. `main`, `feature/foo`) is the folder differentiator. If the agent works on multiple branches, each gets its own folder under `session-diffs/`.

An autosave loop runs `package_diff` (uncommitted working tree changes) on a configurable interval (`AUTOSAVE_INTERVAL`, default 60s), writing `autosave.diff` to the session directory as an incremental checkpoint.

`workspace/session-diffs/` accumulates branch directories over time and is not automatically pruned by the harness.

### Apply workflow

On the host, `scripts/apply_workspace.sh` provides two application paths:

**`make draft [FROM=<hash>] [DIFFS=<start>..<end>]`** — creates a `draft/<branch>` branch from `FROM` (default: current host `HEAD`; accepts any commit hash or partial hash). Applies the numbered `.diff` files from `session-diffs/<branch-name>/` in sort order using `git apply` with index lines stripped. `DIFFS` selects a sub-range (e.g. `3..5`, `2..`, `..4`); default is all. Produces a branch with one commit per diff, ready for `git rebase -i` onto the target branch. Writes `draft-state`.

**`make confirm [TARGET=<branch>]`** — cleans up the draft branch after the operator has rebased and merged. Deletes the draft branch, clears `draft-state`.

**`make reject`** — discards the draft branch, clears `draft-state`. Artefacts unchanged.

**`make apply [DIFF=<path>]`** — applies a single `.diff` to the working tree uncommitted using `git apply` with index lines stripped. Used for mid-session partial changes (sandbox→host) and host amendments pushed into a running sandbox (host→sandbox). Default: latest `.diff` in `workspace/output/` by timestamp.

No checkpoint git tags are used. No `git am`. No `docker exec`. All correspondence flows via diff files through the bind-mounted workspace.

---

## References

| Topic | Document |
|---|---|
| Correspondence model — three cases, bidirectional flow | [../concepts/sandbox_host_correspondence_model.md](../concepts/sandbox_host_correspondence_model.md) |
| Reasoning layer lifecycle | [provider_lifecycle.md](provider_lifecycle.md) |
| Mount shape and container wiring | [execution_model.md](execution_model.md) |
| Operator run workflow | [../concepts/agent_workflow.md](../concepts/agent_workflow.md) |
| Mount shape guarantees | [tool_interface.md](tool_interface.md#mount-shape-guarantees) |
| Project onboarding | [../operations/project_onboarding_guide.md](../operations/project_onboarding_guide.md) |
