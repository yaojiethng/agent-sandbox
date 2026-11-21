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
    - communication-principle-keep-a-subject-near
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

**Where another rule wins.** Use the passive voice when the actor is unknown or the object is the topic. A verbatim quote keeps its wording. Put the condition before the instruction, so the reader skips what does not apply; that form is [`communication-principle-structure-instructions-imperatively`](../communication-principle-structure-instructions-imperatively/SKILL.md)'s. A reference to context outside the text - a session label, an earlier version - is [`communication-principle-write-for-the-reader`](../communication-principle-write-for-the-reader/SKILL.md)'s; a subject's parts apart across a document is [`communication-principle-keep-a-subject-near`](../communication-principle-keep-a-subject-near/SKILL.md)'s; a term that needs a definition is [`communication-principle-define-terminology-before-use`](../communication-principle-define-terminology-before-use/SKILL.md)'s to settle first, then place it here.

**The test.** Read the sentence left to right, and ask at each phrase whether it can attach to the structure already built. Rewrite the sentence if it forces the reader to:

- hold an unattached phrase,
- supply a missing element,
- reanalyse.

Source: ASD-STE100 Issue 9, Section 3 Rule 3.6, for the actor; The Global English Style Guide for the modifier, noun string, pronoun and gapped verb; Frazier and Fodor (1978) for incremental parsing; Gibson (1998) for working memory; Ferreira et al. (2002) for good-enough processing. The style-guide records are `.agents/registry/citations/asd-ste100.json` and `.agents/registry/citations/global-english.json`.
