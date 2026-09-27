---
description: Package committed branch history as numbered diffs for structured review. Use this skill when the agent has committed work that needs to be reviewed as a series of shaped commits  --  e.g. "package my branch", "export my commits", "prepare a commit series for review". Also use when the operator requests a full re-export of the iteration's committed work. Packaging does not affect iteration status  --  do not edit any of the iteration file contents while packaging.
trigger: /package-branch
---
> $@

Package all commits since `init_sha` for export via the workspace output mount. Execute the following steps immediately. This task is independent of iteration open housekeeping  --  do not read the handover or roadmap first. Run the script, write the guide, then resume normal iteration flow.

## 1. Choose the bundle summary and draft the guide content

`--bundle-summary` is a short snake_case label that names the export. It must describe the change set this export contains. Derive it from the commit subjects since `init_sha`; never reuse a previous export's summary or a remembered value.

A good summary names the dominant change in the package. Examples: `fix_autosave_path_regression`, `update_provider_entrypoint`. A bad summary is generic or empty. Examples: `changes`, `update_files`, `misc`, `package`, `snapshot`.

State your proposed bundle summary before running the script. Along with the one-line summary, state the draft content for these guide sections: `What changed and why`, `API breaking changes`, `Changed files`, and `Verification`. Follow the content rules under step 3 for each section.

## 2. Run the packaging script

Inside the container, invoke the script with the summary you chose in step 1:

```bash
bash /opt/sandbox/lib/package_branch.sh --to=$HOME/workspace/output --bundle-summary=<summary>
```

The script auto-resolves `init_sha` and `session_ts` from `~/sandbox/.git/SESSION_STATE` and writes output to `<to>/bundles/<EXPORT_TIME>-<BUNDLE_SUMMARY>[-<SESSION_ID>]/`. If `SESSION_STATE` is missing, the script aborts with a clear error.

**To diff against an explicit baseline:**

```bash
bash /opt/sandbox/lib/package_branch.sh --to=$HOME/workspace/output --baseline=<sha> --bundle-summary=<summary>
```

The script produces one numbered `.diff` file per commit since `init_sha`, with the commit subject embedded in the filename, plus a sibling `.msg` file with the full commit message:

```text
<to>/bundles/<EXPORT_TIME>-<BUNDLE_SUMMARY>[-<SESSION_ID>]/
  patches/
    0001-<sha>-<subject>.diff     --  per-commit diff (index lines stripped)
    0001-<sha>-<subject>.msg      --  full original commit message
    0002-<sha>-<subject>.diff
    0002-<sha>-<subject>.msg
    ...
  uncommitted.diff
  all-changes.diff
  changed-files/
    MANIFEST.txt
```

The `.msg` files are consumed by `make draft` to recreate commits with their original messages. Each `.diff` is a unified diff with index lines stripped, suitable for sequential `git apply`. The numbered order reflects commit history from `init_sha` to `HEAD`.

On the host, invoke via:

```bash
agent-sandbox package-branch --sandbox=<path> [--bundle-summary=<text>] [--baseline=<sha>]
make package-branch [BUNDLE_SUMMARY=<text>] [BASELINE=<sha>]
```

The baseline defaults to `git merge-base <init_sha> HEAD`: `init_sha` without a rebase, and the branch point after one. Pass `--baseline=<sha>` (or `BASELINE=<sha>`) only to override it. In a `make draft` invocation the same commit is `BRANCH_FROM=<sha>`, never `--branch-from=<sha>`. See `/package-rebase` for the rebase case.

After the script finishes, echo its final lines to the conversation. The script outputs three lines on stderr  --  repeat them so the operator sees the bundle path and the `make draft` command immediately. The last line is always the actionable next step; echo it, then write the guide.

## 3. Write the migration guide

Write `migration-guide.md` in the output directory. The script does not generate it. Assemble it from the content you drafted in step 1. Use this template:

```text
# Migration Guide - <bundle-summary>

Bundle: <bundle-id>
<N> commits, <no|with> uncommitted changes.

## What changed and why

## API breaking changes

## Changed files

## Verification

## How to apply
```

Fill the placeholder bundle id and commit count from the packaging output. Reconcile the `Changed files` table against `changed-files/MANIFEST.txt` in the packaging output.

Each section holds the following content:

- `What changed and why` -- describe the work done in this change set: the problem it solves and how it solves it. Explain motivation, not a list of files. Include any major deletions here.
- `API breaking changes` -- list changes to function signatures, environment variables, file paths, or CLI flags that callers must update. If none, write "None."
- `Changed files` -- table with columns File and Nature of change. Nature of change is one of added, modified, deleted, or renamed. No remarks column.
- `Verification` -- state that the operator runs the unit test suite to confirm the change works. Add to this section only checks that only the operator can run on the host, such as `make dry-run`. Name the test file or the make target.
- `How to apply` -- pure prose: how the operator applies the numbered diffs to a draft branch for structured review, how review completes (rebase and confirm) or the draft is discarded (reject), and how to apply a single diff without a branch. Name the commands inline. When the export diffed from a rebased branch point, state the soft-reset path: `make confirm TARGET_BRANCH=<new-branch> NEW=1`, then the printed `git switch <original-branch>` and `git reset --soft <new-branch>` direction.
