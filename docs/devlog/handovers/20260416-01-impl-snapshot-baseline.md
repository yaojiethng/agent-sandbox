# Agent Handover

**Session date:** 2026-04-16
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation

## Objective

Redesign and implement `snapshot_init_git` so that the sandbox git state correctly reflects the operator's working tree: committed state as the baseline commit, working tree modifications present but unstaged, untracked files present but untracked.

## Scope

Single function: `snapshot_init_git` in `libs/snapshot.sh`, plus the host-side preparation it depends on in `scripts/start_agent.sh`. All other M2.3 changes are out of scope for this session — see `20260412-02-impl-m2_3.md` for their frozen state.

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

## Required File Changes

| File | Change |
|---|---|
| `scripts/start_agent.sh` | After `snapshot_copy_worktree`, add: `git -C "$PROJECT_DIR" archive HEAD > "$SNAPSHOT_DIR/baseline.tar"` |
| `libs/snapshot.sh` | Rewrite `snapshot_init_git` per design above. Add `snapshot_copy_to_sandbox` call to unpack baseline.tar, commit, overlay rsync. |
| `docs/architecture/sandbox_lifecycle.md` | Update Phase 1 Stage 1 (baseline.tar produced on host) and Stage 2 (archive unpack → commit → rsync overlay). |
| `tests/test_snapshot_container.sh` | Replace existing `snapshot_init_git` tests with the four-case matrix below. |

## Acceptance Criteria

These are the test specification. They belong in `tests/test_snapshot_container.sh`.

**AC-SB-1 — Untracked file shows as untracked**
```bash
# Setup: project with one committed file (committed.txt). Add hello-world.txt to working tree.
touch "$PROJECT_DIR/hello-world.txt"
make start PROVIDER=<n>
# Inside container:
git -C sandbox/ status --porcelain
# Expected: ?? hello-world.txt
# Not expected: hello-world.txt in git log or git show HEAD
```

**AC-SB-2 — Tracked file with unstaged edits shows as modified**
```bash
# Setup: project with foo.py committed. Edit foo.py without staging.
echo "new content" >> "$PROJECT_DIR/foo.py"
make start PROVIDER=<n>
# Inside container:
git -C sandbox/ status --porcelain
# Expected: M foo.py (unstaged modification)
git -C sandbox/ show HEAD:foo.py
# Expected: original committed content, not the edited content
git -C sandbox/ diff HEAD foo.py
# Expected: shows the edit as an unstaged change
```

**AC-SB-3 — Tracked file deleted without staging shows as deleted**
```bash
# Setup: project with bar.txt committed. Remove it without git rm.
rm "$PROJECT_DIR/bar.txt"
make start PROVIDER=<n>
# Inside container:
git -C sandbox/ status --porcelain
# Expected: D bar.txt (unstaged deletion)
git -C sandbox/ show HEAD:bar.txt
# Expected: file content present in baseline commit
```

**AC-SB-4 — Clean working tree shows clean status**
```bash
# Setup: project with no uncommitted changes.
make start PROVIDER=<n>
# Inside container:
git -C sandbox/ status --porcelain
# Expected: empty output (clean)
```

**AC-SB-5 — Gitignored file is not present in sandbox**
```bash
# Setup: project with .gitignore containing "secret.env". Create secret.env.
echo "API_KEY=abc" > "$PROJECT_DIR/secret.env"
make start PROVIDER=<n>
# Inside container:
ls sandbox/secret.env 2>/dev/null
# Expected: file absent
git -C sandbox/ status
# Expected: no mention of secret.env
```

**AC-SB-6 — Baseline commit is exactly HEAD**
```bash
# Inside container:
git -C sandbox/ log --oneline
# Expected: exactly one commit with message "baseline"
git -C sandbox/ diff HEAD
# Expected: empty (working tree changes are unstaged, not uncommitted diffs from HEAD)
```

**AC-SB-7 — Diff pipeline still produces correct diff after agent edits**
```bash
# This validates that the baseline SHA recorded at init is correct for diff_on_exit.
# Setup: clean project. Start session. Agent edits foo.py and commits.
# After session exit:
cat "$SANDBOX_DIR/.workspace/changes/<session>/staged.diff"
# Expected: diff shows only agent's changes to foo.py, not the working-tree
# state from before the session
```

## Deferred Items

None — this session is scoped to snapshot-baseline only. Changes 1–3 remain in `20260412-02-impl-m2_3.md` on hold.

## Next Session

Once AC-SB-1 through AC-SB-7 pass with operator confirmation, the session closes and Changes 1–3 can begin atomicization. Each will get its own handover derived from `20260412-02-impl-m2_3.md`. Suggested order: Change 1 (checkpoint tag) → Change 2 (format-patch) → Change 3 (draft/confirm/reject), since each depends on the previous.
