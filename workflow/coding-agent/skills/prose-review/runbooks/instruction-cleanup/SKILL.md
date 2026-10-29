---
name: instruction-cleanup
description: Review an instruction surface and propose the cleaned one. Use when a set of prompts, skills, audits or policy clauses has grown by accretion and someone needs one prompt per use case, with an audit of how it got that way.
disable-model-invocation: true
---

# instruction-cleanup

A review of instructions written by accretion. An iteration added a prompt, a skill, a policy clause, and nothing retired what it superseded; the same rule now lives in several files, in different words, sometimes with opposite requirements, and some of those rules make a reader behave worse than no rule would. Because the files are grouped by history rather than by purpose, no reader can tell which file owns which rule.

## The standard

A unit of instruction is kept, replaced, moved or removed by one judgement: it harms the reader, it states what another file already owns, it contradicts a rule the same surface relies on, or the reader it addresses cannot act on it.

One prompt per use case is the target. A rule already owned by a convention, a skill or a reference dies by citation and is not restated more briefly. What is left runs without reading the files it replaced, and takes another rule on the same subject without restructuring.

The agent proposes and the operator decides; no rule is removed that the operator has not seen. The operator's wording is authoritative for the operator's own instructions and for the ones the operator and the agent aligned on: it may be restructured, and what it requires may not be re-worded. Text the surface imported from elsewhere is the surface's to rewrite.

The judgement is unmeasured. A fault list is a sample of a surface rather than an enumeration of it, so the review reports what it found and claims nothing about what it did not.

## Scope accepted

A set is a list of named paths, and it resolves to those paths as they stand. A set holding no instruction is a refused dispatch rather than an empty review, because the review would judge nothing.

The caller may hand over the rulings already taken on part of the set. A ruling is evidence and not a substitute for reading: the review still judges the set, and does not re-open a candidate the caller has settled.

## Returns

Three parts, and a return missing any of them is not yet a review.

**The cleaned surface.** Per file, the rules kept, each replacement or removal at the site it sits at, and the files the set loses. The caller applies it: this file is a review, and changes nothing it judges.

**The ruling log.** One line per candidate, carrying where the instruction came from, the ruling, and what would refine it. A ruling one document supports reads differently from one the whole set supports, and the log says which.

**The open list.** What the review could not settle, or settled on thin evidence, as work rather than as an opinion. A refinement names the condition that would settle it; a wish to improve does not.

What the cleaned surface reads like is judged by `writing-for-agents`, `write-for-the-reader` and `rewrite-syntax-never-semantics`.
