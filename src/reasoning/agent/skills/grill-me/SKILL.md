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

Interview the user relentlessly until you reach a shared understanding. Map the design as a **design tree**: every decision branches into the decisions that hang off it.

Ask the questions one at a time. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask now without guessing at answers you have not heard. Put one frontier question, then wait. A question whose answer depends on one still open belongs to a later turn, not this one.

The next question waits until every question already put is explicitly resolved: the user answered it, withdrew it, or parked it. A side-question of your own is parked in the open list rather than asked now, and is put in full once the question it interrupted is settled.

A question the user asks back takes precedence over the one you asked. It is not an answer, and not a side-question of yours: they may need it settled before they can answer, and it may expose an assumption the pending question rests on. Answer it in full, then ask what you need to close their thread, one question at a time, with the pending question held on the open list -- neither dropped nor answered for them.

When the thread ends, re-derive the frontier before putting anything. The thread may have settled the pending question, moved the frontier past it, or broken an assumption a resolved branch rests on, which re-opens that branch and every question downstream of it; the earlier answer is corrected before anything new is put. Put the question the frontier now holds, naming what the thread settled and what it re-opened; only when the frontier is unchanged do you re-put the pending question, and then repaired -- narrowed, with the context it was missing, and with options that cover the choice it hid.

A branch is resolved only by the user's choice, a withdrawal or a park. The recommendation is advice carried with a question, never a fallback for the one the user did not give.

Test every branch against the problem summary: a branch that does not serve the stated problem is resolved or dropped before the plan widens.

Format the question like so:

```text
**Q1** - **<question title>**: <question body, might be multiple paragraphs>

Options:
- **<option>**: <benefit>; <tradeoff>
- **<option>**: <benefit>; <tradeoff>

-> **Recommendation:** <the option you recommend, and why>
```

Offer the options that differ in kind, each with its benefit and its tradeoff, then recommend one. Do not present a recommendation without the alternatives it beat.

Finding _facts_ is your job, never the user's. When the question needs a fact from the environment (filesystem, tools, etc.), explore the codebase, or use the `dispatch` skill to send a read-only child after a search large enough to run beside the interview; do not ask the user for anything you could look up yourself. Do not block the whole interview on it: only a question downstream of that fact waits for the child to report.

The session is done when the frontier is empty: every branch of the design tree decided by the user, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.
