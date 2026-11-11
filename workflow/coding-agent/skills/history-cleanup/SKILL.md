---
name: history-cleanup
description: Rewrite a branch's history so each commit is one reviewable, bisectable commit whose record is true at that commit, and no content inside the range is written then replaced. Use when a draft branch carries an inversion, when a reviewer would read the same rule twice, or before packaging a branch for review.
disable-model-invocation: true
---

# history-cleanup

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `git-discipline`, `work-log`

## Mandate

Four invariants decide the result: every commit is reviewable; every commit is bisectable; every record is true at the commit that carries it; no content appears twice in the series with one occurrence cancelling the other. A rewrite that satisfies the shape and breaks bisectability is worse than the history it replaced.

The content is the invariant. The records are not. Only the records are rewritten, because they describe a shape that no longer exists. That asymmetry is why the proofs exclude record paths: hold the content fixed, and let the records move.

**The method is yours.** The invariants, the checks and the two review gates are fixed; how the series is produced is not. Fold, drop, reorder, split, or rebase the whole range, at whatever scope a unit needs. Report the operation each unit took, per `## Report`, because a departure nobody can see is the failure this skill exists to prevent.

## Input contract

| Input | Meaning |
|---|---|
| branch | The branch to rewrite, typically a draft export the operator is about to review. |
| base | The commit the range starts at, usually the last reviewed tip. |
| record path | Where the record a commit carries lives, or the convention that names it. |
| gate | The command that decides a commit is sound. It runs in each commit's own tree. |
| test | The suite that proves the tip stands. |
| additions | Optional. A path or artifact that did not exist in the old range and belongs in the new series, named by the operator with the commit it should ride. |

The argument slot may carry extra context: known inversions, a review comment that names a superseded commit, or an operator ruling on what may be dropped. Ask for whatever the message does not name.

## Establish that the rewrite is safe

Rewrite nothing until the refs are checked. A tag, a second branch, a note, or a signed commit inside the range is an invisible casualty of a rewrite and none of them appears in `git log`.

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

Validate the detector before believing it: run it against a two-commit fixture whose inversion you introduced yourself, built from prose-length lines, because a control made of short lines passes under the detector's eight-character floor and reads the same as a clean range.

For each hit, name both commits and the exact content replaced. Some hit classes are not design inversions and the caller must classify them rather than count them: a record a later commit corrects, and a generated file regenerated whole at each commit, whose rows change at every commit while no reader sees a difference.

Completion criterion: the positive control fires, every inversion is listed with both commits and the replaced content, or the range is reported clean with the control's output attached.

## Propose the target series, in two stages

Stage one is the manifest. One row per unit:

| unit | subject | source commits | files carried | record it rides | predicted change |
|---|---|---|---|---|---|

A row that carries no result of its own folds into the unit it serves; related small units combine. Present the manifest and wait. A boundary is cheap to change here and expensive after a build.

Stage two is the candidate. Build the series on a scratch ref and never move the reviewed branch. Present the per-unit `git log --stat` and the `range-diff` against the old range. Approval is of what the operator can see, and that approval is what moves the branch.

One commit per coherent deliverable. Collapse an inversion into the later commit, because the later content is the one a reviewer should read. Keep the record-to-commit pairing at one to one, because the record is the only place a reviewer learns why the commit exists.

An inversion collapses backwards when the earlier commit's record needs the content to be true at that commit, and the later commits only rewrote it. State which direction was chosen and why, per inversion.

When two records merge, the survivor keeps the earlier number, so a citation from outside the range still resolves. A record born into the new series states the correct facts at birth, which means no `[CORRECTION]` tag, because there is nothing earlier in the series to correct.

Do not split a change when the split would make the tree assert a rule twice and a later commit remove one copy. That trades one inversion for another, one level up.

Completion criterion: the manifest is approved, the candidate's per-unit statistics match it, and the proposal lists the collapse direction per inversion with the text dropped from the superseded records.

## Stop for release

Present the manifest, then the candidate. Neither is a rewrite until the operator releases, unless a grant already covers this rewrite; quote the grant rather than paraphrasing it.

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

## Reorganize the series

A unit stages the paths it owns. A record enters at the commit the manifest names, and nowhere else.

Run the gate as the commit's own tree holds it, because today's gate is not the gate of its day. A range whose tooling tightened mid-branch fails at commits that were clean when written, and a rule that says "stop" there leaves no route but to commit past it silently.

A commit that fails its own gate is not bisectable: the run stops and reports it. An ungated commit is a decision the operator takes before it is committed.

Rewrite the records in the same pass, one per unit and staged by path, because a record that disagrees with its commit is worse than none. Delete the superseded ones, and make each record's quoted counts true at its own commit.

Two attempts at a unit, then stop and report the residue.

Completion criterion: every commit passes the gate in its own tree, the records are one per unit, and the series matches the approved manifest.

## Run the audit

`scripts/audit.sh <base> [tip]`, beside this file, runs eight checks and exits non-zero on a finding:

| Check | Asserts |
|---|---|
| record added once | every record path is added by exactly one commit, with its final content |
| citation resolves | every roadmap row the range writes cites a record that exists at that commit |
| nothing born and buried | every path added in the range still exists at the tip |
| tip content identity | non-record blobs at the tip equal the reference tip's |
| commit gate | each commit passes the gate in its own tree |
| no silent empty unit | each commit changes a non-record path, or the manifest declares it record-only |
| manifest conformance | the resulting subjects and file sets match the approved manifest |
| inversions | delegates to `scripts/inversions.mjs`; no second implementation |

Run it on the candidate, before asking for release. A manifest file holds one row per unit: `sha<TAB>subject<TAB>comma-separated paths`. A check that has never failed is not a check, so run it once against a range built to violate each one.

## Prove the series, not only the endpoint

The audit's check 4 proves content identity and its check 8 reports the inversions. The series comparison is its own: `git range-diff <base>..<old> <base>..<new>` maps each old commit to its new one and shows a content section only where content moved between commits. A regroup moves content by construction; what must not appear is a non-record file whose content changed rather than moved.

Do not use the sorted patch-id multiset as the content proof. It is invariant under a reorder and false under a collapse, and this runbook requires collapses. A check that cannot hold on the required work is not a check.

Completion criterion: the audit is clean apart from named additions, and the range-diff shows no non-record content change. A difference in either fails the rewrite, including a difference that looks like an improvement.

## Prove each commit stands

Run the gate on every commit, in its own tree, as `## Reorganize the series` states.

Run the suite at the tip, once. A commit that changes only Markdown cannot break a shell test, and running the whole suite per commit spends minutes re-proving behaviour the commit did not touch; the tip is the tree a reviewer reads, and it is where the suite belongs.

Capture the suite's own exit status. `out=$(cmd | tail)` records the status of `tail`, so redirect to a file and read `$?`, or use `PIPESTATUS`. A loop that reports success for a suite that failed is worse than no loop.

A commit that fails once and passes on re-run at the same commit is a load-dependent failure, not a defect in the commit: re-run the failing file rather than the suite, which is the same evidence at a fraction of the cost, and record it. A failure that repeats is the commit's, and the series is not done.

Completion criterion: every commit passes the gate in its own tree, the tip is green on the full suite, and every quoted number is true at its commit.

## Report and retain

Report these, in this order:

- the old-to-new hash map, one row per commit;
- the operation each unit took: fold, drop, reorder, split, or whole-range rebase, and why that scope;
- the range-diff summary;
- the content comparison, with the record delta reported separately;
- what changed in the records;
- any addition named after the release;
- the audit's output.

Completion criterion: the report covers every commit and names every operation, and the backup ref is retained.

## Non-goals

- Not a port. `rebase.md` ports a stale branch; this rewrite preserves the final content and changes only how the series reads.
- Not a cleanup of content. If the final tree is wrong, that is a new commit or a new iteration, not a history rewrite.
