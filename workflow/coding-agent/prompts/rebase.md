---
description: Offer a merge unit from a branch. Rebase it onto the current trunk head, resolve every conflict, drop what the trunk already carries, and make it apply cleanly. The author owns the merge-back; the trunk only accepts or refuses.
argument-hint: "[branch] [trunk head] [unit range - the whole branch, or a slice]"
---

> $ARGUMENTS

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `git-discipline` - commit types, branch names and the delivery commit.

## Role

You act for the **author**: a branch. You own the unit's merge-back. You rebase it onto the current trunk head, resolve every conflict yourself, and drop what the trunk already carries. The integrator will not do this for you.

## Intent

Make the branch's work available as a unit that applies at the current trunk head. The unit is the whole branch, or an early slice: one commit, authored as its own unit with its own closed handover.

## Inputs

| Input | Meaning |
|---|---|
| branch | the branch that carries the unit |
| trunk head | the commit the unit must apply to |
| unit range | the commits the unit offers; the whole branch by default |

## The obligation

- The tree applies at the trunk head with every conflict resolved by you.
- Content the trunk already carries is dropped. Content it superseded is adapted or dropped.
- One commit per unit; the unit's handover is closed and its message keeps its type prefix.
- Stop on a semantic divergence between the unit and the trunk; ask. Do not guess a shared meaning.

## Method

The port mechanics are the ones already in use: read each commit's handover, re-realize its intent against the current tree, keep the commit granularity, and run the repo's checks. The `git-discipline` convention owns the commit and branch rules; `/commit` owns the unit's close. This runbook restates neither.

## Stop

Stop and ask when the trunk's design contradicts the unit, when the intent is ambiguous, or when the unit is an early slice whose grain the operator has not chosen.

## Close

Report the branch, the unit range, the commits offered and the checks run. End with the one question: does the unit apply at the trunk head with every conflict resolved?
