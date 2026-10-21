---
name: communication-principle-link-what-the-reader-can-open
description: "Apply when writing or editing a document, a prompt, a skill, a record, an `AGENTS.md` layer, or a reply that points at another document. A pointer claims a target is reachable where the citing text is read, so link what that reader can open and name what they may not."
---

# Link What the Reader Can Open

A pointer claims a target exists and is reachable from where the citing text is read. Link what the reader can reach; name what they cannot.

**The pattern.** Choose the form by the reader's reach, not the writer's.

| Instead of | Write |
|---|---|
| a link to a path that exists only in the writing repository | the target's name, or the shipped skill that states the rule |
| a link to a handover, a discussion or a session export | its name in a code span, because the target moves and the link does not |
| a link from a shipped document to a project-scoped path | the name of the path, and what the reader does when it is absent |
| a heading fragment the reader must convert by hand | the grep command that finds the section |

**Why.** Two readers take a broken pointer differently. A reader with the repository open finds the file by hand. A reader in a container has no repository to search, so the pointer returns nothing and the work stops. Nothing reports the difference, because the sentence reads normally either way.

**The test.** Name the reader, then name where they read the text. For each pointer, does the target exist there? Where it does not, is the pointer a name rather than a link, and does the sentence say what to do instead?
