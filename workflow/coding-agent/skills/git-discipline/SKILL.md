---
name: git-discipline
description: agent-sandbox's git-discipline skill - the history as a commons, the four properties a series holds, the commit message, the commit types, the branch names, the fold rules and the maintenance runbooks.
---

# git-discipline

Dense, self-carrying commits cost the writer a minute and save every later reader -- the accept, the next session, a bisect, whoever debugs, and the writer next pass -- the reconstruction of intent.

## The series

**atomic**

- **Invariant:** a commit holds the whole of its change; no later commit completes, corrects or reverts it.
- **Violated when** review cannot judge a commit on its own, because the change it starts is finished further up the series.
- **Check:** `git log --oneline` read downward, and `git show --stat` per commit.
- **Rewrite when:** instead of appending a correction above its work unit, fold it -- `git commit --fixup=<sha>`, then `git rebase --autosquash <base>`; instead of splitting one outcome across commits, fold them; instead of leaving `wip:` checkpoints, squash them into the delivery commit; instead of committing a record the branch later retires, keep it out of the series until it lands.

- **Source:** Linux kernel, *Submitting patches*; Google, *Small CLs*.

**bisectable**

- **Invariant:** every commit builds and passes the suite, so a bisect names one commit.
- **Violated when** bisect cannot name the commit that introduced the failure, or the next session cannot adopt the tree at a commit.
- **Check:** `git bisect run scripts/run_tests.sh`.
- **Rewrite when:** instead of a commit that leaves the tree failing, land the failing change in the commit that makes it pass.

- **Source:** Linux kernel, *Submitting patches*.

**self-explanatory**

- **Invariant:** each commit explains itself, its subject naming the change and its body stating the reason, so no reader needs the chat, the handover or the diff.
- **Violated when** a reader cannot tell why a commit exists without the chat, the handover or the diff.
- **Check:** `scripts/check_commit_message.sh <message-file>`, then read the series cold.
- **Rewrite when:** instead of a subject naming a file and a body restating the diff, name the change in the subject and the reason in the body.

- **Source:** Chris Beams, *How to Write a Git Commit Message*; Tim Pope, *A Note About Git Commit Messages*; `git-commit(1)`, Git manual.

**blameable**

- **Invariant:** after a rewrite, the commit that introduced a line still names it.
- **Violated when** archaeology cannot find where a line came from.
- **Check:** `git blame`.
- **Rewrite when:** instead of squashing a work unit into an earlier commit and burying its origin, fold corrections only and leave the introducing commit in place.

- **Source:** `git-blame(1)`, Git manual.

## The commit message

```text
type: short description

The reason the change happened, in at most 280 characters, wrapped to the
display, never restating the diff.

Ref: a file, a record or a decision a reader would otherwise hunt for
```

An adaptation of [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/), narrowed to the active types in [`references/commit-types.md`](references/commit-types.md).

Write the subject in the imperative mood, as the Git manual puts it: as if giving orders to the codebase to change its behaviour. Keep it to 72 characters, targeting 50, with no file path and no line number, because the diff shows those. A reference earns its place in the footer or is dropped, and a transient identifier such as a session id is never cited.

`scripts/check_commit_message.sh` checks a delivery message against these rules; [`/commit`](/opt/workflow/agent/modules/coding-agent/prompts/commit.md) runs it before the commit.

## The fold

Fold a correction into the commit of the work it corrects, rather than leaving it as a later commit. That keeps the commit whole, and keeps the commit that introduced the line findable by `git blame`.

An iteration's work and a run of dependent units fold by the same rule.

- A correction folds into the delivery commit, not into an intermediate commit. A change that alters the iteration's task description, its code and its records is one amendment across all three.
- Amend while the history is cheap to rewrite: on the same branch, and ideally within the session that made the commit. Beyond that the operator rules.
- Never rewrite a commit that has left this container, and never rewrite published history.
- A temporary commit is a fine instrument where it is simpler: `fixup!`, `squash!`, or a `wip:` commit, then fold it.

**The delivery commit carries an active type. An intermediate commit never does.** A typed intermediate reads as a closed deliverable that later folds away, a false delivery surface. An intermediate is a `wip:` commit, a fixup, or an amend.

A correction to the work of a closed iteration folds into that iteration's commit and never opens a new one; the record amendments ride with the fold. When the caller names no record set, the fold is the commit alone; there are no record amendments to ride with it.

[`record-correction`](/opt/workflow/agent/modules/coding-agent/prompts/record-correction.md) runs the fold and carries the record arm for a closed artifact. A correction that would change the target's type, or that needs a handover the target does not have, is its own commit with its own handover.

## The working tree

A discard destroys whatever no ref holds, so save the work first.

To discard:

1. Read what the command would take: `git status --porcelain -- <path>` and `git diff -- <path>`, or `git clean -n` for a clean.
2. Save what no ref holds: `git stash push`, a `wip:` commit, a backup branch, or a copy aside.
3. Run the discard.
4. Confirm the path is clean: `git status --porcelain -- <path>`.

The commands in scope are `git restore`, `git checkout -- <path>`, `git clean -f`, `git reset --hard` and `git stash drop`.

A mutation you made yourself is not undone by those verbs: they restore HEAD, not the state before your edit, so copy the file aside before mutating and copy it back after.

## Grouping

Each commit should hold one coherent change, so a reader can judge it, a bisect can name it and a revert can undo it without touching anything else. A restructuring across six files is one commit, as is a script with its tests; unrelated changes are separate commits.

## The branch name

Name the branch for the commit type, the milestone and a slug, in that order; the accept takes the branch by its name. [`references/branching.md`](references/branching.md) states the parts, the branch tree and tagging.

## Runbooks

The pipeline's dispatch is [`change_pipeline.md`](/opt/sandbox/docs/reference/change_pipeline.md#the-operations)'s; this table is the skill's local index.

| Runbook | Runs when |
|---|---|
| [`prepare`](references/prepare.md) | you are on a feature branch; make it consumable by the operator's `make confirm` |
| [`history-cleanup`](runbooks/history-cleanup/SKILL.md) | a feature branch's series is messy before its PR or merge-request review |
| [`recovery`](../recovery/SKILL.md) | the record and the repository disagree; the operator starts `/recovery` and the skill classifies the description |
| [`correction`](references/correction.md) | the repository agrees with the record and the operator disagrees; the commit is wrong or the series is messy |

`prepare` is the branch-preparation primitive; it leaves a branch the operator's verbs can consume. `history-cleanup` is the operator-invoked series pass under the change pipeline, and it serves the PR or merge-request reviewer rather than the host's one-commit delivery. The two are independent: either can run on its own, and running both is two separate operator calls. You prepare the branch and report its state; the operator runs the verb. A primitive is internal, never a second flow.

The four properties are per-commit and local: a commit is judged alone. The series is judged as a whole by `history-cleanup`, because a commit cannot know its successors and reading the sequence at each commit spends agent turns for a judgement only the full range supports.

## Where to look

| File | Open when |
|---|---|
| [`references/commit-types.md`](references/commit-types.md) | you choose the type for a commit, or a new type is proposed |
| [`references/branching.md`](references/branching.md) | you create a branch, size a sub-milestone's branch model, or reach for a tag |
