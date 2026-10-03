---
description: Merge arbitrary draft branches into a target branch by replaying each draft's content commits one-for-one in export order. The target history stays linear and reads as original work; no merge commits, no squash, no draft metadata.
argument-hint: "[draft branches...] [target branch]"
---

> $@

## Mandate

You are merging draft branches into a target branch. The operator named the drafts and the target. Your deliverable is every draft's content landed on the target one-for-one, with the inter-draft conflicts resolved once, and the target history linear.

Merging replays current draft exports one-for-one. It is not a port: the drafts are finished sessions whose content lands as-is. When a branch's work must be re-realized against a changed target, use `/rebase` instead.

Four rules govern this run.

First, replay commits, never merge. A draft's content commits are cherry-picked one-for-one in their original order, each keeping its message, its author, and its handover. No merge commit is produced, and no squash folds the drafts together. The target history must read as if the work was done there.

Second, merge the drafts synchronously. All named drafts land in one pass, in export order, oldest first. Every later draft resolves its overlaps against everything the earlier drafts already landed. A draft is not merged against the target alone; it is merged against the accumulated tree.

Third, exclude the metadata. A draft branch's first commit is `.draft-state`, a record of the export: source branch, hashes, timestamps. It is never replayed, and the file never appears in the result. On the new base it would record false state. `.rej` files and stray untracked files are excluded the same way, and flagged to the operator.

Fourth, stop on real divergence. Textual conflicts, additive merges, and stale counts are your work to resolve. A design contradiction between a draft and the target, or between two drafts, is the operator's; ask before guessing.

## Input contract

| Input | Meaning |
|---|---|
| draft branch | A `draft/`-prefixed export of a session's commits, typically `draft/YYYYMMDD-HHMMSS-<host>-<hash>`. |
| target branch | Where the drafts land: the current working line, usually a `feat/` or `milestone/` branch. |
| export order | The order the drafts were exported, from each draft's `.draft-state` `session_ts`. |

The argument slot may carry extra context: operator rulings, supersession concerns between drafts, or records to reconcile. Use them; ask for what is missing.

## Establish topology

Map the branch graph before reading any commit.

- Each draft's export base: `from_hash` in its `.draft-state`. A draft whose base is the current target tip replays cleanly in isolation; a draft whose base is older lands against everything the target gained since.
- The target's commits since the oldest base: `git log --oneline <oldest-base>..<target>`.
- Each draft's content commits: `git log --oneline <from_hash>..<draft>` -- then drop the `.draft-state` commit. Classify each remaining commit: its type, its files, and the handover it carries.
- Draft-to-draft overlap: which files two drafts both changed since their common base. The roadmap, the feedback record, and the read-through register are the usual shared files, and their edits are usually disjoint regions.
- Draft-to-target overlap: which draft-touched files the target also changed since the draft's base.

## Sort the replay

Order the drafts by `session-ts`, oldest first. Within a draft, keep the commit order. The replay is one cherry-pick at a time; there is no batch mode, because every conflict must be resolved against the tree as it stands.

Before touching any file, pin the target's base: the replay starts at the target's current tip. Replay the earliest draft first, then each later draft in turn. A draft whose own base is old contributes its commits onto whatever the earlier drafts have already established; expect its conflicts to come from both sides.

## Exclude pipeline artifacts

A draft export carries metadata that is not content.

- The `.draft-state` commit is skipped. It records the export -- source branch, `from_hash`, timestamps -- and on the merged branch it would assert a state that never existed there.
- The `.draft-state` file is absent from the result. Verify with `git cat-file -e HEAD:.draft-state`, which must fail.
- `.rej` files are rejected patch remnants. On a current export they mean the iteration's change did not land; flag them, do not carry them.
- Stray untracked files in the working tree describe sessions outside the branch. Flag them to the operator; do not carry them.

Name every exclusion in your report. The operator expects the result to be free of draft metadata.

## Resolve conflicts

Each conflict gets one verdict, decided against the accumulated tree.

- Present: an earlier draft in this pass already landed the change, possibly under a different hash. Drop it and say so. Per-file identity is `git diff --quiet <draft> <target> -- <file>`.
- Merged: two drafts changed the same document in disjoint regions, one bullet here and one row there. Keep both sides. This is the common case for the roadmap, the feedback record, and the read-through register.
- Superseded: an earlier draft's refactor renamed or restructured the surface a later draft still used. Keep the refactored version. Adapt the later draft's use to the new name, or drop the stale use when the new shape made it obsolete. A test that pins a function the refactor renamed is the usual case: the refactor's own unit replaces it.
- Live: the change is absent and uncontradicted. Replay it as-is.
- Divergent: two designs contradict each other within or across drafts. Stop and ask; this verdict never resolves itself.

Fold current-state corrections into the commit that owns the subject: counts, suite totals, status lines. Never create a commit that only repairs an earlier replay; amend or fixup into the owning commit, following the repo's transient-commit rules.

## Verify

- The replay count: `git log --oneline <target-base>..HEAD` shows exactly the sum of the drafts' content commits, and no others.
- The branch carries no merge commit and no scaffolding commit.
- `.draft-state` is absent from the result.
- No conflict markers remain anywhere in the tree.
- The suite is green under the repo runner: `bash scripts/run_tests.sh`. The test-liveness gate and the lint gate pass too: `bash scripts/lint.sh`.
- `git status` is clean apart from operator-owned strays you flagged.
- The tree diff against each draft shows only intended content: excluded artifacts, target-side content, and applied corrections.

## Close

Report the topology, the replay order, the per-draft commit counts, the conflict verdict per file, and the verification numbers. Name every exclusion and every drop. End with the one question that matters: whether every draft's intent is fully landed on the target.
