---
description: Accept a prepared branch by fast-forwarding the trunk. You are on the trunk; verify the staged tree, then compare-and-swap the head to a branch whose tip descends from it. Refuse a branch that is not ready.
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

## Why preflight, then CAS

The accept is a preflight, a staged verification, then a compare-and-swap. It never acts and repairs.

- The preflight is the scenario above. It refuses with a reason and changes nothing.
- The staged verification runs the suite and the lint gate on a scratch worktree at the branch tip. A red tree changes nothing.
- The compare-and-swap writes the trunk ref only if it still points at the head that was checked. A lost race changes nothing.

The alternative, act then roll back, is rejected: the rollback is a second write that can fail, and it leaves the trunk advanced and red in the window. Verify before the commit, and there is no rollback path.

## The obligation

- Accept only a branch whose tip descends from the head.
- Stage the branch at the head in a scratch worktree and run the suite and the lint gate.
- Commit with a compare-and-swap: `update-ref <trunk> <tip> <old-head>`. If it loses, nothing changed.
- Never edit or resolve. A conflict sends the branch back to prepare.

## Method

The accept is the compare-and-swap above. The `git-discipline` convention owns the commit rules. This runbook restates neither.

## Handoff

A branch that is not ready, including one whose trunk moved, goes back to `/prepare-rebase`. The order may come from `/merge-queue`; the direct path needs no queue. This runbook owns the preflight, the staged verification and the compare-and-swap.

## Close

Report the branch, the old and the new head, and the checks. End with the one question: did the head advance?
