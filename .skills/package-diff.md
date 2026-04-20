---
description: Package changed files and a unified diff into the workspace output mount for handoff or migration. Use this skill whenever the agent has made changes that need to be shipped to the operator — e.g. "package up my work", "export these changes", "prepare a diff for review", "ship this", or any request to bundle, export, or hand off the current session's work. Also use when preparing a mid-session checkpoint before a risky operation.
trigger: /package-diff
---
Package the current session's changes for export via the workspace output mount.

## Steps

### 1. Run the packaging script

Use the git alias registered by `agent-sandbox onboard`:

```bash
git package-diff
```

If the alias is not registered, fall back to the direct invocation:

```bash
bash ~/agent-sandbox/libs/package-diff.sh
```

**Default behaviour:** packages all uncommitted working tree changes against `HEAD`.

**To package all changes since session start** (committed and uncommitted):

```bash
git package-diff --baseline="$BASELINE_SHA"
```

`BASELINE_SHA` is an environment variable set by the container entrypoint. If it is not
set, the script falls back to reading `.git/BASELINE_SHA` (written by `snapshot_init_git`
at container startup). Both are always present inside the container.

If neither is available the script exits with an error — this indicates the script is
being run outside the container context, where `--baseline` is required explicitly.

**On the host, `--baseline` is mandatory.** There is no synthetic baseline outside the
container and no default is applied.

**Always supply a descriptive `--name`** — the agent knows what changed and should
name the output accordingly. The name should be a concise snake_case phrase describing
the nature of the change, like a handover filename: specific enough that a reader
scanning a list of output directories knows what is inside without opening it.

```bash
git package-diff --baseline="$BASELINE_SHA" --name=add_session_scoped_artefact_dirs
git package-diff --baseline="$BASELINE_SHA" --name=fix_snapshot_baseline_working_tree
git package-diff --baseline="$BASELINE_SHA" --name=refactor_compose_generation
```

Good names: `add_format_patch_support`, `fix_autosave_path_regression`, `update_provider_entrypoint`
Bad names: `changes`, `update_files`, `misc`, `package`

`--name` produces the directory as-is with no timestamp prefix — use it when the name
is self-describing. `--label` appends a timestamp prefix and is the fallback when the
agent does not supply a name. Omit both only as a last resort; the mechanical derivation
is a safety net, not the intended path.

The script produces:
- `<outdir>/changes.diff` — unified diff against baseline
- `<outdir>/changed-files/` — copies of all changed files, repo-relative paths preserved

It prints the output directory path, file count, and diff size on completion.

**If `libs/package-diff.sh` is not present** (pre-unification harness), fall back to the
original manual steps: enumerate changed files with `git diff --name-only HEAD` and
`git ls-files --others --exclude-standard`, copy them manually, and generate the diff
with `git diff HEAD > changes.diff`.

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

```
Option A — Copy files:
  cp -r changed-files/* /path/to/repo/

Option B — Git apply:
  git apply changes.diff
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
