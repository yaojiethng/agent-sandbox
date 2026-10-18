---
description: Rewrite a branch's history so each commit is one reviewable, bisectable unit whose record is true at that commit, and no content inside the range is written then replaced. Use when a draft branch carries a change that a later commit undoes, when a reviewer would read the same rule twice, or before packaging a branch for review.
argument-hint: "[branch] [base commit] [record path or convention] [gate command] [test command]"
---

> $@

## Project conventions

This step reads and writes project records through the project's conventions. For each convention below, read `.agents/skills/<name>/SKILL.md` for this project's structure. If that file is absent, or holds the seeded stub, state the failure and hand control to the agent, which decides with the steering it has loaded; the workflow prescribes no fallback.

- `git-discipline` - commit types, branch names and the delivery commit.
- `work-log` - the handover a commit carries, and its shape.

## Mandate

You are rewriting the history of one branch. The operator names the branch, its base, and the gate that decides whether a commit is sound. The deliverable is a series in which each commit is one reviewable unit, builds and passes on its own, carries a record true at that commit, and contains no content that a later commit in the range replaces.

A clean shape is not the goal. Four invariants are: every commit is a reviewable unit; every commit is bisectable; every record is true at the commit that carries it; no content appears twice in the series with one occurrence cancelling the other. A rewrite that satisfies the shape and breaks bisectability is worse than the history it replaced.

The working tree is the invariant. The records are not. You rewrite only the records, because they describe a shape that no longer exists.

## Input contract

| Input | Meaning |
|---|---|
| branch | The branch to rewrite, typically a draft export the operator is about to review. |
| base | The commit the range starts at, usually the last reviewed tip. |
| record path | Where the record a commit carries lives, or the convention that names it. |
| gate | The command that decides a commit is sound, cited once and run per commit. |
| test | The suite that proves a commit stands, cited once and run per commit. |

The argument slot may carry extra context: known inversions, a review comment that names a superseded commit, or an operator ruling on what may be dropped. Use them; ask for what is missing.

## Establish that the rewrite is safe

Nothing is rewritten until the refs are checked. A tag, a second branch, a note, or a signed commit inside the range is an invisible casualty of a rewrite and none of them appears in `git log`.

Record four results. `git status -sb` shows no upstream, because a pushed range is not yours to rewrite. `git for-each-ref --contains <base>` names no tag or branch inside the range. `git log --show-signature` emits no signature that the rewrite would invalidate, or the operator accepts the loss. `git notes list` is empty inside the range, or the notes are copied.

Create the backup ref `pre-squash-<date>` at the tip. Keep it until the operator releases the package.

Completion criterion: each of the four checks has a stated result, the backup resolves, and a tag, a branch, a note or a signed commit inside the range has stopped the run for operator release.

## Build the patch series as data

Read the range as objects, not as subjects. Per commit, collect `git diff-tree -r --no-commit-id`, `git patch-id --stable`, `git rev-parse <commit>^{tree}`, and the record the commit carries.

Table the result: hash, subject, type, files, patch id, tree, record.

Completion criterion: every commit between base and tip has a row, the union of the file column equals the range's changed-file set, and the patch-id multiset for the range is recorded.

## Detect the inversions mechanically

An inversion is content the range writes and later replaces. Do not infer it from commit subjects, which describe intent and hide the reversal. Find four kinds.

A file added in one commit and deleted in a later one. A line set written in one commit and rewritten in a later one, found with `git log -G` on the changed text. A hunk whose removal appears in a later patch, found by matching removed lines against earlier added lines. A patch id that appears twice, which is a change made twice.

For each, name both commits and the exact content replaced.

Completion criterion: every inversion is listed with both commits and the replaced content, or the range is reported clean and the task stops there.

## Propose the target series

One commit per coherent deliverable. Collapse an inversion into the later commit, because the later content is the one a reviewer should read. Keep the record-to-commit pairing at one to one, because the record is the only place a reviewer learns why the unit exists.

Do not split a change when the split would make the tree assert a rule twice and a later commit remove one copy. That trades one inversion for another, one level up.

Completion criterion: the proposal lists each target commit with its files, its record, its type, and the text dropped from the superseded records.

## Stop for release

Unless an operator grant already covers this rewrite, present the proposal, the inversion list, the rollback ref, and the hashes that will stop resolving, then wait.

Completion criterion: the operator releases, or the grant is quoted.

## Rebuild with the gate on every commit

`git reset --soft <base>`, then `git restore --staged .`. Stage by path and commit in order, each with the type its patch earns.

Run the gate as each commit is produced, with `--exec` on a rebase or as a worktree run after each commit. A commit that has never been built is not a unit.

Rewrite the records in the same pass: delete the superseded ones, write one per target commit, and make each record's quoted counts true at its own commit.

Completion criterion: `git log --oneline <base>..HEAD` matches the proposal exactly, and every commit was gated when it was produced.

## Prove the series, not only the endpoint

Three checks, in this order.

- Tree identity: `git rev-parse <old-tip>^{tree}` equals `git rev-parse HEAD^{tree}`.
- Content identity: the sorted patch-id multiset is unchanged, which forbids a change being split across commits and recombined.
- Series identity: `git range-diff <base>..<old> <base>..<new>` shows the record edits and no content drift.

Completion criterion: all three hold. A difference in any of them fails the rewrite, including a difference that looks like an improvement.

## Prove each commit stands

Run the suite over the new series with `git bisect run`, or the equivalent per-commit loop in a worktree. Re-derive every count a record quotes and compare it against that commit, not against the tip.

Completion criterion: every commit is green and every quoted number is true at its commit.

## Report and retain

The old-to-new hash map, the range-diff summary, the patch-id comparison, and what changed in the records.

Completion criterion: the report covers every commit and the backup ref is retained.

## Non-goals

- Not a port. Porting replays intent onto another branch; this rewrite preserves the final content and changes only how the series reads. The git policy names the porting operation in its reference table.
- Not a squash of the whole range. Collapsing every commit into one destroys the record-to-commit pairing the reviewer needs.
- Not a cleanup of content. If the final tree is wrong, that is a new commit or a new iteration, not a history rewrite.

## Failure modes

| Failure | Response |
|---|---|
| The branch has an upstream, or the range is pushed | Stop. A rewrite of shared history is not this prompt's business. |
| A tag or branch points inside the range | Stop for operator release; the rewrite would move or orphan it. |
| The range is already clean | Report it and stop. An empty rewrite still changes every hash. |
| The gate cannot run at an intermediate commit | Stop. A series whose middle commit does not build is linear and useless. |
| `range-diff` shows content drift | Undo with the backup ref and redo the staging. The tree may still be right while the series is wrong. |
| The record contradicts the commit it carries | Fix the record in the same rebuild; a record that disagrees with its commit is worse than none. |
| The backup ref is deleted before review | The rewrite is now unrecoverable in practice. Retain it until the operator releases. |
