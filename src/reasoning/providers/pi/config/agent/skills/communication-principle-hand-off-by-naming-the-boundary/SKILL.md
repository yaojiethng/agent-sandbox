---
name: communication-principle-hand-off-by-naming-the-boundary
description: Name the boundary when a runbook hands work to another prompt, by stating the next prompt and its entry part, the set it owns, what stays, and where this one stops. Use when writing or reviewing a prompt or skill whose last step sends the reader to another document.
disable-model-invocation: true
metadata:
  claim: authority
---

# Name the handoff boundary

A runbook that hands work to another prompt names the boundary, so a reader can see where one document ends and the next begins.

**The pattern.** Four moves, in order.

1. Name the next prompt and the part that runs. `/iter` names `/wrapup` for the close and `/commit` for the commit, not `/wrapup` alone.
2. List what the next prompt owns, and say that this one does not restate it. A step absent from both lists is a gap.
3. Name what stays here, with its reason. A step that stays without a reason reads as an oversight.
4. State where this runbook stops and who picks it up.

A prompt that ends inside its own scope omits the handoff.

**Why.** Four prompts apply this shape and none of them used to name it, so each restatement was a copy that drifts. A bare name leaves the reader to work out where to enter a long runbook, and an owned step left off both lists falls between the two documents.

**The test.** Read the last step. Can a reader name the next prompt, its entry part, what it owns, what stays, and the stopping point? Any gap is an unwritten handoff.
