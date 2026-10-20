---
name: linking
description: "Apply when writing or editing a document, a prompt, a skill, a record, an `AGENTS.md` layer, or a reply that points at another document. A link claims a target exists and is reachable where the citing text is read: link what the reader may open, name what they may not, and let the gate settle whether the target resolves."
---

# linking

A link claims a target exists and is reachable from where the citing text is read. Link a target the reader may open; name one they may not. Every rule below names the user story it serves.

## Why

Two readers take a broken pointer differently. A reader of the repository can still find the file by hand. An agent reading the same line in a container has no repository to search, so the pointer returns nothing and the agent stops. Nothing reports the difference: the sentence reads normally either way.

A pointer also outlives the reason it was written. A link into a session export, a handover or a discussion names a transient target, so the citation breaks at the point the target leaves the tree.

## What to link

Link a document the reader may need to open; otherwise write its name. Inline code is not a substitute for a link. Story S2.

- **Link a durable target from another durable document.** A documentation or policy document links the ADR that records the fact, and the ADR links the handover that evidences it.
- **Name a target the citing text cannot reach.** Where the citing document ships into the image and the target does not, write the target's repository path in a code span. Story S1.
- **Name transient evidence.** A handover, a discussion page and a session export are named in a code span and never linked, because the target moves and the link does not.

## Where the link is read

A link resolves where its document is read, not where it was written. A prompt, a skill, a bundled document and an `AGENTS.md` layer are each read at a path the image gives them, so a link from one reaches only a path that ships, or a path inside the reach the surface's own cell declares. Story S1.

`src/build/container-interface.json` declares what each surface ships and reaches. This skill names no reachable path, so a change to the manifest changes the check with no edit here.

## Where the handoff is

Place a handoff link where the handoff happens, and name the section it hands to. A References table is navigation, not a handoff. Story S3.

## How to form one

A step-level reference carries a section anchor. A document-level reference is a plain document link. Where an agent must locate a section programmatically, give the grep command instead of a link. Story S4.

## The stories

| Story | The use case | Served by |
|---|---|---|
| S1 | an agent reads a shipped document in a container and follows a pointer to the rule it needs | where the link is read; name a target the citing text cannot reach |
| S2 | a later reader follows a citation back to its evidence | what to link; name transient evidence |
| S3 | a runbook hands work to another prompt, and the reader needs the entry point | where the handoff is |
| S4 | an agent locates a section without a human converting a heading into a fragment | how to form one |

## The check

`scripts/lint/linking.mjs` runs as a custom rule under the Markdown gate, `scripts/check_markdown.sh`, which [`scripts/lint.sh`](../../../scripts/lint.sh) runs. It fails when a relative target or a heading fragment does not resolve, when a shipped file's link reaches only a repository path, and when a link lands outside the reach its instruction cell declares. It reads its subject set from the interface manifest, so a new surface joins the check with no edit to it.

The check has no `check_linking.sh` of its own, because the Markdown gate is its entry. A reply's pointers are not in the tree, so the author applies them while writing.

## The cost

One link or one code span per pointer while writing, one gate line at commit.
