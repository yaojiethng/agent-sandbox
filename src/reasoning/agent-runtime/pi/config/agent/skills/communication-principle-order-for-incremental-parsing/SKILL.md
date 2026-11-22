---
name: communication-principle-order-for-incremental-parsing
description: "Apply when writing or revising a sentence: order clauses for incremental parsing, so the reader can attach each new phrase to the structure already built."
metadata:
  intent: "Establish a context disclosure rule that ensures the reader can always build on existing context to incorporate new information."
  mechanism: "Order clauses for incremental parsing: each phrase must attach to existing structure, never force reanalysis."
  leitwort: incrementality
  neighbours:
    - communication-principle-define-terminology-before-use
    - communication-principle-write-for-the-reader
    - communication-principle-link-what-the-reader-can-open
    - communication-principle-single-train-of-thought
    - communication-principle-keep-context-in-view
    - communication-principle-structure-instructions-imperatively
---

# Order clauses for incremental parsing

Order clauses so the reader can attach each new phrase to the structure already built. A reader parses incrementally, building a syntactic structure left to right; each phrase attaches to what is there. A sentence fails when it forces the reader to hold an unattached phrase, supply a missing element, or reanalyse.

**The pattern.** Put the structure before the phrase that needs it.

**Prevent working-memory holds.** When a phrase arrives before its host:

- Name the actor first: put the actor in the subject slot instead of hiding it in the passive voice.
- Name the object first: introduce the object before the imperative.
- Keep the main clause whole: put the modifier or long condition after it.
- Unpack the noun string: "the proto import budget check script" becomes "the script that checks the proto-import budget".

**Prevent missing elements.** When the parse has nothing to attach to:

- Bind every pronoun: every "it", "they" and "this" points to one explicit noun; repeat the noun when in doubt, and never point "this" or "which" at a whole clause.
- Keep gapped verbs: supply the verb in a parallel clause, so "Phase 1 moves the converters and Phase 2 moves the runtime" has one in each.

**Prevent reanalysis.** When an early parse must be discarded:

- Commit to one reading early: structure the opening words so the initial parse holds through the end of the sentence.
- Pin scope modifiers: keep "only" and "not" directly next to the word they modify; "only fails on growth" and "fails only on growth" say different things.

**Why.** When a phrase cannot attach, the text carries high extraneous load: the reader spends working memory on the form rather than the meaning, re-parsing what did not attach and choosing between readings. Reducing the load buys a first-pass attachment, so the memory goes to the instruction and the reading arrives once rather than twice. Good-enough processing makes the failure silent: the reader settles on the plausible reading, so a misread arrives as a wrong instruction rather than a stumble.

**Where another rule wins.** This rule governs how each phrase attaches to the structure already built, within a sentence; the text's structure is another rule's. It yields to a valid exception: the passive voice when the actor is unknown or the object is the topic, and a verbatim quote.

- **A condition before an instruction:** `structure-instructions-imperatively` lets the reader skip what does not apply.
- **A part away from what it needs, across the text:** `keep-context-in-view` places the caveat, the state reminder and the split part beside the rule or step.
- **A missing definition:** `define-terminology-before-use` settles it first.
- **Context outside the text:** `write-for-the-reader` names the referent.

**The test.** Read the sentence left to right, and ask at each phrase whether it can attach to the structure already built. Rewrite the sentence if it forces the reader to:

- hold an unattached phrase,
- supply a missing element,
- reanalyse.

Source: ASD-STE100 Issue 9, Section 3 Rule 3.6, for the actor; The Global English Style Guide for the modifier, noun string, pronoun and gapped verb; Frazier and Fodor (1978) for incremental parsing; Gibson (1998) for working memory; Ferreira et al. (2002) for good-enough processing. The style-guide records are `.agents/registry/citations/asd-ste100.json` and `.agents/registry/citations/global-english.json`.
