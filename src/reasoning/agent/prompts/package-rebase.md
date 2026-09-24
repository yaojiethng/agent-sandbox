---
description: Export rebase-modified branch history to the host worktree via an explicit branch point. Use when history was rewritten with git rebase and the normal export path (init_sha) can no longer produce an appliable bundle.
trigger: /package-rebase
---
> $@

Export the commits that differ from an explicit baseline, so the operator can apply them onto the host branch after a rebase. Run this prompt when the iteration rewrote history (interactive rebase, fold, or amend) and the export-by-`init_sha` path no longer applies cleanly.

## Why an explicit baseline

The normal bundle is diffed from `init_sha` -- the branch point recorded in `SESSION_STATE` at session start. A rebase rewrites the commits after that point, so diffs against the recorded baseline no longer match the host checkout, or the branch topology changed and the recorded point is stale. The explicit baseline fixes the comparison: diff from the commit the rebased branch diverges from (for example the new base `M3_1` HEAD), so the exported diffs apply cleanly onto that same commit on the host.

## Procedure

1. Identify the baseline SHA the rebased branch now diverges from -- the newest commit both the export source and the host target share. Name it `BRANCH_POINT`.
2. Run the packaging script with that baseline:

```bash
bash /opt/sandbox/lib/package_branch.sh --to=$HOME/workspace/output --baseline=$BRANCH_POINT --bundle-summary=<summary>
```

3. Report the bundle path and the `make draft` invocation to the operator. The generated command hint must carry the branch point; if the hint omits it, pass it explicitly as `--branch-from=$BRANCH_POINT` (or `agent-sandbox draft --branch-from=$BRANCH_POINT`, or `make draft ... --branch-from=$BRANCH_POINT`).
4. The operator applies the bundle onto the host branch using that branch point, so the exported commits land on top of the same base they were diffed from.

## Command hints always carry a branch point

`package-branch` and `make draft` command hints specify a branch point by default, so a rebase-based workflow does not fall back on a stale `init_sha` silently. When the hint would omit the baseline, add `--baseline=<sha>` (package-branch) or `--branch-from=<commit>` (draft). The operator then applies with the recorded point rather than guessing.

## Relationship to make draft

`make draft` recreates commits from the `.msg` files paired with each diff, applying them onto a draft branch. With a rebase, the diffs are derived from `--baseline=BRANCH_POINT`, and the draft branch is created from `--branch-from=BRANCH_POINT`. The two must name the same commit, or the patches resolve against the wrong parent.

## Verification

State that the operator applies the bundle onto the host branch at the branch point and confirms the resulting tree diff equals the rebase delta. The export is correct when the applied commit series matches the source commit series it was diffed from.
