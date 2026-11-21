---
name: communication-principle-link-what-the-reader-can-open
description: "Apply to a pointer: a sentence naming material the reader must reach. It claims the target is reachable where the citing text is read, so link what that reader can open and name what they cannot."
metadata:
  intent: "The text is written with the reader's context in mind; it does not reference context the reader does not have."
  mechanism: "Discipline around links, references and records. Prefer links to files the reader has access to."
  neighbours:
    - communication-principle-define-terminology-before-use
    - communication-principle-write-for-the-reader
    - communication-principle-order-for-incremental-parsing
    - communication-principle-single-train-of-thought
    - communication-principle-keep-a-subject-near
---

# Link what the reader can open

A pointer claims a target exists and is reachable from where the citing text is read. Link what the reader can reach; name what they cannot.

**The pattern.** Choose the form by the reader's reach, not the writer's.

| Instead of | Write |
|---|---|
| a link to a path only the writing tree holds | the target's name, or the shipped skill that states the rule |
| a link to a target that moves | its name in a code span |
| a pointer the reader's copy cannot reach | the name, and what the reader does when the target is absent |
| a heading fragment the reader must convert by hand | the grep command that finds the section |

**The pointer's text.** Link with words that say where the link goes: the page title or a short description. Never "click here". Prefer a sentence of context on the page over a link off it.

Which of a project's documents fall in each class, and where a handoff link belongs, belongs to that project's reference convention, where the project states one.

**Why.** Two readers take a broken pointer differently. A reader with the repository open finds the file by hand. A reader in a container has no repository to search, so the pointer returns nothing and the work stops. Nothing reports the difference, because the sentence reads normally either way.

**Fires on.** A pointer, and the one question it settles: whether the reader's copy holds the target.

**What it does not cover.** Whether the reader needs the target or the material itself: [`communication-principle-write-for-the-reader`](../communication-principle-write-for-the-reader/SKILL.md). Where a project files each kind of document: that project's reference convention.

**The family.** This is one of the `context disclosure` principles. It shares the `correct disclosure` term with `define-terminology-before-use` and `write-for-the-reader`, and its remedy is the pointer's target.

**The test.** Name the reader, then name where they read the text. For each pointer, does the target exist there? Where it does not, is the pointer a name rather than a link, and does the sentence say what to do instead?
