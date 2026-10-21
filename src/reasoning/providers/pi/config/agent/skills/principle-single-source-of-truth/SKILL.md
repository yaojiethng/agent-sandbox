---
name: principle-single-source-of-truth
description: "A norm has one source of truth, so you do not repeat yourself. Apply when writing, moving or copying a rule, a judgement or a definition across documents. A second copy is a defect unless it points at that source."
disable-model-invocation: true
metadata:
  claim: source
---

# Single source of truth

A norm has one source of truth, and every other place that carries it points at that source.

**The pattern.**

1. Name the norm's kind, per `docs/reference/agent_workflow.md` `### Norm kinds`.
2. Put it in the source of truth that kind carries.
3. Make every other carrier a pointer to that source.

**Why.** Two copies of one norm drift. The reader then holds a version that no observer checks and no author updates, and the drift is silent, because each copy reads as current. A duplicate also forces the reader to decide which copy governs, and no record answers that.

The field states the prohibition as do not repeat yourself. The half that carries the load is knowledge rather than text, so a second copy of the words is a defect while it states the same knowledge twice, and not otherwise. An inline that names the source of truth states no second knowledge, which is the exception the next part states.

**A fast path is not a second source of truth.** A workflow document may inline a short form of a rule for context efficiency. It stays a fast path while the rule keeps its source of truth and the inline names that source. Remove either and the inline becomes a second source of truth.

**One rule's parts sitting apart is a different defect.** `communication-principle-keep-a-subject-near` owns it, at `$AGENT_HOME/agent/skills/communication-principle-keep-a-subject-near/SKILL.md`.

**A bridge document is a duplicate with extra steps.** A document whose only job is to connect two others duplicates content across a third place. Collapse it into the more relevant of the two and link them directly.

**A definition and its record are two objects.** The document whose workflow produces the thing owns the definition. The record owns its own shape.

**A policy file owns a rule.** The policy set is every `docs/**/*_policy.md` file, in any folder. A file of that name that owns no rule is misnamed: fold its content into its owner, give it the name of its kind, or delete it.

**The test.** Point at the norm's source of truth, and at every carrier that names it. A carrier that states the norm without pointing at its source of truth is a second source of truth, and the next edit reaches one of the two.
