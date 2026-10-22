---
description: "Owns the history and merge mechanism: checkpointing, the intermediate commits that fold into a delivery commit, recovery of a mixed tree, and the merge policy. The commit message, the types, the branch names and the fold rules live in the `git-discipline` convention-skill."
scope: ["history rewriting", "merges"]
reader: [agent]
---

# Git Policy

## The convention

The commit message, the commit types, the branch names and the fold rules live in the `git-discipline` convention-skill, `.agents/skills/git-discipline/SKILL.md`.

The sections below are what remains: the history and merge mechanism, which states what a mid-iteration tree does and how a branch lands.

## Checkpointing

An iteration that ends with uncommitted work is a risk -- the handover records intent, but the filesystem is the only copy. Commit at iteration end even if the work is incomplete.

**Rules:**

- At iteration end, commit all work-in-progress on the active branch with a clear message: `wip: description of incomplete state`
- `wip` is not a commit type -- it is a prefix that signals the commit is not reviewable. The next iteration amends or follows up.
- Intermediate commits (wip, corrections, amends) are not subject to the type enforcement rule -- that rule applies only to the delivery commit at iteration end. A delivery prefix is still reserved for the delivery commit; type an intermediate as `wip:` or as an amend of a prior `wip:`.
- Do not leave uncommitted changes across iteration boundaries -- this includes stashes. If work is incomplete at iteration end, commit with `wip:` prefix instead of stashing. The handover cannot reconstruct files; the commit can.
- On integration branches, session branches should be merged (not left dangling) before the session ends, even if the integration branch itself is not ready for `main`.

This is the git-level equivalent of the `autosave.diff` pattern in the execution model -- a checkpoint that preserves state without implying completeness.

## WIP Commits

`wip:` is an accepted commit prefix for intermediate checkpoints. A `wip:` commit is a checkpoint, not a deliverable. It is never reviewable and never reaches `main` as-is. Squash every `wip:` commit into the typed delivery commit at iteration end.

Intermediates are `wip:` or amends, never delivery-typed. A mid-iteration `fix:`/`feat:`/`docs:`/`chore:` commit reads as a closed deliverable that later folds away -- a false delivery surface that misleads the reviewer. When a discrete task group goes in, land it as `wip:` and squash it into the delivery commit at the same close that owns it, or amend an existing `wip:`. Type the delivery prefix only once, on the delivery commit.

Use `wip:` when:

- The current task is a far-reaching refactor or audit-type change and you need checkpoints.
- An exchange is open, so its result is provisional. Write it to the record first, per the write-back rule in [`iteration_policy.md`](iteration_policy.md), and commit the record as `wip:`.
- The operator directs a wip commit.
- You propose a wip commit and the operator accepts.

The delivery commit at iteration end always carries a type prefix from the Active Types table, however many wip commits preceded it. wip commits are implementation detail; the delivery commit replaces them.

## Transient commits fold into the delivery commit

One delivery commit carries each iteration. Transient commits during the iteration fold into it. Three kinds exist:

- `wip:` checkpoints -- in-progress snapshot that is never reviewable; squash into the delivery commit at iteration end.
- Correction commits -- an amend or fixup that corrects a commit made earlier in the same iteration; fold into that commit via `git commit --fixup=<hash>` and `git rebase -i --autosquash`.
- The close edit -- the `Status: Closed` flip and the roadmap write-back; they belong in the delivery commit.

Each kind resolves to the single delivery commit; the delivery commit is the sole reviewable surface.

**Stuck procedure.** When the iteration's history already holds the work commit and the close edit is still outstanding, fold the edit into the work commit: set `Status: Closed`, apply the write-back, then amend (`git commit --amend`) or, for a non-HEAD delivery commit, `git commit --fixup=<hash>` plus `git rebase -i --autosquash`. The end state is one commit per iteration.

## Amending

Report and stop when folding needs an interactive rebase with several conflict edits. The cost has moved past an amendment, and the alternative instrument is a port: see `workflow/coding-agent/prompts/rebase.md`.

What may be amended after a close is in [`iteration_policy.md`](iteration_policy.md); the record forms are in the `record-correction` procedure and [`documentation_policy.md`](documentation_policy.md#post-close-document-corrections). Which change a correction may contain is the judgement of `principle-minimal-corrections`; this section decides only where it lands.

## Recovery

Procedures for recovering from situations where normal discipline breaks down.

### Splitting interleaved changes

When a single file contains changes from multiple iterations that must be split into separate commits:

1. Save the full diff: `git diff > file.patch`
2. Reset to HEAD: `git checkout HEAD -- file`
3. For each commit, apply only the relevant hunks: `git apply file.patch` (then stage and commit)
4. Repeat for each remaining iteration's changes

If the file cannot be split by hunk boundaries (interleaved changes to the same logical section), consider splitting into two files or restructuring the changes so each iteration's work is disjoint.

## Merge Policy

Two integration forms exist, and they keep separate commit disciplines. A live session branch that the agent still works on lands by squash merge, per the section below. A `draft/`-prefixed export of a reviewed session lands by one-for-one replay, per the draft section.

### Session branch -> integration branch

**Squash merge.** Each session branch becomes a single commit on the integration branch. The squash message uses the appropriate commit type and summarises the session's contribution. Individual session commits are implementation detail -- the integration branch reads as a sequence of coherent steps.

### Draft branch -> feature branch

**One-for-one replay.** A `draft/`-prefixed export of a reviewed session lands on the feature branch as its own commits. The operator replays the export's commits one-for-one in export order, oldest draft first; each replayed commit keeps its message, author, and handover, so the branch history reads as original work. No merge commit and no squash describes the operation. The `.draft-state` commit that opens every export is never replayed: it records export state, which is false once the work lands on the branch. The operation is defined in the `/merge` workflow template under `workflow/coding-agent/prompts/`. A stale branch whose work must be re-derived against a changed target follows the `/rebase` template instead.

### Session branch -> `main` (simple case)

**Squash merge.** Same rationale -- the branch collapses to one commit on `main`. If the branch has only one commit already, a fast-forward merge is acceptable.

### Integration branch -> `main`

**Merge commit.** Preserves the sub-milestone as a visible unit in `main`'s history. The merge commit message follows the format:

```text
feat: complete M2.1 — snapshot pipeline and diff workflow
```

Use the dominant commit type for the sub-milestone. If the sub-milestone is mixed (feat + docs + build), use `feat` if it delivers new capability, or `docs` if it is primarily documentation.

### Review gate

No branch merges to `main` without operator review and approval. This restates the system invariant: all repository mutation is operator-initiated. For integration branches, the operator may review incrementally (session branch merges) or as a whole (integration branch merge to `main`), but the final merge to `main` always requires explicit approval.

### Conflict resolution

The operator resolves conflicts. When two session branches on the same integration branch touch overlapping files, the second branch to merge resolves conflicts against the integration branch before merging. Conflicts on merge to `main` are resolved on the integration branch, not on `main`.
