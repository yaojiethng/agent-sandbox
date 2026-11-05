# Name the handoff boundary

Open this when a workflow ends and directs the reader to a subsequent one: a prompt naming the prompt that follows, a skill naming its runbook, a runbook handing to the next.

## The pattern

Four moves, in order.

1. Name the next workflow and the part that runs, so the reader is never left to work out where to go. `/iter` names `/wrapup` for the close and `/commit` for the commit, not `/wrapup` alone.
2. List what the next workflow owns, and say that this one does not restate it. A step absent from both lists is a gap.
3. Name what stays here, with its reason. A step that stays without a reason reads as an oversight.
4. State where this one stops and who picks it up.

A workflow that ends inside its own scope omits the handoff.

## When it applies

When the workflow is **invoked and its end continues into another run**: the reader is mid-job and the job transfers. A tutorial's closing pointer starts a separate job; an ADR's supersession is a field `decision-records` already owns; a reference has no last step; and code's contract is a signature a compiler enforces, with a caller at the other end rather than a continuation.

## Why

Four prompts applied this shape and none named it, so each restatement was a copy that drifts. A bare name leaves the reader to work out where to enter a long runbook, and an owned step left off both lists falls between the two documents.

## The test

At the last step of the current workflow, can we consistently predict that a reader will want to invoke a next prompt? Are the next prompt's invocation parameters already well defined by that time?
