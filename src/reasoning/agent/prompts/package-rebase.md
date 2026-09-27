---
description: Export rebase-modified branch history to the host worktree via an explicit branch point. Use when history was rewritten with git rebase and the normal export path (init_sha) can no longer produce an appliable bundle.
trigger: /package-rebase
---
> $@

Export the commits that differ from an explicit baseline, so the operator can apply them onto the host branch after a rebase. Run this prompt when the iteration rewrote history (interactive rebase, fold, or amend) and the export-by-`init_sha` path no longer applies cleanly.

## Baseline resolution

`package_branch.sh` defaults its baseline to `git merge-base <init_sha> HEAD`: the newest commit shared by the session baseline and HEAD. Without a rebase this equals `init_sha`. After a rebase it is the branch point, which is exactly the commit the host still holds, so the exported diffs apply onto the host branch.

An explicit `--baseline=<sha>` override wins over the computed value. Use it only when the host target diverged from the recorded `init_sha`, for example when the operator advanced the host branch during the session.

## Procedure

1. Confirm the branch point the export will use:

```bash
git merge-base "$(grep '^init_sha=' .git/SESSION_STATE | cut -d= -f2)" HEAD
```

2. Run the packaging script. Pass `--baseline=<sha>` only to override the default:

```bash
bash /opt/sandbox/lib/package_branch.sh --to=$HOME/workspace/output --bundle-summary=<summary>
```

3. Report the bundle path and the `make draft` command to the operator. The script prints a concrete hint. In a make invocation the branch point is `BRANCH_FROM=<sha>`, never `--branch-from=<sha>`:

```text
make draft FROM=bundles BUNDLE=<bundle> BRANCH_SUMMARY=<summary> BRANCH_FROM=<branch-point>
```

4. The operator drafts the bundle, then applies it to the host branch.

## Applying a rebased package

A rewritten target history cannot fast-forward, so `make confirm TARGET_BRANCH=<branch>` (the fast-forward path) does not fit. Use the soft-reset mode instead:

```bash
make draft FROM=bundles BUNDLE=<bundle> BRANCH_SUMMARY=<summary> BRANCH_FROM=<branch-point>
make confirm TARGET_BRANCH=<new-branch> NEW=1
```

`NEW=1` requires a branch name that does not exist yet. It creates `<new-branch>` at the draft tip, deletes the draft, and leaves the original target untouched. It prints the operator-run direction that moves the original branch onto the rebased series:

```text
git switch <original-branch>
git reset --soft <new-branch>
```

The reset moves the branch pointer to the rebased series without touching the working tree. When the rebase preserved content, the tree stays clean and no commit is needed.

## Command hints carry a branch point

`package-branch` and `make draft` command hints name a branch point by default, so a rebase-based workflow does not fall back on a stale `init_sha` silently. The operator applies with the recorded point rather than guessing.

## Verification

State that the operator applies the bundle onto the host branch at the branch point and confirms the resulting tree diff equals the rebase delta. The export is correct when the applied commit series matches the source commit series it was diffed from.
