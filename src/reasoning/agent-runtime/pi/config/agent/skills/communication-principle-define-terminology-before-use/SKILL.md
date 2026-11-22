---
name: communication-principle-define-terminology-before-use
description: "Apply before the work relies on a word whose meaning the reader has to supply: the word can carry two meanings, it arrives from another field, or the repository states no definition for it."
metadata:
  intent: "To establish the domain model and align shared understanding; to define important terms before the work relies on it."
  mechanism: "Prose structure. The definition is critical reference material that needs to be established before anything else builds on it, in a manner where the reader of the work will always be able to access the definition."
  neighbours:
    - communication-principle-write-for-the-reader
    - communication-principle-link-what-the-reader-can-open
    - communication-principle-order-for-incremental-parsing
    - communication-principle-single-train-of-thought
    - communication-principle-keep-context-in-view
    - communication-principle-maximize-conceptual-leverage
---

# Define terminology before use

Each concept has one term, and each term one concept. State the term where the concept first arrives, and use it from then on.

**The pattern.** It fails two ways, and neither one announces itself.

- **One word, two concepts.** `unit` is the size of text, the work item and the test. Say which one the work means, and give the others their own term: `language unit`, `work unit`, `test unit`.
- **One concept, two words.** `norm` in one section and `rule` in the next. Choose one, define it once, and use it wherever the concept appears.

A term with no concept, and a concept with no term, are the ends of the same problem: cut the first, and find the word for the second.

**A general-use word is qualified by the domain being described.** A word in general use carries the sense of every field that uses it, so on its own it means no one concept: the Diataxis mode, not the mode. Where the word is a value out of a closed set, mark the mention: the "reference" mode, or the mode named reference, never its mode is reference. Which terms this repository reserves, and the qualifier each takes, is `docs/reference/terminology.md`'s.

A definition stated once and pointed at from every use keeps the term attached where a reader meets it. A definition collected at the end of a long document is read after the work that depended on it.

**Why.** An overloaded term reads normally. Nothing in the sentence marks it, so the second meaning arrives without a signal, and two readers proceed on two definitions while the sentence still reads correctly to the writer. The cost arrives later, where the two meanings have already driven different decisions: a task's scope and its acceptance criteria are the same pairing, and two readers who pair them differently have the same fault.

**What it does not cover.** Which terms the repository reserves, which is `docs/reference/terminology.md`'s. A word with one settled meaning, which needs nothing. And which concepts the domain contains, which is a design question the work answers, not a writing rule.

**The family.** This is one of the `context disclosure` principles. It shares the `correct disclosure` term with `write-for-the-reader` and `link-what-the-reader-can-open`, and its remedy is the definition.

**The test.** Ask three questions of the passage. Can you point at each term's definition? Does every use of a term carry that one meaning? Does every mention of a concept carry the same term? A no is where the reader's model diverges from the writer's. Where a word reads for its ordinary sense and the sentence means one specific concept, the word takes its qualifier: a work unit, not a unit, and a mark where the word is a value.
