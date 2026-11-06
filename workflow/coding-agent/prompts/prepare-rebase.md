---
description: Prepare a branch for acceptance by rebasing it onto the trunk head. You are on a feature branch carrying a unit the trunk does not; rebase it, resolve every conflict, drop what the trunk already carries, and make it fast-forwardable.
argument-hint: "[branch] [trunk head] [unit range - the whole branch, or a slice]"
---

> $ARGUMENTS

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `git-discipline` - commit types, branch names and the delivery commit.

## The scenario

You are on a feature branch preparing it for acceptance. Confirm it before you start:

- `git rev-parse --abbrev-ref HEAD` names your branch, not the trunk.
- `git log --oneline <trunk>..HEAD` is non-empty: the branch carries a unit the trunk does not.

If either check fails, you are not in this scenario. Stop and ask.

If `git merge-base --is-ancestor <trunk> HEAD` fails, the trunk has moved; rebase before you finish. If it succeeds, the branch is already fast-forwardable.

## Intent

Make the branch ready: its tip descends from the current head, so the trunk can fast-forward to it. A unit is the whole branch, or an early slice prepared as its own unit: one commit, with its own closed handover.

## Inputs

| Input | Meaning |
|---|---|
| branch | the branch that carries the unit |
| trunk head | the commit the branch must descend from |
| unit range | the commits the unit covers; the whole branch by default |

## The obligation

- The head is an ancestor of the branch tip, so the accept is a fast-forward.
- Every conflict is resolved by you, and content the trunk already carries is dropped.
- One commit per unit; the unit's handover is closed and its message keeps its type prefix.
- Stop on a semantic divergence; ask. Do not guess a shared meaning.

## Method

Rebase onto the head, re-realize each commit's intent, keep the commit granularity, and run the repo's checks. The `git-discipline` convention owns the commit and branch rules; `/commit` owns the unit's close. This runbook restates neither.

## Handoff

A ready branch can go straight to `/accept-fast-forward`, or to `/merge-queue` first to see the order. This runbook owns the rebase and the branch's fast-forwardability; it does not order and it does not accept.

## Close

Report the branch, the unit range, the commit count and the checks. End with the one question: does the branch tip descend from the trunk head, so the trunk can fast-forward to it?
