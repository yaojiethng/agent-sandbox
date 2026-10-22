---
name: history-cleanup
description: Rewrite a branch's history so each commit is one reviewable, bisectable unit whose record is true at that commit, and no content inside the range is written then replaced. Use when a draft branch carries an inversion, a change a later commit undoes, when a reviewer would read the same rule twice, or before packaging a branch for review.
disable-model-invocation: true
---

# history-cleanup

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `git-discipline`, `work-log`

## Mandate

The deliverable is a series in which each commit is one reviewable unit, builds and passes on its own, carries a record true at that commit, and contains no content that a later commit in the range replaces.

Four invariants decide the result: every commit is a reviewable unit; every commit is bisectable; every record is true at the commit that carries it; no content appears twice in the series with one occurrence cancelling the other. A rewrite that satisfies the shape and breaks bisectability is worse than the history it replaced.

The content is the invariant. The records are not. You rewrite only the records, because they describe a shape that no longer exists. This asymmetry is why the proofs below exclude record paths: hold the content fixed, and let the records move.

## Input contract

| Input | Meaning |
|---|---|
| branch | The branch to rewrite, typically a draft export the operator is about to review. |
| base | The commit the range starts at, usually the last reviewed tip. |
| record path | Where the record a commit carries lives, or the convention that names it. |
| gate | The command that decides a commit is sound, cited once and run per commit. |
| test | The suite that proves a commit stands, cited once and run per commit. |
| additions | Optional. A path or artifact that did not exist in the old range and belongs in the new series, named by the operator with the commit it should ride. |

The argument slot may carry extra context: known inversions, a review comment that names a superseded commit, or an operator ruling on what may be dropped. Ask for whatever the message does not name.

## Establish that the rewrite is safe

You rewrite nothing until you check the refs. A tag, a second branch, a note, or a signed commit inside the range is an invisible casualty of a rewrite and none of them appears in `git log`.

Record four results. `git status -sb` shows no upstream, because a pushed range is not yours to rewrite. `git for-each-ref --contains <base>` names no tag or branch inside the range. `git log --show-signature` emits no signature that the rewrite would invalidate, or the operator accepts the loss. `git notes list` is empty inside the range, or the notes are copied.

Create the backup ref `pre-squash-<date>` at the tip. Keep it until the operator releases the package; a backup deleted before review leaves the rewrite unrecoverable in practice.

Completion criterion: each of the four checks has a stated result, the backup resolves, and a tag, a branch, a note or a signed commit inside the range has stopped the run for operator release.

## Build the patch series as data

Read the range as objects, not as subjects. Per commit, collect `git diff-tree -r --no-commit-id`, `git patch-id --stable`, `git rev-parse <commit>^{tree}`, and the record the commit carries.

Table the result:

| hash | subject | type | files | patch id | tree | record |
|---|---|---|---|---|---|---|

Completion criterion: every commit between base and tip has a row, the union of the file column equals the range's changed-file set, and the patch-id multiset for the range is recorded.

## Detect the inversions mechanically

An inversion is content the range writes and later replaces. Do not infer it from commit subjects, which describe intent and hide the reversal. A range excludes its base, so a write that sits at the base commit is outside it, and so is a removal after the tip. Find these kinds.

A file added in one commit and deleted in a later one. A line set written in one commit and rewritten in a later one, found with `git log -G` on the changed text. A hunk whose removal appears in a later patch, found by matching removed lines against earlier added lines. A patch id that appears twice, which is a change made twice.

The detector at `scripts/inversions.mjs`, beside this file, reads added and removed lines per commit per file and reports every ordered pair where a later commit removes a line an earlier one added. It needs `node` and a git working tree, and takes the range as `<base> [tip]`.

Validate the detector before believing it. Run it against a two-commit fixture whose inversion you introduced yourself, and confirm it names both commits and the line. A detector that reports a clean range and a detector that cannot match a line produce the same output, and the difference is only visible against a case whose answer is already known.

Strip the diff marker before comparing. Keeping the leading `+` or `-` makes every added line differ from every removed one by that character, so the report is a confident and wrong "none".

A length floor is the same trap in another form. The detector skips content lines shorter than eight characters, so a control built from short lines reports a clean range against a real inversion. Build the control from prose-length lines, and state the floor in the detector's own header beside the marker note.

For each hit, name both commits and the exact content replaced. Some hit classes are not design inversions and the caller must classify them rather than count them: a record a later commit corrects, and a generated file regenerated whole at each commit, whose rows change at every commit while no reader sees a difference.

Completion criterion: the positive control fires, every inversion is listed with both commits and the replaced content, or the range is reported clean with the control's output attached.

## Propose the target series

One commit per coherent deliverable. Collapse an inversion into the later commit, because the later content is the one a reviewer should read. Keep the record-to-commit pairing at one to one, because the record is the only place a reviewer learns why the unit exists.

An inversion collapses backwards when the earlier commit's record needs the content to be true at that commit, and the later commits only rewrote it. Say which direction you chose and why, per inversion.

Merging records follows from the pairing. When two records merge, the survivor keeps the earlier number, so a citation from outside the range still resolves. A record born into the new series states the correct facts at birth, which means no `[CORRECTION]` tag, because there is nothing earlier in the series to correct.

Do not split a change when the split would make the tree assert a rule twice and a later commit remove one copy. That trades one inversion for another, one level up.

Completion criterion: the proposal lists each target commit with its files, its record, its type, the collapse direction per inversion, and the text dropped from the superseded records.

## Stop for release

Unless an operator grant already covers this rewrite, present the proposal, the inversion list, the rollback ref, and the hashes that will stop resolving, then wait.

The release covers the proposal as presented. Content that enters the series afterwards, including an artifact the operator asks for mid-run, needs a second release naming the commit it rides, or stays out of the series and lands as its own commit.

Completion criterion: the operator releases, or the grant is quoted, and any addition after the release is named with its commit.

## Check every path the range writes twice

Before the reset, list every path the range writes more than once, and compare each pair of consecutive versions. A wholesale `git checkout <commit> -- <path>` replaces the file, so a fix applied at an earlier commit is reverted at the later one unless the later version carries it. That revert does not show in the file-set table, and repairing it costs a second rebuild, because by then the range writes a line and later unwrites it.

```bash
git diff --name-only <base> <tip> | while read -r p; do
  [ "$(git log --oneline <base>..<tip> -- "$p" | wc -l)" -gt 1 ] && echo "$p"
done
```

For each hit, diff consecutive versions of that path and confirm nothing the earlier one carried has disappeared. Apply a fix at every commit that writes the file, or at none of them, because a fix at the first write only is what the second write reverts.

Completion criterion: every path the range writes more than once has been diffed against its consecutive versions, and each pair differs by nothing the earlier version carried.

## Rebuild with the gate on every commit

`git reset --soft <base>`, then `git restore --staged .`, then `git checkout <base> -- .` and `git clean -fd` so the working tree holds the base and nothing left over from the old range. Stage by path. `git add -A` stages an untracked file from the old range silently, and it lands in the first commit. Verify each commit with `git show --stat` before moving on.

Commit in order, each with the type its patch earns.

Run the gate as you produce each commit, with `--exec` on a rebase or as a worktree run after each commit. A commit that has never been built is not a unit. Where the gate cannot run at an intermediate commit, stop: a series whose middle commit cannot be built cannot be bisected. The suite's grain is `## Prove each commit stands`.

Rewrite the records in the same pass: delete the superseded ones, write one per target commit, and make each record's quoted counts true at its own commit. A record that disagrees with its commit is worse than none, so fix it in the same rebuild rather than after it.

Completion criterion: `git log --oneline <base>..HEAD` matches the proposal exactly, and every commit was gated when it was produced.

## Prove the series, not only the endpoint

Three checks run in this order, and the first two exclude the record paths, because the records are what the rewrite is allowed to change.

1. **Content identity.** Every non-record blob at the new tip equals the blob at the old tip: `git ls-tree -r <old-tip>` against `git ls-tree -r HEAD`, with the record paths filtered out, differing by nothing except a named addition. Report the record delta separately, as files added and removed.
2. **Net content identity.** `git diff <base> <tip> | git patch-id --stable` is unstable here, because the range now carries the record edits and any addition. Use the blob comparison above as the content check and report the net patch-id only as context, never as a pass condition.
3. **Series identity.** `git range-diff <base>..<old> <base>..<new>` maps each old commit to its new one and shows a content section only where content moved between commits. A regroup moves content by construction; what must not appear is a non-record file whose content changed rather than moved.

Do not use the sorted patch-id multiset as the content proof. It is invariant under a reorder and false under a collapse, and this runbook requires collapses. A check that cannot hold on the required work is not a check.

Completion criterion: the blob comparison is empty apart from named additions, and the range-diff shows no non-record content change. A difference in either fails the rewrite, including a difference that looks like an improvement.

## Prove each commit stands

Run the tests the commit's files can break, with `git bisect run` or the equivalent per-commit loop in a worktree. A commit that changes only Markdown cannot break a shell test, and running the whole suite per commit spends minutes re-proving behaviour the commit did not touch. The test command named in the input contract takes a file or directory selector, so the commit's own files choose the run. Measure the gate and the suite once at the start and state both costs, rather than discovering the second one mid-run.

The gate is the cheap one, seconds per commit, and it is not optional. Re-derive every count a record quotes and compare it against that commit, not against the tip.

Capture the suite's own exit status. `out=$(cmd | tail)` records the status of `tail`, so redirect to a file and read `$?`, or use `PIPESTATUS`. A loop that reports success for a suite that failed is worse than no loop.

A commit that fails once and passes on re-run at the same commit is a load-dependent failure, not a defect in the commit: re-run the failing file rather than the suite, which is the same evidence at a fraction of the cost, and record it. A failure that repeats is the commit's, and the series is not done.

Run the full suite at the tip, once, whether or not the per-commit runs were targeted. The tip is the tree a reviewer reads, and a targeted run per commit does not cover behaviour that more than one commit contributes to.

Completion criterion: every commit is green on the tests its files can break, the tip is green on the full suite, every quoted number is true at its commit, and any single-run failure is recorded with its re-run.

## Report and retain

Report these, in this order:

- the old-to-new hash map, one row per commit;
- the range-diff summary;
- the content comparison, with the record delta reported separately;
- what changed in the records;
- any addition named after the release.

Completion criterion: the report covers every commit and the backup ref is retained.

## Non-goals

- Not a port. `rebase.md` ports a stale branch; this rewrite preserves the final content and changes only how the series reads.
- Not a cleanup of content. If the final tree is wrong, that is a new commit or a new iteration, not a history rewrite.
