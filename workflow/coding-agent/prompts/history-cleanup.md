---
description: Rewrite a branch's history so each commit is one reviewable, bisectable unit whose record is true at that commit, and no content inside the range is written then replaced. Use when a draft branch carries a change that a later commit undoes, when a reviewer would read the same rule twice, or before packaging a branch for review.
argument-hint: "[branch] [base commit] [record path or convention] [gate command] [test command]"
---

> $@

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `git-discipline`, `work-log`

## Mandate

You are rewriting the history of one branch. The operator names the branch, its base, and the gate that decides whether a commit is sound. The deliverable is a series in which each commit is one reviewable unit, builds and passes on its own, carries a record true at that commit, and contains no content that a later commit in the range replaces.

A clean shape is not the goal. Four invariants are: every commit is a reviewable unit; every commit is bisectable; every record is true at the commit that carries it; no content appears twice in the series with one occurrence cancelling the other. A rewrite that satisfies the shape and breaks bisectability is worse than the history it replaced.

The working tree is the invariant. The records are not. You rewrite only the records, because they describe a shape that no longer exists. This asymmetry is why the proofs below exclude record paths: hold the content fixed, and let the records move.

## Input contract

| Input | Meaning |
|---|---|
| branch | The branch to rewrite, typically a draft export the operator is about to review. |
| base | The commit the range starts at, usually the last reviewed tip. |
| record path | Where the record a commit carries lives, or the convention that names it. |
| gate | The command that decides a commit is sound, cited once and run per commit. |
| test | The suite that proves a commit stands, cited once and run per commit. |
| additions | Optional. A path or artifact that did not exist in the old range and belongs in the new series, named by the operator with the commit it should ride. |

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

A working implementation is `.agents/drafts/history-cleanup/inversions.mjs`, which reads added and removed lines per commit per file and reports every ordered pair where a later commit removes a line an earlier one added. It is a draft until the skill pipeline lands and can carry it.

Validate the detector before believing it. Run it against a two-commit fixture whose inversion you introduced yourself, and confirm it names both commits and the line. A detector that reports a clean range and a detector that cannot match a line produce the same output, and the difference is only visible against a case whose answer is already known.

Strip the diff marker before comparing. Keeping the leading `+` or `-` makes every added line differ from every removed one by that character, so the report is a confident and wrong "none". That defect has been live in this repository once.

A length floor is the same trap in another form. The draft detector skips content lines shorter than eight characters, so a control built from short lines reports a clean range against a real inversion. Build the control from prose-length lines, and state the floor in the detector's own header beside the marker note.

For each hit, name both commits and the exact content replaced. Two hit classes are not design inversions and the caller must classify them rather than count them: a record a later commit corrects, and a generated file regenerated whole at each commit, whose hashed rows churn without any reader seeing them.

Completion criterion: the positive control fires, every inversion is listed with both commits and the replaced content, or the range is reported clean with the control's output attached.

## Propose the target series

One commit per coherent deliverable. Collapse an inversion into the later commit, because the later content is the one a reviewer should read. Keep the record-to-commit pairing at one to one, because the record is the only place a reviewer learns why the unit exists.

An inversion collapses backwards when the earlier commit's record needs the content to be true at that commit, and the later commits only churned it. Say which direction you chose and why, per inversion.

Merging records follows from the pairing. When two records merge, the survivor keeps the earlier number, so a citation from outside the range still resolves. A record born into the new series states the correct facts at birth, which means no `[CORRECTION]` tag, because there is nothing earlier in the series to correct.

Do not split a change when the split would make the tree assert a rule twice and a later commit remove one copy. That trades one inversion for another, one level up.

Completion criterion: the proposal lists each target commit with its files, its record, its type, the collapse direction per inversion, and the text dropped from the superseded records.

## Stop for release

Unless an operator grant already covers this rewrite, present the proposal, the inversion list, the rollback ref, and the hashes that will stop resolving, then wait.

The release covers the proposal as presented. Content that enters the series afterwards, including an artifact the operator asks for mid-run, needs a second release naming the commit it rides, or stays out of the series and lands as its own commit.

Completion criterion: the operator releases, or the grant is quoted, and any addition after the release is named with its commit.

## Rebuild with the gate on every commit

Before the reset, list every path the range writes more than once, and compare each pair of consecutive versions. A wholesale `git checkout <commit> -- <path>` replaces the file, so a fix applied at an earlier commit is reverted at the later one unless the later version carries it. That revert does not show in the file-set table, and repairing it costs a second rebuild, because by then the range writes a line and later unwrites it.

```bash
git diff --name-only <base> <tip> | while read -r p; do
  [ "$(git log --oneline <base>..<tip> -- "$p" | wc -l)" -gt 1 ] && echo "$p"
done
```

For each hit, diff consecutive versions of that path and confirm nothing the earlier one carried has disappeared. Apply a fix at every commit that writes the file, or at none of them, because a fix at the first write only is what the second write reverts.

`git reset --soft <base>`, then `git restore --staged .`, then `git checkout <base> -- .` and `git clean -fd` so the working tree holds the base and nothing left over from the old range. Stage by path, never with `git add -A`, because an untracked file from the old range is staged silently by the wildcard and lands in the first commit. Verify each commit with `git show --stat` before moving on.

Stage by path and commit in order, each with the type its patch earns.

Run the gate as each commit is produced, with `--exec` on a rebase or as a worktree run after each commit. A commit that has never been built is not a unit.

Rewrite the records in the same pass: delete the superseded ones, write one per target commit, and make each record's quoted counts true at its own commit.

Two costs, and the caller decides the grain. The gate is cheap, seconds per commit, and is not optional. The suite is the expensive one, so run the tests a commit's files can break rather than the whole suite. `scripts/run_tests.sh` takes a file or directory selector, so a Markdown-only commit runs the doc and record gates and nothing else, and a commit that changes shell or JavaScript runs the files that cover its subject. Run the full suite once, at the tip, because the tip is what a reviewer reads. Measure both costs once at the start and state them, rather than discovering the second one mid-run.

Completion criterion: `git log --oneline <base>..HEAD` matches the proposal exactly, and every commit was gated when it was produced.

## Prove the series, not only the endpoint

Three checks, in this order. The first two exclude the record paths, because the records are what the rewrite is allowed to change.

- **Content identity.** Every non-record blob at the new tip equals the blob at the old tip: `git ls-tree -r <old-tip>` against `git ls-tree -r HEAD`, with the record paths filtered out, differing by nothing except a named addition. Report the record delta separately, as files added and removed.
- **Net content identity.** `git diff <base> <tip> | git patch-id --stable` is unstable here, because the range now carries the record edits and any addition. Use the blob comparison above as the content check and report the net patch-id only as context, never as a pass condition.
- **Series identity.** `git range-diff <base>..<old> <base>..<new>` maps each old commit to its new one and shows a content section only where content moved between commits. A regroup moves content by construction; what must not appear is a non-record file whose content changed rather than moved.

Do not use the sorted patch-id multiset as the content proof. It is invariant under a reorder and false under a collapse, and this prompt requires collapses. A check that cannot hold on the required work is not a check.

Completion criterion: the blob comparison is empty apart from named additions, and the range-diff shows no non-record content change. A difference in either fails the rewrite, including a difference that looks like an improvement.

## Prove each commit stands

Run the tests the commit's files can break, with `git bisect run` or the equivalent per-commit loop in a worktree. A commit that changes only Markdown cannot break a shell test, and running the whole suite per commit spends minutes re-proving behaviour the commit did not touch. Re-derive every count a record quotes and compare it against that commit, not against the tip.

Capture the suite's own exit status. `out=$(cmd | tail)` records the status of `tail`, so redirect to a file and read `$?`, or use `PIPESTATUS`. A loop that reports success for a suite that failed is worse than no loop.

A commit that fails once and passes on re-run at the same commit is a load-dependent failure, not a defect in the commit: re-run the failing file rather than the suite, which is the same evidence at a fraction of the cost, and record it. A failure that repeats is the commit's, and the series is not done.

Run the full suite at the tip, once, whether or not the per-commit runs were targeted. The tip is the tree a reviewer reads, and a targeted run per commit does not cover behaviour that more than one commit contributes to.

Completion criterion: every commit is green on the tests its files can break, the tip is green on the full suite, every quoted number is true at its commit, and any single-run failure is recorded with its re-run.

## Report and retain

The old-to-new hash map, the range-diff summary, the content comparison, what changed in the records, and any addition named after the release.

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
| The range is already clean | Report it and stop, but only after the positive control fires. An unvalidated clean result is not a finding. |
| The detector cannot match a line | Suspect the comparison before the range. Strip the diff marker and re-run the control. |
| The gate cannot run at an intermediate commit | Stop. A series whose middle commit does not build is linear and useless. |
| `range-diff` shows a non-record content change | Undo with the backup ref and redo the staging. The tree may still be right while the series is wrong. |
| A record contradicts the commit it carries | Fix the record in the same rebuild; a record that disagrees with its commit is worse than none. |
| The suite fails once and passes on re-run at the same commit | Record it as load-dependent, with the failing file's re-run as evidence. Do not fix it into the commit. |
| A path is written by more than one commit and the later version reverts an earlier fix | Apply the fix at every write of that path, or at none. A fix at the first write only is what the later write reverts. |
| The suite fails on re-run | The commit is not a unit. Undo with the backup ref. |
| Content enters the series after release | Stop for a second release naming its commit, or land it outside the series. |
| The backup ref is deleted before review | The rewrite is now unrecoverable in practice. Retain it until the operator releases. |
