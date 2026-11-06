---
description: Accept a prepared branch into the trunk. You are on the trunk; fast-forward to a branch whose tip descends from the head, verify the staged tree, and refuse a branch that is not ready.
argument-hint: "[branch] [trunk head]"
---

> $ARGUMENTS

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `git-discipline` - commit types, branch names and the delivery commit.

## The scenario

You are on the trunk, and a branch is ready. Confirm it before you start:

- `git rev-parse --abbrev-ref HEAD` names the trunk.
- `git status --porcelain` is empty: the trunk carries no uncommitted work.
- `git merge-base --is-ancestor <trunk> <branch>` succeeds: the trunk head is an ancestor of the branch tip, so the accept is a fast-forward.

If a check fails, you are not in this scenario. Stop and ask; do not resolve the branch on the trunk.

## Intent

Fast-forward the trunk to a ready branch and verify the staged tree. The branch prepared itself; the trunk only moves its pointer.

## Inputs

| Input | Meaning |
|---|---|
| branch | the prepared branch |
| trunk head | the commit the accept is expected to replace |

## The obligation

- Accept only a branch whose tip descends from the head.
- Stage the branch at the head in a scratch worktree and run the suite and the lint gate.
- Commit with a compare-and-swap: `update-ref <trunk> <tip> <old-head>`. If it loses, nothing changed.
- Never edit or resolve. A conflict sends the branch back to prepare.

## Method

The accept is the compare-and-swap above. The `git-discipline` convention owns the commit rules. This runbook restates neither.

## Stop

Stop and ask when the branch is not ready, when the staged checks fail, or when the compare-and-swap loses.

## Close

Report the branch, the old and the new head, and the checks. End with the one question: did the head advance?
