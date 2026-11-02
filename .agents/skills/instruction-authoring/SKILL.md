---
name: instruction-authoring
description: "Classifies each sentence of an instruction by its modality - rule, fact, judgement, permission or claim - and states what each kind owes a reader who must act on it. Use when writing or reviewing a prompt, a skill or any instruction. The mechanics of writing a skill are the `skill-scaffolder` skill's until they migrate here."
---

# instruction-authoring

A home being built. Its first subject is the modality of a sentence: what force the sentence carries, and what happens to a reader who finds it broken. The mechanics of writing a skill - its frontmatter, its carrier roots, its siblings - are [`../skill-scaffolder/SKILL.md`](../skill-scaffolder/SKILL.md)'s.

## What lives where

| Subject | Home |
|---|---|
| what `rule`, `fact`, `judgement`, `permission` and `claim` are | the glossary, `docs/reference/terminology.md` `## modality` |
| how a sentence is classified, what each kind owes a writer, and the smell tests | this file |
| how a skill is written, and where it lands | the `skill-scaffolder` skill |

The decision behind the five kinds, and why the classification is not a gate, is `docs/adr/instruction_modality.md`; what follows states the consequence for a writer.

## Classify before you draft

Two questions, in order.

1. **What does the sentence appeal to?** An obligation the reader owes, or a state of the world the reader must accept. Deontic, or epistemic.
2. **How strong is that appeal?** Necessity, which holds without exception. Graded, which a criterion settles. Or possibility, which allows and does not require.

The five answers are `rule`, `fact`, `judgement`, `permission` and `claim`: one space, two bases and three strengths. RFC 2119 names the strengths as MUST, SHOULD and MAY, and a sentence that uses one of those words while meaning another is the commonest defect in this file's subject.

## What each kind owes

1. **A rule names its observer.** State the artifact that fails when the sentence is broken: a gate, a test, a lint. A rule that names none is a judgement that has not admitted it.
2. **A fact carries its evidence, or says it is an inference.** A number, a count, a state description without either is a claim wearing a fact's clothes, and it is the failure nobody reports.
3. **A judgement states the criteria a reader applies, and a test on their own work.** A judgement with no criteria is a taste, and it cannot be applied twice the same way.
4. **A permission names what grants it.** A permission is the weakest force and the easiest to overstate, because a reader told they may do a thing will do it. State the mechanism that allows it, such as a flag, a config key or an override. Where nothing grants it, the sentence is a suggestion, which is advice and not an instruction, and saying so is what stops a reader treating it as a grant.
5. **A claim says that it is unevidenced.** It is allowed to exist; it is not allowed to pass as a fact. An inference marked as one is honest, and an unmarked inference is the defect.

## Why this cannot be a gate

The taxonomy is a standard, not a rule, and that is a property of the object rather than a shortcoming of our tooling. Classifying a sentence needs the base it appeals to and the standard it is ranked against, and both are context the sentence does not carry. A gate reading the sentence alone would guess, and its guess would read as a verdict.

What that means in practice: there is no ledger, no count, and no gate on this. There are the five obligations above and the smell tests below, applied by a reader.

## The smell tests

- An imperative with no observer is a judgement in a rule's voice.
- A number with no source is a claim in a fact's voice.
- A judgement whose two readers disagree is missing its criteria, not its rigour.
- A MAY whose granter is unnamed is a suggestion wearing a permission's clothes.
- A sentence whose removal changes nobody's action is no kind at all; delete it.
- A MUST and a SHOULD governing one situation is one requirement written twice, with two forces.
