---
description: Merge a merge request into the trunk. You are on the trunk; replay a unit already resolved at the current head, keep the trunk linear, verify the accumulated tree, and refuse a request that does not apply.
argument-hint: "[unit: branch and commit range] [target branch]"
---

> $ARGUMENTS

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `git-discipline` - commit types, branch names and the delivery commit.

## The scenario

You are on the trunk, and a merge request is ready. Confirm it before you start:

- `git rev-parse --abbrev-ref HEAD` names the trunk.
- `git status --porcelain` is empty: the trunk carries no uncommitted work.
- `git log --oneline <trunk>..<unit>` is non-empty: the unit is not already on the trunk.
- A dry-run replay of the unit at the head reports no conflict.

If a check fails, you are not in this scenario. Stop and ask; do not resolve the request on the trunk.

## Intent

Land one resolved unit on the trunk and verify the accumulated tree. A unit is a branch and a commit range: the whole branch is the common case, and a range is how an early slice is named.

## Inputs

| Input | Meaning |
|---|---|
| unit | the source branch and the commit range it covers |
| target | the trunk branch the unit lands on |

## The obligation

- Replay the unit's commits one for one, each keeping its message and its handover. No merge commit, no squash.
- The unit applies at the current trunk head. If it does not, stop: send it back to the branch. Do not resolve it here.
- A textual conflict, an additive overlap or a stale count is the branch's to resolve. A design contradiction is the operator's; ask.
- Verify the tree, not the report: the replay count, the suite and the lint gate.

## Method

The replay mechanics are the ones already in use: read each commit and the handover it carries, exclude the export metadata, apply one commit at a time, and run the repo's checks. The `git-discipline` convention owns the commit rules; its recovery reference owns the lost-work classes. This runbook restates neither.

## Stop

Stop and ask when the unit does not apply at the head, when two units contradict each other in design, or when the operator has not chosen the unit's grain and order.

## Close

Report the unit, its commit count, the replay result and the verification numbers. End with the one question: is every unit's intent landed on the trunk?
