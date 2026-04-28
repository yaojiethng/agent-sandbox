---
description: Package committed branch history as numbered diffs for structured review. Use this skill when the agent has committed work that needs to be reviewed as a series of shaped commits — e.g. "package my branch", "export my commits", "prepare a commit series for review". Also use when the operator requests a full re-export of the session's committed work. Packaging does not affect session status — do not edit any of the session file contents while packaging.
trigger: /package-branch
---
> $@

Package all commits since `init_sha` for export via the workspace output mount.

## 1. Run the packaging script

Inside the container, invoke the script directly:

```bash
bash ~/sandbox/libs/package_branch.sh --session-summary=add_format_patch_support
```

This auto-resolves `init_sha` and `session_ts` from `~/sandbox/.git/SESSION_STATE` and writes output to `bundles/<EXPORT_TIME>-<SESSION_SUMMARY>-<SESSION_TS>/`.
If `SESSION_STATE` is missing, the script aborts with a clear error.

Always supply `--session-summary` — a concise snake_case phrase describing the nature of the change.
Good summaries: `add_format_patch_support`, `fix_autosave_path_regression`, `update_provider_entrypoint`.
Bad summaries: `changes`, `update_files`, `misc`, `package`.

The script produces one numbered `.diff` file per commit since `init_sha`:

```
bundles/<EXPORT_TIME>-<SESSION_SUMMARY>-<SESSION_TS>/
  0001-<sha>.diff
  0002-<sha>.diff
  ...
```

Each `.diff` is a unified diff with index lines stripped, suitable for sequential `git apply`.
The numbered order reflects commit history from `init_sha` to `HEAD`.

## 2. Write `migration-guide.md`

Write `migration-guide.md` in the output directory.
The script does not generate this — it requires reasoning about the changes.

Required sections:

**What changed and why**
Root cause in 2–3 sentences.
Not a list of files — explain the motivation and the problem being solved.

**Changed files**
Table: `| File | Nature of change |`.
One row per file.
Nature of change: added, modified, deleted, or renamed.
For modifications add a brief phrase: "modified — added session-scoped artefact directory support".

**Deleted code**
Describe any functions, classes, or blocks removed and why.
If nothing was deleted, write "None."

**How to apply**

The operator applies the numbered diffs to a draft branch for structured review:

```bash
make draft [SESSION=<path>] [BRANCH_SUMMARY=<slug>]
```

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

**API breaking changes**
List any changes to function signatures, environment variables, file paths, or CLI flags that callers must update.
If none, write "None."

**Verification**
The command the operator should run to confirm the change works.
Be specific — name the test file or the make target.

**Snapshot invariant**
Include this section only if the change touches `libs/snapshot.sh`, `sandbox-entrypoint.sh`, or any script in the snapshot pipeline:
> The snapshot invariant is unchanged — baseline commit correctly represents `HEAD`, working tree overlay applied via rsync with `--delete`.
Omit entirely if the snapshot pipeline is not affected.
