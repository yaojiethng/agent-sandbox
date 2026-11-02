---
name: principle-own-the-scope-you-declare
description: Apply when a workflow document declares a scope, when one has started explaining a step that belongs to another, or when a rule set has two rules for one situation. Hold everything the scope owes, describe no work outside it, and hand on one artifact to one next step.
---

# Own the scope you declare

A document owns the scope it declares, and so does a rule. Each holds everything its scope owes, and describes no work outside it.

**The pattern.** Read the declared scope first: a prompt's `Scope` declaration, a skill's `description`, a record's `## Scope` section. The agent neither sets it nor infers it. Where no scope is declared, that is the defect to fix before this one applies.

The declared scope names one artifact and one next step, and every success criterion is met from that scope. A scope that names two artifacts, or one artifact and two next steps, is two scopes. Split it, or declare it a dispatcher.

A rule declares the situation it governs, and that situation is its scope. Two rules that govern one situation are one rule, however differently they are worded, and merging them is what makes the set extendable: a reader adds a rule for a new situation, and removes one without the rest going stale. A rule a reader must hold another rule to apply is coupled, and the coupling is the defect rather than the length.

The document holds everything its scope owes.

1. The input it receives.
2. The decision it takes.
3. The output it hands on.
4. The directions it gives the operator.
5. The evidence that it ran.

It describes no work outside that scope, whether or not the description is accurate.

A top-down view of the whole flow is a different artefact. The sequence across every step, and why the steps sit in that order, belongs to a concept document when a reader needs the model, and to an ADR when it records a decision and its alternatives.

**Why.** It catches a document locally accurate and globally unreliable. Every sentence is true of the moment it was written, nothing compares it against the work on either side, and when an adjacent stage changes the copy stays behind with no signal.

**Fires on.** A document that declares a scope, a document whose content has drifted into a neighbour's step, and a rule set where two rules govern one situation.

**When content does not belong.** One of three, and widening is the operator's decision:

- link to the document that owns it,
- move the content there,
- ask the operator to widen the scope.

**What it does not cover.** The seam where one document hands to the next: `communication-principle-hand-off-by-naming-the-boundary`. How precise each step's instruction is: `principle-match-precision-to-stakes`. Whether a rule earns its place at all: `communication-principle-cut-what-carries-nothing`, whose test a rule set's rules each answer before their scope is compared.

**The test.** Take each paragraph and name the scope it serves. Serving this one, it must name the input, the decision, the output, the directions or the evidence. Serving an earlier or later one, it is out of scope unless it is a pointer.

Then take each rule and name the situation it governs. A second rule naming the same situation is the same rule written twice, and a rule that needs another rule beside it to be applied is one rule split in two.
