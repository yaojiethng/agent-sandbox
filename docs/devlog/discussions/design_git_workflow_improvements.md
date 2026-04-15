# Design — Git Workflow Improvements

**Status:** Working document. Tracks all proposed changes to the git-facing pipeline.  
**Target milestone:** M2.3 (Changes 1–3) + Snapshot Hardening (pre-M2.3 or bundled)

---

## Context

Four changes have been identified across two sessions of analysis. Three are the M2.3 targeted changes (checkpoint tag, format-patch generation, apply workflow). One is a pre-existing snapshot pipeline defect exposed during the worktree feasibility investigation.

Open questions are listed per change. No implementation should begin until all open questions for that change are resolved.

---

## Change 1 — Pre-session checkpoint tag

**File:** `scripts/start_agent.sh`

**What:** Before the snapshot runs, create a lightweight git tag in PROJECT_DIR:

```
agent-checkpoint/YYYYMMDD-HHMMSS
```

Write the tag name to `$SANDBOX_DIR/.workspace/checkpoint-latest.ref` so `apply_workspace.sh` can read it for correlation.

**Why:** Gives the operator a known-good recovery point before any session work. If the session produces a bad diff that corrupts PROJECT_DIR after apply, the operator can recover with:

```bash
git reset --hard "$(cat .workspace/checkpoint-latest.ref)"
```

**Why a tag, not a branch:** A tag is a point-in-time marker. It doesn't imply a line of development, doesn't move, and has a clear semantic: "PROJECT_DIR was here before this session." Branches are for development lines.

**Tag cleanup:** Tag creation is in scope; so is pruning. Policy: keep the 5 most recent `agent-checkpoint/*` tags. On each new tag creation, delete any beyond the 5 most recent (sorted by tag name, which is chronological given the `YYYYMMDD-HHMMSS` format).

**Files changed:** `scripts/start_agent.sh`

---

## Change 2 — Format-patch generation + session-scoped artefact directory

**Files:** `libs/diff.sh`, `scripts/start_agent.sh`

**Session naming:** At session start, `start_agent.sh` derives a session name from the current branch and the checkpoint timestamp:

```bash
BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
SANITIZED=$(echo "$BRANCH" | tr '/' '-')   # main, feat-auth, etc.
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

**Commit authorship:** The agent writes its own commits during the session. Commit messages are used as-is. The agent may include model attribution naturally — encouraged, not enforced. No session metadata file needed.

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

Reads `.workspace/draft-state`. Target branch is `SOURCE_BRANCH` unless `TARGET` is supplied (necessary if the source branch no longer exists).

Sequence:
1. On the working branch: `git rebase <target>` — replays draft commits on top of current target HEAD.
2. `git switch <target>`
3. `git merge --ff-only <working-branch>` — always succeeds because working branch is now directly ahead of target.
4. Delete working branch. Clear `.workspace/draft-state`.

History is always linear. No merge commit is created.

If the target branch has not moved since `make draft`, the rebase is a no-op and the fast-forward is trivial. If the target has new commits and there is no conflict, the rebase replays cleanly. If there is a conflict, the rebase stops and the operator resolves normally:

```bash
# resolve conflict markers
git add <resolved files>
git rebase --continue
# or to abort and return to pre-rebase state:
git rebase --abort   # working branch is restored; operator can then make reject
```

On success: working branch deleted, `.workspace/draft-state` cleared. Session artefacts in `.workspace/changes/<session-name>/` retained.

**`make reject`**

Reads `.workspace/draft-state`. Checks out `SOURCE_BRANCH`. Deletes the working branch without merging. Clears `.workspace/draft-state`. PROJECT_DIR returns to exactly the state before `make draft` was called. Session artefacts retained.

**Backwards compatibility:** `make apply --mode=apply` retains the old `git apply` behaviour (flat diff applied to working tree, no commits created) for sessions from older harness versions that predate format-patch.

**Conflict during `make draft`** (`git am` conflict, distinct from `git rebase` conflict during `make confirm`):

```bash
git add <resolved files>
git am --continue
# or to abort the patch application:
git am --abort   # working branch exists in partial state; run make reject to clean up
```

**Author reset loop:**

```bash
AUTHOR="$(git config user.name) <$(git config user.email)>"
for patch in "$SESSION_DIR/patches/"*.patch; do
  git am --3way "$patch" || exit 1
  git commit --amend --author="$AUTHOR" --no-edit
done
```

Author identity comes from the operator's git config at `make draft` time. Commit message and author timestamp preserved from the agent's patch.

**Updated operator workflow:**

```bash
cat .workspace/changes/main-20260407-112344/staged.diff   # optional flat overview
make draft                            # creates agent/draft/main-20260407-112344, applies patches
git log -p HEAD~N..HEAD               # review using any git tool
make confirm                          # merge to main, delete working branch
# or:
make confirm TARGET=other-branch      # if main is gone or operator wants a different target
# or:
make reject                           # discard working branch, return to main
```

**Files changed:** `scripts/apply_workspace.sh`, `Makefile.template`  
**Dependency:** Change 2 (session-scoped artefact directory, `SESSION_NAME` env var)

---

## Change 4 — Working-tree-aware snapshot (rsync)

**File:** `libs/snapshot.sh`

**Problem:** `snapshot_enumerate_files` uses `git ls-files --cached --others --exclude-standard`. `--cached` enumerates the git **index**, not the working tree. The index and working tree diverge whenever the operator has unstaged deletions or unstaged moves. When `snapshot_copy_files` tries to `cp` an index-listed path that doesn't exist on disk, it hard-fails and aborts the snapshot.

Affected scenarios:

| Operator working tree state | Current behaviour | Desired behaviour |
|---|---|---|
| Unstaged deletion (`rm file.txt`) | `cp` fails → snapshot aborts | File absent from snapshot |
| Unstaged move (`mv a.txt b.txt`) | `cp a.txt` fails → snapshot aborts | `a.txt` absent, `b.txt` present |
| Unstaged modification | Working tree version copied ✅ | (unchanged) |
| Unstaged new file | Picked up via `--others` ✅ | (unchanged) |
| Staged deletion (`git rm`) | Correctly excluded ✅ | (unchanged) |

**Root cause:** The current approach is index-driven and corrects toward the working tree imperfectly. It is only coincidentally correct for modifications and new files.

**The right frame:** The invariant is that the agent sees an exact replica of the working tree the operator sees, filtered by `.gitignore`. The working tree is the authoritative source. The index is not.

**Fix:** Replace the `snapshot_enumerate_files` + `snapshot_copy_files` pipeline with a single `rsync` call:

```bash
rsync -a \
  --filter=':- .gitignore' \
  --exclude='.git' \
  "$SOURCE_DIR/" "$DEST_DIR/"
```

rsync enumerates from the filesystem directly. It copies what is on disk. Deletions, moves, and new files all behave correctly because rsync has no concept of an index — it sees what the operator sees.

`--filter=':- .gitignore'` is rsync's dir-merge filter syntax: it reads `.gitignore` in each directory and applies the rules to that directory, including nested `.gitignore` files and `!` negation patterns. `--exclude='.git'` prevents the git directory from being copied.

**Global gitignore and repo-level excludes:** rsync's `--filter=':- .gitignore'` does not read `~/.gitignore_global`, `~/.config/git/ignore` (resolved via `git config core.excludesFile`), or `.git/info/exclude`. These are read explicitly at snapshot time and passed to rsync via `--exclude-from`.

Sequence in `snapshot_copy_worktree`:

1. Resolve global gitignore path: `GLOBAL_IGNORE=$(git -C "$SOURCE_DIR" config --global core.excludesFile 2>/dev/null)`. Expand `~` if present.
2. Collect exclude sources that exist on disk: `GLOBAL_IGNORE` (if non-empty and file exists) and `$SOURCE_DIR/.git/info/exclude` (if exists).
3. Concatenate into a temp file (`mktemp`). If neither source exists, skip `--exclude-from` entirely.
4. Pass `--exclude-from=<tempfile>` to rsync. Clean up temp file after rsync completes (trap on EXIT).

**Warning on global-rule exclusions:** To make it visible when a file is excluded by global/exclude rules (not local `.gitignore`), `snapshot_copy_worktree` performs two rsync dry-runs before the real copy:

- **Dry-run A:** `--filter=':- .gitignore'` only — local rules only. Captures file list.
- **Dry-run B:** same, plus `--exclude-from=<tempfile>` — all rules. Captures file list.

Files present in A but absent in B were excluded solely by global/exclude rules. For each such file, emit a warning to stderr:

```
[snapshot] WARNING: <relative-path> excluded by global gitignore or .git/info/exclude
```

This makes the exclusion visible without blocking the snapshot.

**Residual limitation — negation patterns in `--exclude-from`:** rsync's `--exclude-from` does not support gitignore-style negation patterns (`!foo`). Negation patterns in global gitignore or `.git/info/exclude` will be silently ignored by rsync. This is uncommon in practice (negations are rare in global configs), but is a known and documented gap. Negation patterns in local per-directory `.gitignore` files are handled correctly by `--filter=':- .gitignore'`.

**Comparison with an existence-check fix to `snapshot_copy_files`:**

An existence check (skip missing files rather than aborting) would fix the hard-failure case but the enumeration would still be index-driven. The result would be "index minus what's not on disk" — approximately correct but not semantically correct. rsync copies "what is on disk" directly and is correct by construction.

**Submodule pre-flight:** The current submodule check (`git ls-files --stage | grep '^160000'`) must be kept as a separate validation step before the rsync call. It is a pre-flight guard, not an enumeration step, and is unaffected by this change.

**Scope note:** This change is independent of M2.3 and should land first. It is a correctness defect causing hard failures on common working tree states.

**API change in `snapshot.sh`:** `snapshot_enumerate_files` and `snapshot_copy_files` are replaced by `snapshot_copy_worktree SOURCE_DIR DEST_DIR`. The submodule check moves into `snapshot_copy_worktree` as a pre-flight or stays in `start_agent.sh` as a separate call. Callers: `start_agent.sh` only.

**Files changed:** `libs/snapshot.sh`, `scripts/start_agent.sh`

---


## Open questions

All open questions resolved. No blockers.

| # | Question | Resolution |
|---|---|---|
| OQ-1 | Checkpoint tag retention policy | Keep last 5. On each new tag creation, prune any `agent-checkpoint/*` tags beyond the 5 most recent. |
| OQ-2 | Session metadata / author amendment | Partial. No `session.json`. Agent writes its own commit messages (including model attribution if it chooses). Author identity (name/email) is reset to the operator's `git config` at apply time via `--author` on each amend. Timestamp preserved from sandbox session. |
