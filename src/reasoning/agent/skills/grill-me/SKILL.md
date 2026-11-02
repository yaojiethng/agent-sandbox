---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
disable-model-invocation: true
---

## Problem summary first

Ground the interview in the problem before questioning the plan. Establish a problem summary with three parts:

1. The problem we encountered.
2. How we are sure it is a problem. State the evidence we observed.
3. The kind of solution we are trying to achieve.

Take each part from the session when the session already holds it: the goal and problem a plan session recorded, the context it gathered, and the conversation a direct invocation arrives in. Ask only for a part the session lacks. The summary is required of every session, so a caller with no prior context is asked for all three parts before the interview starts.

## Interview

Read the `grilling` skill's `SKILL.md` in full and follow it. Test every branch against the problem summary: a branch that does not serve the stated problem is resolved or dropped before the plan widens.
