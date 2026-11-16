---
description: "Land an iteration's work as one delivery commit: the three operations (commit, amend, squash), the fold by autosquash, the in-session checkpoint, and the post-commit self-check. Use at an iteration's close, after /wrapup has closed the record."
argument-hint: "[optional: a commit range to audit]"
---

> $ARGUMENTS

# /commit - The Delivery Commit

**Scope:** landing the iteration's work as one commit. It owns the three operations, the checkpoint and the self-check. The close that prepares the record is [`/wrapup`](wrapup.md)'s, and the rules a commit satisfies are the protocol's and the `git-discipline` convention's.

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `git-discipline`

## The three operations

| Operation | Runs when |
|---|---|
| **commit** | the close's work lands as one delivery commit |
| **amend** | a change to the delivery commit, before it leaves this container |
| **squash** | a pile of commits folds into one |

A correction belongs to the commit of the work it corrects, so the squash needs its target. `--fixup` encodes the target in the correction's own commit, and `--autosquash` folds it there:

```bash
git commit --fixup=<sha>
git rebase --autosquash <base>
```

A correction with no target yet is a `wip:` commit, which the squash folds.

## The checkpoint (in-session, recurring)

Run this after each committed task group. It is a hygiene pass, not a release point; it does not stop the session.

### A1. Enumerate the range

```bash
git log --oneline <base>..HEAD
```

`<base>` is the branch point, the last delivery commit on the trunk; with no named base, the previous merge base. Identify each commit by kind: the delivery commit, `wip:` checkpoints, and the close edit.

### A2. Squash to one delivery commit

```bash
git reset --soft <base>          # keep the work staged
git add -A
git commit -F <message-file>
```

When the work commit has already landed and the close edit is outstanding, amend that commit rather than adding one.

### A3. Verify the result

```bash
git log --oneline <base>..HEAD   # one commit
git status --short               # clean
bash scripts/lint.sh
```

## The close commit

### B1. Stage what the close prepared

[`/wrapup`](wrapup.md) has closed the handover and written the roadmap row. Confirm both are staged; the handover format gate checks the record's shape.

### B2. Land the single commit

Write the message per the `git-discipline` table: the type, an imperative subject, the reason.

```bash
git commit -F <message-file>
```

The `commit-msg` hook in `.githooks/` is installed into `.git/hooks/commit-msg` at container start on copy delivery, and checks the message and refuses a non-conforming one, naming the layer and the rule; fix the message and commit again.

### B3. Self-check the range

Read the range back against three records: `scripts/check_commit_message.sh` owns the message, the `git-discipline` convention owns the fold and the branch, and [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md) owns the close's invariants. Fix what you find by amending or squashing, or record it as a deliberate deviation with its reason.
