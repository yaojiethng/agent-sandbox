---
name: linking
description: "agent-sandbox's linking convention - the structure a pointer takes in this repository: what each document kind links, where a handoff link belongs, how to form one, and the gate that checks it. The judgement behind it is `communication-principle-link-what-the-reader-can-open`."
---

# linking

This convention holds the structure a pointer takes in this repository. The judgement behind it - link what the reader can open, name what they may not, and resolve the pointer where the text is read - is `communication-principle-link-what-the-reader-can-open`, which ships and is stated nowhere here. Every rule below names the user story it serves.

## What to link

Link a document the reader may need to open; otherwise write its name. Inline code is not a substitute for a link. Story S2.

- **Link a durable target from another durable document.** A documentation or policy document links the ADR that records the fact, and the ADR links the handover that evidences it.
- **Name a target the citing text cannot reach.** Where the citing document ships into the image and the target does not, write the target's repository path in a code span. Story S1.
- **Name a project skill the reader's file cannot load.** A `.agents/skills/<name>/` path is legal from a shipped document only where `initialize` seeds that name, because the seeding is what delivers it; where it does not, the rule is stated in the text the reader holds. Story S1.
- **Name transient evidence.** A handover, a discussion page and a session export are named in a code span and never linked. They are the targets that move, which the principle states as a class.

## Where the link is read

A link resolves where its document is read, not where it was written. A prompt, a skill, a bundled document and an `AGENTS.md` layer are each read at a path the image gives them, so a link from one reaches only a path that ships. A link from a file read in the working tree reaches the repository. Story S1.

`src/build/container-interface.json` declares what ships where, as one row per root: the source folder, the image destination, the provisioning template and the mounts. This skill names no destination, so a row added to the manifest changes the check with no edit here.

## Where the handoff is

Place a handoff link where the handoff happens, and name the section it hands to. A References table is navigation, not a handoff. Story S3.

## How to form one

A step-level reference carries a section anchor. A document-level reference is a plain document link. Where an agent must locate a section programmatically, give the grep command instead of a link. Story S4.

## Citations

A citation is a pointer to the evidence behind a claim, and its target may be inside the repository or outside it. Story S2.

An internal citation follows the rules above: link the handover, the ADR or the record that evidences the claim.

An external citation names a source this repository reads but does not carry: a standard, a paper, a specification. Write the publisher, the title, the version or date, and the URL. The gate skips an external target, which `scripts/lint/linking.mjs` does by design, so the version is the only thing that pins which revision the claim rests on.

What we took from that source and what we dropped is a record rather than a link: `.agents/registry/citations/<id>.json`, whose fields `docs/development/source_tracking.md` `## Citations` states. The citing text names the source, and the record holds the adaptation.

## The stories

| Story | The use case | Served by |
|---|---|---|
| S1 | an agent reads a shipped document in a container and follows a pointer to the rule it needs | where the link is read; name a target the citing text cannot reach |
| S2 | a later reader follows a citation back to its evidence | what to link; name transient evidence; the external form under `## Citations` |
| S3 | a runbook hands work to another prompt, and the reader needs the entry point | where the handoff is |
| S4 | an agent locates a section without a human converting a heading into a fragment | how to form one |

## The check

`scripts/lint/linking.mjs` runs as a custom rule under the Markdown gate, `scripts/check_markdown.sh`, which [`scripts/lint.sh`](../../../scripts/lint.sh) runs. It fails when a relative target or a heading fragment does not resolve, when a shipped file's link reaches only a repository path, when a link lands outside the reach its instruction cell declares, and when a shipped document names a `.agents/skills/<name>/SKILL.md` path for a convention the seeded corpus does not hold. It reads its subject set from the interface manifest and its convention names from the `initialize` corpus, so a new surface joins the check with no edit to it.

The check has no `check_linking.sh` of its own, because the Markdown gate is its entry. A reply's pointers are not in the tree, so the author applies them while writing.

## The cost

One link or one code span per pointer while writing, one gate line at commit.
