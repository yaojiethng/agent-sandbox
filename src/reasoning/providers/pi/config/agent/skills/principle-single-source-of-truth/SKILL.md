---
name: principle-single-source-of-truth
description: "Apply when scoping anything, or when one responsibility is about to have two sources. The SSOT law: a scope that duplicates a responsibility another component owns is a boundary violation and a second source of truth; stop and raise it to the operator, and do not decide the fix."
metadata:
  leitwort: SSOT
---

# Single source of truth

A responsibility has one source of truth. That is the SSOT law: every other place that carries it points at that source. A scope that duplicates a responsibility another component owns is a boundary violation and a second source of truth. Do not build it. If you see one, something is wrong: the scope or the design. Stop and raise it to the operator.

**The pattern.**

1. List the responsibilities the scope will own.
2. For each, name the component that already owns it.
3. If one is already owned, stop. You have a boundary violation.
4. Raise it to the operator. Name the responsibility, the component that owns it, and the scope that would duplicate it.
5. Do not proceed until the operator decides.

When the responsibility is a rule or a judgement carried in text, place it by the organization rule in `.agents/skills/project-documentation/references/organization.md`: pick the mode first, then the corpus, with the how-to mode held by the instruction surface. Then deconflict the scope. If an existing document already owns that scope, the new document is a second source. Extend the existing document, or stop and raise the boundary violation. A new document must have a scope no existing document owns.

**Why.** A boundary violation caught at scoping is cheap. Caught after the work is built, the duplicate has consumers and failures of its own, and the boundary is harder to redraw. The violation is evidence that the scope or the design is wrong. It is not a decision the agent gets to take silently.

Two copies of one rule also drift. The reader holds a version that no observer checks and no author updates, and the drift is silent, because each copy reads as current. A duplicate also forces the reader to decide which copy governs, and no record answers that.

The field states the prohibition as do not repeat yourself. The half that carries the load is knowledge rather than text, so a second copy of the words is a defect while it states the same knowledge twice, and not otherwise. An inline that names the source of truth states no second knowledge, which is the exception the next part states.

**What a violation looks like.** The scope adds a validation, state, rule, document, skill, instruction or code path that another component already owns. The component may be a library, an app, a service, or another part of the tree. The scope needs a parallel vocabulary to keep the two sources apart. The scope's failure is not the failure it was meant to catch. The scope repeats an output the other component already produces. The scope is defensive over-engineering: it does not trust the component. It is a leaky boundary.

**The agent does not choose the fix.** Do not silently reuse, move, remove or justify the second source. The operator may decide to reuse the component, move the responsibility, remove the duplicate, or justify a second source. That is the operator's decision. The principle raises the violation.

**A fast path is not a second source of truth.** A workflow document may inline a short form of a rule for context efficiency. It stays a fast path while the rule keeps its source of truth and the inline names that source. Remove either and the inline becomes a second source of truth.

**One rule's parts sitting apart is a different defect.** `communication-principle-keep-a-subject-near` owns it, at `$AGENT_HOME/agent/skills/communication-principle-keep-a-subject-near/SKILL.md`.

**A bridge document is a duplicate with extra steps.** A document whose only job is to connect two others duplicates content across a third place. Collapse it into the more relevant of the two and link them directly.

**A definition and its record are two objects.** The document whose workflow produces the thing owns the definition. The record owns its own shape.

**A policy file owns a rule.** The policy set is every `docs/**/*_policy.md` file, in any folder. A file of that name that owns no rule is misnamed: fold its content into its owner, give it the name of its kind, or delete it.

**The test.** During scoping, list the responsibilities the change will own. For each, name the component that already owns it. If one is already owned, stop and raise the boundary violation. Do not proceed.

For a rule or a judgement, point at the source of truth and at every carrier that names it. A carrier that states the rule without pointing at its source of truth is a second source of truth, and the next edit reaches one of the two.
