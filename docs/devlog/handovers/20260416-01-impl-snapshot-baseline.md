# Agent Handover

**Session date:** 2026-04-16
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Completed

## Objective

Redesign and implement `snapshot_init_git` so that the sandbox git state correctly reflects the operator's working tree: committed state as the baseline commit, working tree modifications present but unstaged, untracked files present but untracked.

## Scope

Change 4 (snapshot baseline initialization) only. All other M2.3 changes remain on hold in `20260412-02-m2_3_onhold.md`.

## Status

**CLOSED. All acceptance criteria passed. Operator confirmed.**

---

## Background — The Bug

The current implementation uses rsync to copy the working tree into `.snapshot/`, then inside the container runs `git init && git add -A && git commit -m "baseline"`. This collapses the entire working tree — including any unstaged edits, new files, and deleted files — into the baseline commit. When the agent runs `git status` inside the sandbox, it sees a clean working tree regardless of the operator's actual working tree state.

The bug was confirmed with `touch hello-world.txt && make start PROVIDER=pi`. The new file appeared in the baseline commit rather than as an untracked file.

## The Problem Has Three Cases

All three must be handled correctly. The naive "skip unstaged files from git add" approach fails case 2.

**Case 1 — Untracked file (`hello-world.txt` was never committed)**
- Current: file ends up in baseline commit. Incorrect.
- Required: file present on disk, not in index, shows as `?? hello-world.txt` in `git status`.

**Case 2 — Tracked file with unstaged edits (`foo.py` exists in HEAD, has working tree changes)**
- Current: edited version ends up in baseline commit. Incorrect.
- Naive fix (skip from git add): `foo.py` absent from baseline entirely. Also incorrect.
- Required: baseline commit contains the HEAD version of `foo.py`; working tree contains the edited version; shows as `M foo.py` in `git status`.

**Case 3 — Tracked file with unstaged deletion (`git rm` not run, file just `rm`-ed)**
- Current: snapshot aborts on `cp` failure (old behaviour) or rsync omits the file correctly but then baseline commit reflects the deletion. Incorrect.
- Required: baseline commit contains the file; working tree does not; shows as `D foo.py` in `git status`.

## The Correct Design — archive HEAD + rsync overlay

The key insight: the baseline commit must represent exactly `HEAD`, independent of the working tree. The working tree state is then layered on top after the commit is made.

**Stage 1 — Host side (`scripts/start_agent.sh`)**

No change to `snapshot_copy_worktree` (rsync). It correctly copies the operator's working tree into `.snapshot/`, excluding gitignored files. This is still the right mechanism for *which files reach the sandbox*. It runs first, as today.

**Stage 2 — Container side (`snapshot_init_git` in `libs/snapshot.sh`)**

Replace the current `git init && git add -A && git commit` sequence with:

```bash
snapshot_init_git() {
  local sandbox_dir="$1"
  local snapshot_dir="$2"   # the rsync copy (.snapshot/)

  # Step 1: init a bare-bones repo and populate it from git archive
  # git archive produces a tar of exactly HEAD — no working tree changes,
  # no untracked files, no index state. This becomes the baseline commit.
  git init "$sandbox_dir"
  git -C "$sandbox_dir" config user.email "sandbox@agent"
  git -C "$sandbox_dir" config user.name "sandbox"

  # Unpack the HEAD archive into a temp dir, stage it, commit as baseline
  local archive_dir
  archive_dir=$(mktemp -d)
  git -C "$PROJECT_DIR" archive HEAD | tar -x -C "$archive_dir"
  cp -a "$archive_dir/." "$sandbox_dir/"
  rm -rf "$archive_dir"

  git -C "$sandbox_dir" add -A
  git -C "$sandbox_dir" commit -m "baseline" --allow-empty
  # Record baseline SHA for diff pipeline
  git -C "$sandbox_dir" rev-parse HEAD > "$sandbox_dir/.git/BASELINE_SHA"

  # Step 2: overlay the rsync working tree copy on top
  # rsync from .snapshot/ over sandbox/ — this brings in:
  #   - edited versions of tracked files (will show as unstaged modifications)
  #   - untracked files (will show as untracked)
  #   - does NOT bring back files deleted in the working tree
  #     (rsync --delete ensures deletions are reflected)
  rsync -a --delete \
    --exclude='.git' \
    "$snapshot_dir/" "$sandbox_dir/"

  # Step 3: do NOT run git add — leave the index as it was after the
  # baseline commit. The working tree now diverges from the index exactly
  # as it does in the operator's PROJECT_DIR.
}
```

**Why this produces correct git status for all three cases:**

| Case | After archive commit | After rsync overlay | git status result |
|---|---|---|---|
| Untracked file | Not in index, not on disk | Copied onto disk | `?? hello-world.txt` ✅ |
| Tracked file with edits | Committed version in index and on disk | Edited version overwrites disk copy | `M foo.py` ✅ |
| Tracked deletion | Committed version in index and on disk | rsync `--delete` removes it from disk | `D foo.py` ✅ |
| Tracked file, no changes | Committed version in index and on disk | rsync copies same content | Clean ✅ |
| Gitignored file | Not in archive, not in index | Not copied by rsync | Not visible ✅ |

**`PROJECT_DIR` availability inside the container:**

`snapshot_init_git` runs inside the capability layer container. `PROJECT_DIR` is not mounted there. The `git archive` call cannot reach `PROJECT_DIR` directly.

Two options:

**Option A (preferred):** Run `git archive HEAD` on the host in `start_agent.sh` and write the tar into `.snapshot/baseline.tar` alongside the rsync copy. The container unpacks it. This keeps all host-side git operations on the host side, consistent with the existing architecture boundary.

**Option B:** Pass the baseline SHA into the container and run `git archive` against `.snapshot/` if it contains a `.git/` directory. This requires `.snapshot/` to carry git metadata, which it currently does not and should not.

Option A is the correct architecture. The split becomes:

- Host (`start_agent.sh`): rsync working tree → `.snapshot/`, then `git -C "$PROJECT_DIR" archive HEAD > "$SNAPSHOT_DIR/baseline.tar"`
- Container (`snapshot_init_git`): unpack `baseline.tar` → commit as baseline → rsync overlay from `.snapshot/` → leave index alone


## What changed

### `libs/snapshot.sh`

| Change | Detail |
|---|---|
| `snapshot_copy_worktree` | Unchanged from the rsync-based implementation. Correctly copies the working tree including untracked non-ignored files. |
| `snapshot_archive_head` | **New function.** Runs `git archive HEAD` on the host and writes `baseline.tar` to `DEST_DIR`. Produces a tar containing exactly the committed state at HEAD — no working tree changes, no untracked files. |
| `snapshot_validate` | **New check.** Fails if `baseline.tar` is absent. Enforces the new pipeline contract at both gate 1 (host) and gate 2 (container). |
| `snapshot_copy_to_sandbox` | **Changed.** Now copies only `baseline.tar` into `SANDBOX_DIR`. Full working tree arrives via the rsync overlay inside `snapshot_init_git` after the baseline commit is made. |
| `snapshot_init_git` | **Rewritten.** New signature: `snapshot_init_git SANDBOX_DIR SNAPSHOT_DIR`. Two-step design: (1) unpack `baseline.tar`, `git add -A && git commit` — index reflects HEAD only; (2) rsync overlay from `SNAPSHOT_DIR` with `--delete`, index not touched — working tree reflects operator's on-disk state. No internal `cd`; all git operations use `-C`. |
| `snapshot_enumerate_files` | **Deleted.** Deprecated index-driven function. |
| `snapshot_copy_files` | **Deleted.** Deprecated index-driven function. |

### `libs/sandbox-entrypoint.sh` (moved from `scripts/`)

| Change | Detail |
|---|---|
| Moved to `libs/` | Aligns with other capability layer libs. Baked into the image via `build_context_sandbox` alongside `snapshot.sh`, `diff.sh`, and `dirs.sh`. |
| `snapshot_init_git` call | **Updated** to pass `$SNAPSHOT_DIR` as second argument. |
| `cd "$ROOT"` recovery | **Removed.** `snapshot_init_git` no longer changes directory internally. |
| File count check | **Moved** to after `snapshot_init_git` completes. Count now excludes `.git/`. |
| Working tree status log | **Added** after `snapshot_init_git`. Prints `git status --short` so operator can confirm sandbox state from container logs. |

### `scripts/start_agent.sh`

| Change | Detail |
|---|---|
| `snapshot_archive_head` call | **Added** immediately after `snapshot_copy_worktree` in the snapshot pipeline block. |

### `tests/test_snapshot_host.sh`

| Change | Detail |
|---|---|
| `test_worktree_copies_edited_version_of_tracked_file` | **New.** Verifies rsync copies the on-disk edited version of a tracked file, not the committed version. |
| `snapshot_archive_head` tests (6) | **New.** Covers: tar produced, committed files present, untracked files absent, unstaged edits absent, failure on no commits, destination auto-creation. |
| `snapshot_validate` missing baseline.tar test | **New.** Covers the new baseline.tar gate check. |
| Deprecated tests (7) | **Deleted.** All tested `snapshot_enumerate_files` and `snapshot_copy_files` which no longer exist. |

### `tests/test_snapshot_container.sh`

| Change | Detail |
|---|---|
| Eight-case working tree matrix | **New.** Cases: (1) clean, (2) unstaged edit, (3) staged edit, (4) unstaged deletion, (5) staged deletion, (6) untracked file, (7) gitignored file, (8) staged new file. Each asserts `git status --porcelain` output. |
| Structural tests (3) | **New.** One baseline commit, returned SHA matches, missing baseline.tar fails cleanly. |
| `snapshot_copy_to_sandbox` test | **Updated.** Asserts only `baseline.tar` copied, working tree files absent. |
| `resync_snapshot` fixture helper | **Fixed.** Now uses rsync with `--delete` and `--exclude='baseline.tar'` so deletions in `PROJECT_DIR` are mirrored into `SNAPSHOT_DIR` correctly during test setup. |
| Old `snapshot_init_git` tests (3) | **Replaced** by the above. |

### Documentation

| File | Change |
|---|---|
| `docs/architecture/sandbox_lifecycle.md` | Phase 1 rewritten: Stage 1 describes `snapshot_archive_head`; Stage 2 describes the two-step init. Four-case correctness table added. |
| `docs/devlog/discussions/design_git_workflow_improvements.md` | Change 4 rewritten as "archive HEAD + rsync overlay" with eight-case working tree state table and full design rationale. |
| `20260412-02-m2_3_onhold.md` | Frozen with status note and forward pointer. Not modified further. |
| `investigation_git_worktrees.md` | Stripped to worktree-mechanism content only. |

---

## Rebuild behaviour

All files under `libs/` — including `sandbox-entrypoint.sh`, `snapshot.sh`, `diff.sh`, and `dirs.sh` — are baked into the capability layer image via `build_context_sandbox`. Changes to any of them require a rebuild.

| File | How it reaches the container | Rebuild needed? |
|---|---|---|
| `libs/sandbox-entrypoint.sh` | Baked in via `build_context_sandbox` | **Yes** |
| `libs/snapshot.sh`, `diff.sh`, `dirs.sh` | Baked in via `build_context_sandbox` | **Yes** |
| `scripts/start_agent.sh` | Runs on host only | No |
| `scripts/sandbox-entrypoint.sh` | No longer exists — moved to `libs/` | — |

This session changed `libs/sandbox-entrypoint.sh` (content changes + move from `scripts/`) and `libs/snapshot.sh`. A rebuild is required before the next run:

```bash
make start PROVIDER=<n> REBUILD=1
```

---

## Root cause (for the record)

The original `snapshot_init_git` ran `git add -A && git commit` after `snapshot_copy_to_sandbox` had already copied the full working tree into sandbox. This collapsed all working tree state — unstaged edits, untracked files, deletions — into the baseline commit. The agent saw a clean `git status` regardless of the operator's actual state.

A previous session proposed fixing this by switching the copy step from rsync to `git ls-files`. This solved the untracked file case but reintroduced hard failures on unstaged deletions and produced an incorrect baseline for tracked files with unstaged edits.

The correct fix separates two concerns: `git archive HEAD` builds the baseline independently of the working tree; rsync then layers the working tree state on top without touching the index.

---

## Acceptance criteria — all passed

| AC | Description | Result |
|---|---|---|
| AC-SB-1 | Untracked file shows as `??` | ✅ |
| AC-SB-2 | Tracked file with unstaged edits shows as `M` (unstaged), baseline contains original | ✅ |
| AC-SB-3 | Tracked file with staged edits: content correct, staging state lost (expected) | ✅ |
| AC-SB-4 | Tracked file deleted without staging shows as `D`, present in baseline | ✅ |
| AC-SB-5 | Tracked file staged for deletion: absent from working tree, present in baseline | ✅ |
| AC-SB-6 | Gitignored file absent from sandbox | ✅ |
| AC-SB-7 | Clean working tree shows clean status | ✅ |
| AC-SB-8 | Exactly one baseline commit, `git diff HEAD` empty | ✅ |

---

## Next session

Change 4 is complete. The next task is atomicizing Changes 1–3 from `20260412-02-m2_3_onhold.md`. Each gets its own handover. Suggested order: Change 1 (checkpoint tag, `start_agent.sh`) → Change 2 (format-patch, `libs/diff.sh`) → Change 3 (draft/confirm/reject, `apply_workspace.sh`), since each depends on the previous.

Before starting Change 1, read `20260412-02-m2_3_onhold.md` for the frozen design and `docs/devlog/discussions/design_git_workflow_improvements.md` for the current spec.
