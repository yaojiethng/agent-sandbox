---
name: git-discipline
description: agent-sandbox's git-discipline convention - the commit message, the commit types, the branch names, the fold rules and the maintenance runbooks.
---

# git-discipline

A commit is the unit a reviewer reads. This file states what a commit message carries, where a change lands when it corrects earlier work, and which runbook runs each history operation. `merge`, `rebase`, `record-correction` and `history-cleanup` each open by naming this convention, and the runbook table below is where the family is named as one set.

## The commit message

```text
type: short description
```

A lower-case type prefix, a colon, a space, and an imperative summary that completes "this commit will...". `feat: add snapshot validation gate`, not `feat: added snapshot validation gate`.

| Part | Rule |
|---|---|
| subject | 50 characters or fewer, carrying no file path and no line number, because the diff shows those |
| body | optional, one sentence after a blank line, 280 characters or fewer |
| footer | optional, for a reference that earns its place: a file, a record, or a decision a reader would otherwise hunt for |

The description states why the change happened and what category it is, not what changed line by line. A reason longer than 280 characters lives in the handover or the ADR, and the body points there. Drop a reference added for completeness, and never cite a transient identifier such as a session id.

The type-prefixed shape follows [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

**The delivery commit carries an active type. An intermediate commit never does.** A typed intermediate reads as a closed deliverable that later folds away, a false delivery surface. An intermediate is a `wip:` commit, a fixup, or an amend. The type is chosen from the diff alone, so the record's type and the commit's type are independent judgements.

## The fold

A change belongs to the commit of the work it corrects. Fold it there rather than stacking it after: a stack of one-line fixups on one logical unit is the history's least readable form, and what the fold discards from the history the handover keeps.

- The unit of work, not the commit, is the unit of amendment. A change that alters a unit's task description, its code and its records is one amendment across all three.
- Amend while the history is cheap to rewrite: on the same branch, and ideally within the session that made the commit. Beyond that the operator rules.
- Never rewrite a commit that has left this container, and never rewrite published history.
- A temporary commit is a fine instrument where it is simpler: `fixup!`, `squash!`, or a `wip:` commit, then fold it. The end state is one commit per unit.

A correction to the work of a closed iteration folds into that iteration's commit and never opens a new one; the record amendments ride with the fold.

Two cases decide who rules on a correction:

- **The session that made the commit is still live.** The agent folds the correction into that commit, whichever actor raised the defect, without asking.
- **That session has ended.** The operator rules whether the correction folds into that commit or lands as a separate commit.

[`record-correction`](../../../workflow/coding-agent/prompts/record-correction.md) runs the fold and carries the record arm for a closed artifact; the mechanics are there. A correction that would change the target's type, or that needs a handover the target does not have, is its own commit with its own handover.

## Grouping

A commit is a coherent unit of change, and fewer meaningful commits beat many granular ones: a policy restructuring that touches six files is one commit, and a script with its tests is one. Unrelated changes are separate commits.

## The branch name

```text
type/milestone_description
```

The type matches the commit type, the milestone is the sub-milestone ID with dots replaced by underscores, and the description is lowercase and hyphen-separated, with the underscore reserved for the milestone separator. A change not tied to a sub-milestone omits the milestone, as in `workflow/git-policy`.

## Runbooks

| Runbook | Runs when |
|---|---|
| [`merge`](../../../workflow/coding-agent/prompts/merge.md) | a reviewed draft export lands on a branch as one commit per iteration, or a session branch lands on an integration branch |
| [`rebase`](../../../workflow/coding-agent/prompts/rebase.md) | a stale branch is ported onto a changed target, one commit per iteration |
| [`history-cleanup`](../../../workflow/coding-agent/skills/history-cleanup/SKILL.md) | a draft branch's series holds an inversion, before the branch is packaged for review |

The first two are prompts and the third is a skill, because it ships a detector beside itself and a prompt is one file. Each runbook states its own procedure.

## Where to look

| File | Open when |
|---|---|
| [`references/commit-types.md`](references/commit-types.md) | you choose the type for a commit, or a new type is proposed |
| [`references/branching.md`](references/branching.md) | you create a branch, size a sub-milestone's branch model, or reach for a tag |
