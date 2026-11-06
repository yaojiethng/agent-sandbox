---
description: Order the ready branches for acceptance. Reads the mergeability of the open branches and emits the merge queue; it prepares nothing and accepts nothing.
argument-hint: "[branches...]"
---

> $ARGUMENTS

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `git-discipline` - commit types, branch names and the delivery commit.

## The scenario

You are the scheduler. There are open branches, and at least one is ready. Confirm it before you start:

- `git branch --list` names the open branches.
- For each branch, `git merge-base --is-ancestor <trunk> <branch>` succeeds and the tip is ahead: the branch is `ready`.
- A branch whose tip is behind the head is `accepted`; a branch that is neither is `not-ready`.

If no branch is ready, the queue is empty. Stop and say so.

## Intent

Emit an order over the ready branches, so the consumer can accept them one at a time. The order is a judgement of criticality and dependency; it changes no branch's mergeability.

## Inputs

| Input | Meaning |
|---|---|
| branches | the open branches |
| mergeability | derived from the ancestor checks |
| dependencies | a branch prepared on another branch is its child |

## The obligation

- Only ready branches enter.
- A stack is a contiguous run: a child follows its parent, and the run is not interrupted.
- A branch that is `not-ready` is left out; it re-prepares and re-enters.
- Recompute on every head advance. The order is derived, not stored.
- Do not prepare and do not accept.

## Method

Read the mergeability, group the stacks, and order the runs by criticality. The consumer is `/accept-fast-forward`; this runbook does not run it.

## Handoff

If nothing is ready, hand off to `/prepare-rebase` for the branch the operator names. Otherwise hand the order to `/accept-fast-forward`. This runbook owns the order alone; it does not prepare and it does not accept.

## Close

Report the order, the ready set, and every excluded branch with the reason it was left out.
