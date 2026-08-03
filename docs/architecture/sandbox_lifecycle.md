# Sandbox Lifecycle

This document describes the capability layer session arc: how project content enters the sandbox, how the agent works, and how changes are returned to the host.

The reasoning layer lifecycle — provider config copy-in, input channels, copy-out — is in [`provider_lifecycle.md`](provider_lifecycle.md). How the two layers are wired together — mount shape, compose generation, start/stop sequencing — is in [`execution_model.md`](execution_model.md).

The sandbox is the unit of isolation. The current implementation uses git for baseline tracking and diff generation — this is an implementation choice, not an architectural constraint.

All snapshot and diff functions are defined in `libs/snapshot.sh` and `libs/diff_export.sh`, sourced by both `scripts/start_agent.sh` and the capability layer entrypoint.

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

1. **Baseline commit from archive** — unpacks `baseline.tar` into `sandbox/`, stages all files, and commits as "baseline". This commit represents exactly `HEAD` in `PROJECT_DIR`. After the commit is created, both the root commit SHA and session timestamp are written to `sandbox/.git/SESSION_STATE` as key-value pairs:

```bash
session_state_write "$SANDBOX_DIR" "init_sha" "$sha"
session_state_write "$SANDBOX_DIR" "session_ts" "$SESSION_TS"
```

`init_sha` is set once and never updated. It is the fixed lower boundary for `package-branch` throughout this container lifetime. `session_ts` records the session start timestamp.

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

`.snapshot/` is overwritten on each **first** start — rebuilt from `PROJECT_DIR` before the containers start. On a resumed session, the snapshot pipeline is skipped entirely. `.snapshot/` retains its previous content but is not accessed after initial git init. It is not archived or cleaned up between runs.

### Resume path (M2.6.2 volume-based persistence)

**Current — single-volume model:**

```
.run-identity exists + REFRESH not set?
  ├── No  → normal init
  │         Host: compute identity, write .run-identity, run copy pipeline
  │         Container: .git absent → snapshot_validate + snapshot_init_git
  └── Yes → resume
            Host: read identity from .run-identity, skip copy pipeline
            Container: .git present → skip snapshot_validate + snapshot_init_git
```

The `.run-identity` file (written to `$SANDBOX_DIR/.run-identity` at session start) records the session identity. It is always overwritten — for new sessions with fresh identity values, and for resumed sessions with values read from the volume's Docker labels.

**Session start (M2.6.5):**

```
--resume passed?
  ├── No → new session (default). Compute fresh identity, reset volume.
  └── Yes → discover volumes for sandbox dir:
            ├── 0 → new session (no volumes to resume)
            ├── 1 → resume that volume
            └── 2+ → interactive selector
                     └── operator picks volume or "new session"
                         Volumes whose host-head-sha label ≠ current HEAD
                         are flagged [STALE].
```

`--refresh` always forces a new session even when combined with `--resume`.

---

## Phase 2 — Work

The agent works exclusively inside `sandbox/`. The host repository is never mounted and cannot be reached from inside the container.

---

## Phase 3 — Join (Diff Pipeline)

On capability layer container exit, an EXIT trap runs the diff pipeline. The entrypoint constructs the output path via `session_export_path` (from `routing.sh`) and calls `diff_export`, which delegates to `package_branch`:

1. **`package_commits`** — Produces one numbered `.diff` file per agent commit since `init_sha`, written into `patches/`. Git index lines are stripped. No sweep commit — uncommitted changes are captured separately.
2. **`write_uncommitted_diff`** — Captures working tree delta from HEAD as `uncommitted.diff`. Includes untracked files via temporary `git add -N` staging.
3. **`write_all_changes_diff`** — Captures net delta from `init_sha` (committed + uncommitted) as `all-changes.diff`.
4. **`write_changed_files`** — Copies all changed files into `changed-files/` with `MANIFEST.txt`, preserving directory structure.

No sweep commit is performed. Uncommitted changes are preserved in the working tree — `diff_export` never commits.

All artefacts land in the session export directory constructed by `session_export_path`:

```
workspace/session-diffs/session/<SESSION_TS>-<SANITIZED_HOST_BRANCH>/
  EXPORT-TIME.txt       — timestamp of the exit export
  uncommitted.diff      — uncommitted changes vs HEAD (no sweep)
  all-changes.diff      — net delta init_sha..HEAD
  patches/
    0001-abc1234-<subject>.diff  — per-commit diffs from package_branch
    0001-abc1234-<subject>.msg   — full commit message for each diff
  changed-files/
    MANIFEST.txt
    <path>/<file>        — working tree copies of all changed files
```

The autosave loop uses the same pattern but writes to `workspace/session-diffs/autosave/<SESSION_TS>-<BRANCH>/`. `session/` and `autosave/` are separate subdirectories under the new flipped layout — they no longer share a parent `<SESSION>-<BRANCH>/` directory.

`workspace/session-diffs/` accumulates session and autosave directories over time and is not automatically pruned by the harness.

### Apply workflow

On the host, `agent-sandbox` dispatches to routers in `routing.sh` which resolve the appropriate diff file or source directory, then pass the resolved path to the workflow library:

**`make draft [SESSION=<name>] [CHANNEL=<channel>]`** — resolves a source directory via routing (`session`, `autosave`, or `bundles` channel), then applies `patches/*.diff` sequentially followed by `uncommitted.diff` if present. Creates a `draft/<SESSION_TS>-<slug>-<sha6>` branch. `SESSION` is name-only (rejected if absolute).

**`make draft FROM=bundles`** — shorthand for `--channel=bundles`. Resolves from `output/bundles/`.

**`make draft FROM=autosave`** — shorthand for `--channel=autosave`. Resolves from `session-diffs/autosave/`.

**`make draft INTERACTIVE=1`** — interactive mode: guides the operator through a two-step numbered picker (channel then session) instead of requiring explicit `SESSION=` or `FROM=` arguments. After selections are made, the equivalent non-interactive command is printed (e.g. `Running: make draft CHANNEL=session SESSION=<name>`). When `SESSION=<name>` is provided and the named session is not in the displayed list, it is injected as option 0 and becomes the default. When more sessions exist than the display limit (10), `n` and `p` navigate between pages.

**`make confirm [TARGET=<branch>]`** — cleans up the draft branch after the operator has rebased and merged.

**`make reject`** — discards the draft branch. Artefacts unchanged.

**`make apply [CHANNEL=<channel>] [DIFF=<path>]`** — applies a diff file via `git apply` with index lines stripped. The diff file is resolved by the router (default: `diffs` channel, resolving from `output/diffs/`). `DIFF=<path>` bypasses all channel resolution. No commits created.

**`make apply FROM=autosave`** — shorthand for `--channel=autosave`. Resolves `uncommitted.diff` from `session-diffs/autosave/`.

**`make apply INTERACTIVE=1`** — interactive mode: guides the operator through a three-step numbered picker (channel, session, diff type) instead of requiring explicit flags. After selections are made, the equivalent non-interactive command is printed (e.g. `Running: make apply CHANNEL=session SESSION=<name>` or `Running: make apply DIFF=<path>` for all-changes.diff). When `SESSION=<name>` is provided and the named session is not in the displayed list, it is injected as option 0 and becomes the default. When more sessions exist than the display limit (10), `n` and `p` navigate between pages.

**`make package-diff [SESSION_SUMMARY=<text>] [ALL=1] [BASELINE=<sha>]`** — runs `agent-sandbox package-diff --sandbox=$(SANDBOX_DIR)`, which sources `.env` and writes to `INPUT_DIR/diffs/<ts>-<summary>/`. Default: packages uncommitted changes only. `ALL=1` packages all changes since session baseline. `BASELINE=<sha>` packages against explicit SHA.

**`make package-branch [SESSION_SUMMARY=<text>] [BASELINE=<sha>]`** — runs `agent-sandbox package-branch`, which sources `.env` and writes to `INPUT_DIR/bundles/<ts>-<summary>/`.

No checkpoint git tags are used. No `git am`. No `docker exec`. All correspondence flows via diff files through the bind-mounted workspace.

---

## References

| Topic | Document |
|---|---|
| Correspondence model — three cases, bidirectional flow | [../concepts/sandbox_host_correspondence_model.md](../concepts/sandbox_host_correspondence_model.md) |
| Reasoning layer lifecycle | [provider_lifecycle.md](provider_lifecycle.md) |
| Mount shape and container wiring | [execution_model.md](execution_model.md) |
| Mount shape guarantees | [tool_interface.md](tool_interface.md#mount-shape-guarantees) |
| Project onboarding | [../operations/project_onboarding_guide.md](../operations/project_onboarding_guide.md) |
