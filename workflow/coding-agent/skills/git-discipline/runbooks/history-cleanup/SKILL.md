---
name: history-cleanup
description: Rewrite a feature branch's series into a reviewable, bisectable sequence with no forward dependencies. Use when a branch is about to be reviewed as a PR or merge request and its commits carry corrections, tangles, reversals, record noise or checkpoints.
disable-model-invocation: true
---

# history-cleanup

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, skip the arm that reads it and report the skipped arm. Raise only a convention the procedure cannot run without.

- `work-log`, `task-list`

`work-log` owns property 5, the record rewrite, the handover record root, `devlog/AGENT_FEEDBACK.md` and `devlog/discussions`; `task-list` owns the roadmap and changelog paths in the audit. Without either, the content properties still run.

## When it runs

A branch accumulates corrections, tangles and reversals while it is written, so it arrives for review with commits that a later commit completes, records that describe a shape that no longer exists, and checkpoints the author meant to fold. The rewrite finds those violations and returns the history to a state worth keeping.

A commit is judged alone when it is written. The series is judged here, because a commit cannot know its successors and only the full range shows the order.

## The contract

| Item | Meaning |
|---|---|
| Input | A commit range, `<base>..<tip>`. |
| Output | A range whose series holds the properties below. |
| Unchanged | The content and the base. The cleanup rewrites the sequence, not what the branch lands. The change pipeline records the branch point and drafts from it. |
| Consumer | The reviewer of the PR or merge request, at feature-branch granularity. The host's one-commit delivery is the pipeline's squash, a different consumer. |

The content is the invariant; the records are not. The audit holds the content fixed and lets the records move.

## The properties

A desirable series:

1. **Complete at every point** -- no commit is completed, corrected or reverted by a later commit in the range.
2. **One unit per commit** -- a commit holds one coherent change; no unit split across commits, no commit spanning units.
3. **A reviewable order** -- the series reads in order; each commit can be read against the one before; a reviewer can stop at any commit.
4. **A bisectable path** -- each commit builds and passes the gate; no commit needs a later one to build.
5. **Records true at their commit** -- no record is born and retired inside the range; each record describes the commit that carries it.
6. **Origin survives the rewrite** -- a correction folds into the unit it corrects, not an introduction; `git blame` still names the commit that introduced the line.

Property 5 is the only record property. When the project has no `work-log`, mark it not applicable, skip the record rewrite and the audit's check 1, and name the skip in the report; properties 1-4 and 6 stand. When the project has no `task-list`, pass only the `work-log` record paths to the audit's check 4; when it has no `work-log`, pass only the `task-list` paths; when it has neither, pass `--record-paths=` and name that skip.

The per-commit properties -- atomic, bisectable, self-explanatory, blameable -- are [`git-discipline`'s](../../SKILL.md); this skill cites them and does not restate them. A stack's contiguity is [`branching.md`](../../references/branching.md)'s.

An inversion is the mechanical form of the first property: content the range writes and a later commit replaces -- a file added then deleted, a line set added and later rewritten, a patch id applied twice. The audit's inversion detector finds it; the property is what forbids it. A generated file regenerated whole is classified, not counted. Record paths are excluded from the content proof, so a record delta is a record move, not an inversion.

## Before you rewrite

Rewrite only a range you own. `git status -sb` shows no upstream; `git for-each-ref --contains <base>` names no tag or branch inside the range; `git notes list` is empty there; a signed commit the rewrite would invalidate has the operator's acceptance.

Create the backup ref `pre-squash-<date>` at the tip and keep it until the operator releases the package.

## The method

The properties are the contract; the method is yours. Rewrite in place -- an interactive rebase, `--fixup` and `--autosquash` -- or build the target series on a scratch ref and move the branch after approval. Choose by the unit's complexity and the series' shape; if a unit does not converge, report the residue rather than forcing it.

Rewrite the records in the same pass, one per unit, where `work-log` is present, because a record that disagrees with its commit is worse than none. Delete a record the range supersedes.

## The proof

The audit is the evidence; do not invent a second check. `scripts/audit.sh <base> [tip]` runs the checks and exits non-zero on a finding, and `scripts/inversions.mjs` is its inversion detector. When there is no `work-log`, pass `--records=` and check 1 is skipped; when there is no `task-list`, pass only the `work-log` record paths; when there is neither, pass `--record-paths=` and check 4 excludes no record path. A manifest file holds one row per unit, written to `.scratchpad/history-cleanup-manifest.tsv` and passed as `--manifest=...`; without it the audit does not check the series against the approved shape.

`git range-diff <base>..<old> <base>..<new>` shows content that moved between commits. Run the repo's gate (`scripts/lint.sh`) on every commit in its own tree, and the suite (`scripts/run_tests.sh`) once at the tip with `TEST_PARALLEL=1`; a commit that fails its own gate is not bisectable, so stop and report it. A commit with no gate is an operator decision, not a silent pass.

## The two releases

1. **The manifest.** One row per unit: subject, source commits, files carried, the record it rides. Present it and wait; the boundary is cheap to change here.
2. **The candidate.** The per-unit `git log --stat` and the `range-diff` against the old range. Approval is of what the operator can see, and it is what moves the branch.

A release covers the proposal as presented. Content that enters after it needs a second release naming the commit it rides.

## Report

Report the old-to-new hash map, the operation each unit took, the range-diff summary, the record delta, any addition named after the release, the skipped record arm, and the audit's output.

## Non-goals

- Not a per-commit repair: a message, a split or a trunk rebase is `git-discipline`'s and `prepare`'s.
- Not a host verb: the pipeline drafts and confirms; this skill leaves the branch and its record.
- Not a recovery: a lost claim is `recovery`'s.
- Not a content change: a wrong final tree is a new commit, not a rewrite.
