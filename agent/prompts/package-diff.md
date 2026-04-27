---
description: Package changed files and a unified diff into the workspace output mount for handoff or migration. Use this skill whenever the agent has made changes that need to be shipped to the operator — e.g. "package up my work", "export these changes", "prepare a diff for review", "ship this", or any request to bundle, export, or hand off the current session's work. Also use when preparing a mid-session checkpoint before a risky operation. Packaging does not affect session status — do not edit any of the session file contents while packaging.
trigger: /package-diff
---
Package the current session's changes for export via the workspace output mount.

## Steps

### 1. Run the packaging script

Inside the container, invoke the script directly — the git alias is not registered in
the sandbox `.git/config`:

```bash
bash ~/sandbox/libs/package_diff.sh
```

On the host, use the git alias registered by `agent-sandbox onboard`:

```bash
git package-diff
```

**Default behaviour:** packages all uncommitted working tree changes against `HEAD`.

**To package all changes since session start** (committed and uncommitted):

```bash
bash ~/sandbox/libs/package_diff.sh --baseline="$BASELINE_SHA"
```

`BASELINE_SHA` is an environment variable set by the container entrypoint. If it is not
set, the script falls back to reading `.git/INIT_SHA` (written by `snapshot_init_git`
at container startup), then to the first commit in the repo. All three are tried
automatically — inside the container `--baseline` is never required.

On the host, `--baseline` is mandatory. There is no synthetic baseline outside the
container and no default is applied.

**Always supply `--session-summary`** — the agent knows what changed and should name the output accordingly. The summary should be a concise snake_case phrase describing the nature of the change, like a handover filename: specific enough that a reader scanning a list of output directories knows what is inside without opening it.

```bash
bash ~/sandbox/libs/package_diff.sh --baseline="$BASELINE_SHA" --session-summary=add_session_scoped_artefact_dirs
bash ~/sandbox/libs/package_diff.sh --baseline="$BASELINE_SHA" --session-summary=fix_snapshot_baseline_working_tree
bash ~/sandbox/libs/package_diff.sh --baseline="$BASELINE_SHA" --session-summary=refactor_compose_generation
```

Good summaries: `add_format_patch_support`, `fix_autosave_path_regression`, `update_provider_entrypoint`
Bad summaries: `changes`, `update_files`, `misc`, `package`

The output directory format is `diffs/<EXPORT_TIME>-<SESSION_SUMMARY>-<SESSION_TS>/`. The
`EXPORT_TIME` is injected automatically from the time of script invocation — you do not control it and do not need to. `SESSION_TS` is read from the environment variable set by the container entrypoint. Omitting `--session-summary` falls back to "snapshot"; this is a safety net, not the intended path.

**Legacy flag:** `--name=<label>` is accepted as an alias for `--session-summary`.

The script produces:
- `<outdir>/changes.diff` — unified diff against baseline, index lines stripped,
  suitable for `git apply`

It prints the output directory path and diff size on completion.

### 2. Write `migration-guide.md`

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
git apply changes.diff
```

If the diff might have conflicts or was generated outside the container, strip index
lines before applying:

```bash
grep -v '^index ' changes.diff | git apply --reject
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
