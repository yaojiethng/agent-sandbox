---
description: Accept a merge unit into the trunk. Replay a unit already resolved at the current head, keep the trunk linear, verify the accumulated tree, and refuse a tree that does not apply. The trunk never authors or resolves.
argument-hint: "[unit: branch and commit range] [target branch]"
---

> $ARGUMENTS

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `git-discipline` - commit types, branch names and the delivery commit.

## Role

You act for the **integrator**: the trunk. The unit's author has already rebased it onto the current head and resolved every conflict. Your work is to accept or refuse the tree, not to repair it.

The same agent may author at another moment. On this action you do not edit the unit, resolve a conflict, or author a change to make the merge work.

## Intent

Land one resolved unit on the trunk and verify the accumulated tree. A unit is a branch and a commit range: the whole branch is the common case, and a range is how an early slice is named.

## Inputs

| Input | Meaning |
|---|---|
| unit | the source branch and the commit range it offers |
| target | the trunk branch the unit lands on |

## The obligation

- Replay the unit's commits one for one, each keeping its message and its handover. No merge commit, no squash.
- The unit applies at the current trunk head. If it does not, stop: send it back to the author. Do not resolve it here.
- A textual conflict, an additive overlap or a stale count is the author's to resolve. A design contradiction is the operator's; ask.
- Verify the tree, not the report: the replay count, the suite and the lint gate.

## Method

The replay mechanics are the ones already in use: read each commit and the handover it carries, exclude the export metadata, apply one commit at a time, and run the repo's checks. The `git-discipline` convention owns the commit rules; its recovery reference owns the lost-work classes. This runbook restates neither.

## Stop

Stop and ask when the unit does not apply at the head, when two units contradict each other in design, or when the operator has not chosen the unit's grain and order.

## Close

Report the unit, its commit count, the replay result and the verification numbers. End with the one question: is every unit's intent landed on the trunk?
