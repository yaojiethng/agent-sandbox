# Prepare

A branch is ready for the operator's `make confirm` when its tip descends from the trunk head and carries one delivery commit. This runbook produces that state. [`branching.md`](branching.md) owns the readiness rule and the queue; the `git-discipline` skill owns the branch and commit rules.

## The scenario

You are on a feature branch preparing it for acceptance. Confirm it before you start:

- `git rev-parse --abbrev-ref HEAD` names your branch, not the trunk.
- `git log --oneline <trunk>..HEAD` is non-empty: the branch carries one delivery commit the trunk does not.

If either check fails, you are not in this scenario. Stop and ask.

If `git merge-base --is-ancestor <trunk> HEAD` fails, the trunk has moved; rebase before you finish. If it succeeds, the branch is already fast-forwardable.

## Inputs

| Input | Meaning |
|---|---|
| branch | the branch that carries the delivery commit |
| trunk head | the commit the branch must descend from |

## Method

Rebase onto the head, re-realize each commit's intent, keep the commit granularity, and run the repo's checks. Resolve every conflict; content the trunk already carries is dropped. Stop on a semantic divergence; ask, and do not guess a shared meaning.

A port -- a change transplanted across branches -- is this operation on the target branch: the correction lands, and `/commit` folds it into the commit that owns it.

## Handoff

A prepared branch is consumable by the operator's `make confirm`. This runbook owns the rebase and the branch's fast-forwardability; it does not order and it does not accept.

## Close

Report the branch, the commit count and the checks. End with the one question: does the branch tip descend from the trunk head, so the trunk can fast-forward to it?
