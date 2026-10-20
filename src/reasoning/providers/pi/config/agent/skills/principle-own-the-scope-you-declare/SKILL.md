---
name: principle-own-the-scope-you-declare
description: Own the scope a workflow document declares, holding everything it owes, describing no work outside it, and handing on one artifact to one next step. Use when writing or reviewing a prompt, a skill, a procedure, or a record, and when a document starts explaining a step that belongs to another one.
disable-model-invocation: true
---

# Own the scope you declare

A workflow document owns the scope it declares. It holds everything that scope owes, and it describes no work outside it.

## The pattern

Read the declared scope first: a prompt's `Scope` declaration, a skill's `description`, a record's `## Scope` section. The agent neither sets it nor infers it. Where no scope is declared, that is the defect to fix before this one applies.

A document hands one artifact to one next step, and every success criterion is met from that scope. A document that hands on two artifacts, or hands one to two next steps, is two documents, or a dispatcher that declares itself one.

The document holds everything its scope owes.

1. The input it receives.
2. The decision it takes.
3. The output it hands on.
4. The directions it gives the operator.
5. The evidence that it ran.

It describes no work outside that scope, whether or not the description is accurate.

A top-down view of the whole flow is a different artefact. The sequence across every step, and why the steps sit in that order, belongs to a concept document when a reader needs the model, and to an ADR when it records a decision and its alternatives.

## When content does not belong

One of three, and widening is the operator's decision:

- link to the document that owns it,
- move the content there,
- ask the operator to widen the scope.

## Why

It catches a document locally accurate and globally unreliable. Every sentence is true of the moment it was written, nothing compares it against the work on either side, and when an adjacent stage changes the copy stays behind with no signal.

## The test

Take each paragraph and name the scope it serves. Serving this one, it must name the input, the decision, the output, the directions or the evidence. Serving an earlier or later one, it is out of scope unless it is a pointer.
