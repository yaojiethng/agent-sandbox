---
name: communication-principle-hand-off-by-naming-the-boundary
description: "Apply when one unit hands work to another: name the unit that receives it, what it owns, what stays here, and where this one stops."
---

# Name the handoff boundary

A unit that hands work to another names the boundary, so a reader can see where one ends and the next begins.

**The pattern.** Four moves, in order.

1. Name the next unit and the part that runs, in the handoff itself, so the reader is never left to work out where to go. `/iter` names `/wrapup` for the close and `/commit` for the commit, not `/wrapup` alone.
2. List what the next unit owns, and say that this one does not restate it. A step absent from both lists is a gap.
3. Name what stays here, with its reason. A step that stays without a reason reads as an oversight.
4. State where this one stops and who picks it up.

A unit that ends inside its own scope omits the handoff.

**Why.** Four prompts apply this shape and none of them used to name it, so each restatement was a copy that drifts. A bare name leaves the reader to work out where to enter a long runbook, and an owned step left off both lists falls between the two documents.

**Where you meet it.** The seam between two units, where one finishes a job and the next starts one.

**What it does not cover.** What a unit's own extent holds and owes: `principle-single-source-of-truth`. How precise each step's instruction is: `principle-match-precision-to-stakes`.

**The test.** Read the last step. Can a reader name the next prompt, its entry part, what it owns, what stays, and the stopping point? Any gap is an unwritten handoff.
