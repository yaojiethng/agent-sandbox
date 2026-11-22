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
---

# Define terminology before use

A term that can carry two meanings here is defined before the work relies on it.

**The pattern.** A term needs defining in two situations. It carries a settled meaning in another field, so a reader who knows that field imports that meaning. Or no definition exists here, so each reader supplies one.

Name the meaning the work uses, in the clause where the term arrives, and name where the definition lives. Then proceed on that definition rather than on the word.

Where one word names two things, name both. Is the account the Customer or the User. One name carrying two meanings is the defect, and two names is the repair.

**A general-use word is qualified by the domain being described.** A word in general use carries the sense of every field that uses it, so on its own it means no one thing: a work unit, not a unit; the Diataxis mode, not the mode. Where the word is a value out of a closed set, mark the mention: the "reference" mode, or the mode named reference, never its mode is reference. Which terms this repository reserves, and the qualifier each takes, is `docs/reference/terminology.md`'s.

A definition stated once and pointed at from every use keeps the term attached where a reader meets it. A definition collected at the end of a long document is read after the work that depended on it.

**Why.** An overloaded term reads normally. Nothing in the sentence marks it, so the second meaning arrives without a signal, and two readers proceed on two definitions. The cost arrives later, where the two meanings have already driven different decisions.

**What it does not cover.** What to call a thing, which is naming rather than definition. A word with one settled meaning, which needs nothing. And which things the domain contains, which is a design question the work answers, not a writing rule.

**The family.** This is one of the `context disclosure` principles. It shares the `correct disclosure` term with `write-for-the-reader` and `link-what-the-reader-can-open`, and its remedy is the definition.

**The test.** Point at the definition of each term the sentence relies on. A definition in the reader's head, or one inherited from a neighbouring field, is not one here. Where a term names two things, count the names: one name with two meanings is two terms waiting to be split. Where a word reads for its ordinary sense and the sentence means one specific thing, the word needs its qualifier, and a mark where the word is a value.
