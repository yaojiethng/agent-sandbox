---
description: "Proceed on a task handed over without a view, and leave a record that makes the next decision cheaper. Use when the operator says just get it done, your call, no preference, or I don't care how, or hands over a deprioritized feature or a first pass."
argument-hint: "[the task - required]"
---

> $@

# Don't know, don't care

## Scope

One small task the operator hands over without a preference, whose artifact stays. If you would delete it after the answer, prototype it instead. If the seam does not fit in one paragraph, the work is large enough to need the project's own rhythm.

## Core Directive

We are both operating with high uncertainty. Your primary directive is to **just get it working**, making sensible default decisions where information is missing, and to stop before an action that cannot be undone. To prevent technical debt from compounding silently, document every assumption, trade-off and skip you make, and the fact that would settle each one. You own the choice, never the consequence.

## Execution Workflow

1. **Declare the contract.** Write the seam before the first line of code, because it constrains what you build. Four lines, where the next reader looks: the record for a session artifact, a `README.md` for code that others call. Name the purpose, the entry point, its inputs and outputs, the command that runs it, what it does not do, and where its state lives. Done when a stranger could change it by reading one file and running one command.

2. **Execute and deliver.** Implement the small feature or tool to a working state. Prioritise speed, function and simplicity over polish. Simplify the inside freely: one file, one layer, no abstraction. Keep the seam honest, because a fact something else holds after you leave is fixed. Stored data and its shape, an interface another caller uses, a name another document cites. A secret in a file, a deletion, a publish, a send, a force-push, a change to shared state. Those wait. Done when the work runs from the command in the contract.

3. **Prove it.** Run the project's check and the run command, and report what they printed. Then use the result on its own surface. A green test proves the harness. Done when the claim of done carries the command and its output.

4. **Surface uncertainty.** Close with the log below, so the next session starts from what you learned rather than from what you assumed. Done when every entry names a fact that would settle it, or says that nothing would.

## The decision and debt log

**State.** What the artifact is, whether anything may depend on it, and who will call it.

**Assumptions.** What you decided because the requirement was vague, and the fact that would settle it.

**Trade-offs.** Each fork, the option you rejected, and the trigger that would make you switch.

**Skipped.** What a slower pass would do, what it costs when it bites, and the symptom that reports it first.

**The question worth answering.** The one fact that would change the most next time, and the check that settles it.

## When the project states no rules

These four hold. A project rule wins over one of them.

- A secret stays out of the tree, the logs, and the commit.
- A failure says what failed, with the input that failed it.
- A one-way action waits for the operator.
- Done names the command and the output.

Tests, types, structure and configuration are the project's call, not this list's.

## Invariants

- A bar that inverts is safe only for an artifact nobody keeps.
- A decision recorded with its trigger is reusable. A decision recorded alone is a preference.
