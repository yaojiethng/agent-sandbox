---
description: Package committed branch history as numbered diffs for structured review. Use this skill when the agent has committed work that needs to be reviewed as a series of shaped commits — e.g. "package my branch", "export my commits", "prepare a commit series for review". Also use when the operator requests a full re-export of the session's committed work. Packaging does not affect session status — do not edit any of the session file contents while packaging.
trigger: /package-branch
---
Package the current session's committed branch history for export via the workspace output mount.

## Steps

### 1. Run the packaging script

Inside the container, invoke the script directly with the full destination path:

```bash
EXPORT_TIME=$(date -u +%Y%m%d-%H%M%S)
OUTDIR="$HOME/workspace/output/bundles/${EXPORT_TIME}-${SESSION_SUMMARY}-${SESSION_TS}"
INIT_SHA=$(cat ~/sandbox/.git/INIT_SHA)
bash ~/sandbox/libs/package_branch.sh ~/sandbox "$INIT_SHA" "$OUTDIR"
```

**Always supply `SESSION_SUMMARY`** — set it as a shell variable before running the command:

```bash
SESSION_SUMMARY=add_session_scoped_artefact_dirs
EXPORT_TIME=$(date -u +%Y%m%d-%H%M%S)
OUTDIR="$HOME/workspace/output/bundles/${EXPORT_TIME}-${SESSION_SUMMARY}-${SESSION_TS}"
INIT_SHA=$(cat ~/sandbox/.git/INIT_SHA)
bash ~/sandbox/libs/package_branch.sh ~/sandbox "$INIT_SHA" "$OUTDIR"
```

Good summaries: `add_format_patch_support`, `fix_autosave_path_regression`, `update_provider_entrypoint`
Bad summaries: `changes`, `update_files`, `misc`, `package`

The output directory format is `bundles/<EXPORT_TIME>-<SESSION_SUMMARY>-<SESSION_TS>/`. The
`EXPORT_TIME` is injected automatically from the time of script invocation — you do not
control it and do not need to. `SESSION_TS` is read from the environment variable set by
the container entrypoint.

### 2. What the script produces

One numbered `.diff` file per commit since `INIT_SHA`:

```
<outdir>/
  0001-<sha>.diff
  0002-<sha>.diff
  0003-<sha>.diff
  ...
```

Each `.diff` is a unified diff with index lines stripped, suitable for sequential
`git apply`. The numbered order reflects commit history from `INIT_SHA` to `HEAD`.

`INIT_SHA` is the SHA of the root commit written at container init. It defines the
lower boundary — all commits after it belong to the agent session. It never advances;
each `package-branch` invocation produces a full re-export of the branch history.

### 3. Consume the output on the host

The operator applies the numbered diffs to a draft branch for structured review:

```bash
make draft [SESSION=<path>] [BRANCH_SUMMARY=<slug>]
```

This resolves the export folder, creates a `draft/<name>` branch, commits `.draft-state`
as the first commit, and applies each numbered diff sequentially via `git apply`.

After review and commit shaping:

```bash
git rebase -i <source_branch>
make confirm
```

To discard the draft:

```bash
make reject
```

For applying a single diff uncommitted (no branch created):

```bash
make apply DIFF=<path>
```

### 4. Write `migration-guide.md`

Write `migration-guide.md` in the output directory. The script does not generate this —
it requires reasoning about the changes.

Required sections:

**What changed and why**
Root cause in 2–3 sentences. Not a list of files — explain the motivation and the problem
being solved.

**Changed files**
Table: `| File | Nature of change |`. One row per file. Nature of change: added, modified,
deleted, or renamed. For modifications add a brief phrase: "modified — added session-scoped
artefact directory support".

**Deleted code**
Describe any functions, classes, or blocks removed and why. If nothing was deleted, write
"None."

**How to apply**

```bash
make draft SESSION=<path-to-export-folder>
```

Or to apply a single diff uncommitted:

```bash
grep -v '^index ' <path-to-diff> | git apply --reject
```

**API breaking changes**
List any changes to function signatures, environment variables, file paths, or CLI flags
that callers must update. If none, write "None."

**Verification**
The command the operator should run to confirm the change works. Be specific — name the
test file or the make target.

**Snapshot invariant**
Include this section only if the change touches `libs/snapshot.sh`,
`sandbox-entrypoint.sh`, or any script in the snapshot pipeline:
> The snapshot invariant is unchanged — baseline commit correctly represents `HEAD`,
> working tree overlay applied via rsync with `--delete`.
Omit entirely if the snapshot pipeline is not affected.
