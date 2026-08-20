---
description: Package committed branch history as numbered diffs for structured review. Use this skill when the agent has committed work that needs to be reviewed as a series of shaped commits — e.g. "package my branch", "export my commits", "prepare a commit series for review". Also use when the operator requests a full re-export of the iteration's committed work. Packaging does not affect iteration status — do not edit any of the iteration file contents while packaging.
trigger: /package-branch
---
> $@

Package all commits since `init_sha` for export via the workspace output mount. Execute the following steps immediately. This task is independent of iteration open housekeeping — Do not read the handover or roadmap first. Run the script, write the guide, then resume normal iteration flow.

## 1. Run the packaging script

Inside the container, invoke the script with an explicit output base directory
and a descriptive `--session-summary`:

```bash
bash /opt/sandbox/lib/package_branch.sh --to=$HOME/workspace/output --session-summary=add_format_patch_support
```

`--session-summary` is required — the script aborts with a usage message if
omitted. Provide a concise snake_case phrase describing the nature of the change.
Good summaries: `add_format_patch_support`, `fix_autosave_path_regression`, `update_provider_entrypoint`.
Bad summaries: `changes`, `update_files`, `misc`, `package`, `snapshot`.

This auto-resolves `init_sha` and `session_ts` from `~/sandbox/.git/SESSION_STATE`
and writes output to `<to>/bundles/<EXPORT_TIME>-<SESSION_SUMMARY>[-<SESSION_ID>]/`.
If `SESSION_STATE` is missing, the script aborts with a clear error.

**To diff against an explicit baseline:**

```bash
bash /opt/sandbox/lib/package_branch.sh --to=$HOME/workspace/output --baseline=<sha> --session-summary=<text>
```

The script produces one numbered `.diff` file per commit since `init_sha`, with
the commit subject embedded in the filename, plus a sibling `.msg` file with the
full commit message:

```
<to>/bundles/<EXPORT_TIME>-<SESSION_SUMMARY>[-<SESSION_ID>]/
  patches/
    0001-<sha>-<subject>.diff    — per-commit diff (index lines stripped)
    0001-<sha>-<subject>.msg     — full original commit message
    0002-<sha>-<subject>.diff
    0002-<sha>-<subject>.msg
    ...
  uncommitted.diff
  all-changes.diff
  changed-files/
    MANIFEST.txt
```

The `.msg` files are consumed by `make draft` to recreate commits with their
original messages. Each `.diff` is a unified diff with index lines stripped,
suitable for sequential `git apply`. The numbered order reflects commit history
from `init_sha` to `HEAD`.

On the host, invoke via:
```bash
agent-sandbox package-branch --sandbox=<path> [--session-summary=<text>]
make package-branch [SESSION_SUMMARY=<text>]
```

## 1.5 Echo completion message

After the script finishes, echo its final lines to the conversation. The script
outputs three lines on stderr — repeat them verbatim so the operator sees the
bundle path and the `make draft` command immediately:

```
package_branch: artefacts written to:
  /home/agentuser/workspace/output/bundles/20260523-112813-<summary>-20260523-042607

To draft this bundle on host, run:
  make draft FROM=bundles SESSION=20260523-112813-<summary>-20260523-042607 BRANCH_SUMMARY=<slug>
```

The script's last line is always the actionable next step — echo it, then
proceed to write the migration guide.

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
For modifications add a brief phrase: "modified — added iteration-scoped artefact directory support".

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
