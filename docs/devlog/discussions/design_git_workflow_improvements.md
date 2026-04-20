# Design — Git Workflow Improvements

**Status:** Tracks in-progress changes to the git-facing pipeline. Superseded as design reference. 
**Target milestone:** M2.3

> **Superseded.** This document is retained as an implementation log for M2.3 Changes 1–4.
> The authoritative design reference for the apply workflow, baseline advancement, and diff
> primitives is [`design_apply_workflow_and_baseline_advancement.md`](design_apply_workflow_and_baseline_advancement.md).
> This document is pending deletion once Changes 1–4 are fully committed and the
> implementation record is fully reflected in implementation handovers and no longer needed for active reference.

---

## Context

Four changes have been identified across two sessions of analysis. Changes 1–3 target the apply workflow and are on hold pending Change 4 completion (see `20260412-02-m2_3_onhold.md`). Change 4 is the active work — its original rsync-only design was found to be incorrect and has been replaced by the archive HEAD + rsync overlay design described below.

---

## Change 1 — Pre-session checkpoint tag

**File:** `scripts/start_agent.sh`

**What:** Before the snapshot runs, create a lightweight git tag in PROJECT_DIR:

```
agent-checkpoint/<worktree-id>/YYYYMMDD-HHMMSS
```

The worktree ID is a short hash of the project path (e.g., `a1b2c3d4`), namespacing checkpoint tags per-worktree.

Write the tag name to `$SANDBOX_DIR/.workspace/checkpoint-latest.ref` so `apply_workspace.sh` can read it for correlation.

**Why:** Gives the operator a known-good recovery point before any session work. If the session produces a bad diff that corrupts PROJECT_DIR after apply, the operator can recover with:

```bash
git reset --hard "$(cat .workspace/checkpoint-latest.ref)"
```

**Why a tag, not a branch:** A tag is a point-in-time marker. It doesn't imply a line of development, doesn't move, and has a clear semantic: "PROJECT_DIR was here before this session." Branches are for development lines.

**Tag cleanup:** Keep the 5 most recent `agent-checkpoint/<worktree-id>/*` tags. On each new tag creation, delete any beyond the 5 most recent (sorted by tag name, which is chronological given the `YYYYMMDD-HHMMSS` format). Pruning is scoped to the worktree namespace.

**Files changed:** `scripts/start_agent.sh`

---

## Change 2 — Format-patch generation + session-scoped artefact directory

**Files:** `libs/diff.sh`, `scripts/start_agent.sh`

**Session naming:** At session start, `start_agent.sh` derives a session name from the current branch and the checkpoint timestamp:

```bash
BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
SANITIZED=$(echo "$BRANCH" | tr '/' '-')
SESSION_NAME="${SANITIZED}-${CHECKPOINT_TS}"   # e.g. main-20260407-112344
```

`SESSION_NAME` is passed to the container as an environment variable. All session artefacts are written under a session-scoped directory:

```
.workspace/changes/<session-name>/staged.diff
.workspace/changes/<session-name>/patches/0001-....patch
.workspace/changes/<session-name>/patches/0002-....patch
```

Multiple sessions accumulate cleanly without clobbering each other.

**`diff_format_patch`** runs inside the capability layer container:

```bash
git format-patch "$BASELINE_SHA"..HEAD \
  --output-directory "$CHANGES_DIR/$SESSION_NAME/patches/"
```

Produces one numbered `.patch` file per agent commit. Degenerate cases:
- Agent made no commits: `diff_commit_pending` creates one sweep commit. Format-patch generates one patch from it.
- Agent made no changes: `diff_generate` no-ops; `diff_format_patch` also no-ops.

Both artefacts are produced:
- `<session-name>/staged.diff` — flat aggregate. Human overview artefact.
- `<session-name>/patches/*.patch` — per-commit patches. Machine apply artefact.

**Commit authorship:** The agent writes its own commits during the session. The author identity is reset to the operator's `git config` at `make draft` time via per-patch `--author` amend. Commit messages are used as-is.

**Files changed:** `libs/diff.sh`, `scripts/start_agent.sh`

---

## Change 3 — Apply workflow

**File:** `scripts/apply_workspace.sh`

**What:** Replace `make apply` with three commands: `make draft`, `make confirm`, `make reject`.

**`make draft [SESSION=<name>]`**

Locates the session artefact directory (most recent under `.workspace/changes/` if `SESSION` not specified). Creates a working branch named `agent/draft/<session-name>` from the checkpoint tag. Applies all patches in order via `git am --3way` with per-patch author reset. Writes `.workspace/draft-state`:

```
SOURCE_BRANCH=main
WORKING_BRANCH=agent/draft/main-20260407-112344
SESSION_DIR=.workspace/changes/main-20260407-112344
```

Exits with the operator on the working branch. Review using any git tool.

**`make confirm [TARGET=<branch>]`**

Reads `.workspace/draft-state`. Target branch is `SOURCE_BRANCH` unless `TARGET` is supplied.

Sequence:
1. `git rebase <target>` on the working branch.
2. `git switch <target>`
3. `git merge --ff-only <working-branch>`
4. Delete working branch. Clear `.workspace/draft-state`.

History is always linear. No merge commit is created.

**`make reject`**

Reads `.workspace/draft-state`. Checks out `SOURCE_BRANCH`. Deletes the working branch without merging. Clears `.workspace/draft-state`. Session artefacts retained.

**Backwards compatibility:** `make apply --mode=apply` retains the old `git apply` behaviour for sessions from older harness versions that predate format-patch.

**Author reset loop:**

```bash
AUTHOR="$(git config user.name) <$(git config user.email)>"
for patch in "$SESSION_DIR/patches/"*.patch; do
  git am --3way "$patch" || exit 1
  git commit --amend --author="$AUTHOR" --no-edit
done
```

**Files changed:** `scripts/apply_workspace.sh`, `Makefile.template`
**Dependency:** Change 2 (session-scoped artefact directory, `SESSION_NAME` env var)

---

## Change 4 — archive HEAD + rsync overlay

**Files:** `libs/snapshot.sh`, `scripts/start_agent.sh`

**Status:** Active. Replaces the previous rsync-only design, which was found to produce an incorrect baseline commit.

### The Problem

The previous design used rsync to copy the working tree into `.snapshot/`, then ran `git init && git add -A && git commit -m "baseline"` inside the container. This collapses the entire working tree — including unstaged edits, new files, and deletions — into the baseline commit. When the agent runs `git status`, it sees a clean working tree regardless of the operator's actual state.

The core issue: the baseline commit is supposed to represent `HEAD` in `PROJECT_DIR`. But `git add -A` commits the working tree, not HEAD. These diverge whenever the operator has any uncommitted changes.

### The Four Cases

Any correct design must handle all four cases:

| Working tree state | Required sandbox git status |
|---|---|
| Untracked file (`hello-world.txt` never committed) | `?? hello-world.txt` |
| Tracked file with unstaged edits (`foo.py` modified but not staged) | `M foo.py` (unstaged) |
| Tracked file deleted without staging (`rm bar.txt`, not `git rm`) | `D bar.txt` (unstaged) |
| Tracked file, no changes | Clean |

The naive "skip unstaged files from `git add`" approach fails case 2: if you don't add `foo.py`, it's absent from the baseline entirely, not present at the committed version.

### The Design

The key insight: construct the baseline commit from `HEAD` directly — independent of the working tree — then overlay the working tree on top without touching the index.

**Host side (`scripts/start_agent.sh`):**

After `snapshot_copy_worktree` (rsync copy of working tree into `.snapshot/`), produce a git archive of HEAD:

```bash
git -C "$PROJECT_DIR" archive HEAD > "$SNAPSHOT_DIR/baseline.tar"
```

This runs on the host where `PROJECT_DIR` is available. The tar contains exactly the committed state at HEAD — no working tree changes, no untracked files, no index state. It is written into `.snapshot/` alongside the rsync copy so both are available to the container.

**Container side (`snapshot_init_git` in `libs/snapshot.sh`):**

```bash
snapshot_init_git() {
  local sandbox_dir="$1"
  local snapshot_dir="$2"

  # Step 1: initialise repo and commit exactly HEAD via the archive
  git init "$sandbox_dir"
  git -C "$sandbox_dir" config user.email "sandbox@agent"
  git -C "$sandbox_dir" config user.name "sandbox"

  local archive_dir
  archive_dir=$(mktemp -d)
  tar -x -C "$archive_dir" < "$snapshot_dir/baseline.tar"
  cp -a "$archive_dir/." "$sandbox_dir/"
  rm -rf "$archive_dir"

  git -C "$sandbox_dir" add -A
  git -C "$sandbox_dir" commit -m "baseline" --allow-empty
  git -C "$sandbox_dir" rev-parse HEAD > "$sandbox_dir/.git/BASELINE_SHA"

  # Step 2: overlay the rsync working tree copy on top of the baseline
  # rsync --delete ensures files absent from the working tree (deletions)
  # are also absent from sandbox/. The index is NOT updated — working tree
  # diverges from index exactly as it does in PROJECT_DIR.
  rsync -a --delete \
    --exclude='.git' \
    "$snapshot_dir/" "$sandbox_dir/"

  # Step 3: do not run git add. The index reflects HEAD (the baseline commit).
  # The working tree reflects the operator's current state.
  # git status will now show the correct diff between the two.
}
```

**Why this is correct for all four cases:**

| Case | After archive + commit | After rsync overlay | git status |
|---|---|---|---|
| Untracked file | Not in index, not on disk | rsync copies it onto disk | `?? hello-world.txt` ✅ |
| Tracked file with edits | Committed version in index and on disk | Edited version overwrites disk copy | `M foo.py` ✅ |
| Tracked deletion | Committed version in index and on disk | `--delete` removes it from disk | `D bar.txt` ✅ |
| No changes | Committed version in index and on disk | rsync copies identical content | Clean ✅ |
| Gitignored file | Not in archive, not in index | rsync excludes it | Not visible ✅ |

**Why rsync is still correct for the copy step:**

rsync `--filter=':- .gitignore'` reads per-directory `.gitignore` files and applies them during the copy. It copies what is on disk (working tree), not what is in the index. This is correct for producing the working tree overlay. The previous design's error was not in rsync — it was in committing the rsync output directly as the baseline.

**Residual limitation — negation patterns in global gitignore:**

rsync's `--exclude-from` (used for `core.excludesFile` and `.git/info/exclude`) does not support gitignore-style negation patterns (`!foo`). Negation patterns in global gitignore or `.git/info/exclude` are silently ignored. This is uncommon in practice (negations are rare in global configs) and is a documented gap. Negation patterns in local per-directory `.gitignore` files are handled correctly by `--filter=':- .gitignore'`.

**Submodule pre-flight:** The existing submodule check is retained as a separate pre-flight step before the rsync call. It is unaffected by this change.

**API change in `snapshot.sh`:**

`snapshot_init_git` gains a second parameter: `snapshot_dir` (path to the rsync copy). Callers: capability layer entrypoint only. The function signature becomes:

```bash
snapshot_init_git SANDBOX_DIR SNAPSHOT_DIR
```

**Files changed:** `libs/snapshot.sh`, `scripts/start_agent.sh`

---

## Open Questions

All open questions resolved.

| # | Question | Resolution |
|---|---|---|
| OQ-1 | Checkpoint tag retention policy | Keep last 5. On each new tag creation, prune any `agent-checkpoint/*` tags beyond the 5 most recent. |
| OQ-2 | Session metadata / author amendment | No `session.json`. Agent writes its own commit messages. Author identity reset to operator's `git config` at apply time via `--author` amend per patch. |
| OQ-3 | How to make baseline commit represent HEAD without mounting PROJECT_DIR in container | Produce `baseline.tar` via `git archive HEAD` on the host side in `start_agent.sh`, write it into `.snapshot/`. Container unpacks it to form the baseline commit. |
