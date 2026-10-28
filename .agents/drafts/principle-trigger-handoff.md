---
description: "Handoff - the two prose principles that govern a document being written do not fire when it is written: their descriptions trigger on a property of finished text, so they can only fire on a revision pass, and no authoring path requires one. Measured on a reference written 2026-10-28 that came out 33 lines where an existing page said the same thing in 14, the excess all framing."
argument-hint: "[scope - trigger shape, authoring path, or both - optional]"
---

> $ARGUMENTS

# Handoff - the prose principles do not fire at authoring time

## What the next session is for

Patch the footgun that let a reference document be written with narration in it, while the skill that forbids exactly that sat named in the file being edited. The operator hit it while expecting nothing of the kind, which is the point: it fires on ordinary document work, not on review work.

## What was measured

The three candidate triggers, quoted from their frontmatter:

- `communication-principle-write-for-the-reader`: "Apply when a sentence needs your session or an earlier draft to make sense".
- `communication-principle-cut-what-carries-nothing`: "Apply to sediment: a sentence no reader's action depends on".
- `writing-for-agents`: "Use when creating or editing skills, or modifying AGENTS.md or CLAUDE.md".

The first two name a property the text has only once it exists, so selection can only happen on a second pass over finished text. The third names an act, but a different artifact class than a reference page under a convention. The situation at the time was "write a reference document", and no description matched it.

Pointers were not missing. `project-documentation/SKILL.md` names `communication-principle-write-for-the-reader` by handle, and `AGENTS.md` carries the judgement as a one-line standard. Both were in context. A standard and a jurisdiction are not triggers.

The result: a reference of 33 lines against a page that already covered the same five steps in 14, with no rule the shorter page lacked. The whole difference was framing, an opener explaining what the convention had lacked, a heading per step, and a closing section. The comparison is now in the tree: `greenfield.md` and the duplicate beside it.

## The intent

A session that writes prose loads the principles governing prose without being told which, and reads its own text back before the file lands. How that is arranged is the next session's to decide; what must be true is that the trigger fires on the act of writing rather than on a property of what was written.

## Constraints the patch has to respect

- The trigger surface is the `description`; a rule restated in a document is a jurisdiction, not a trigger.
- An authoring path states the standards it applies as a step, at the point the text exists, not as a sentence naming who owns them.
- A new routing artifact earns its place only if it has a caller; two bridges were retired on that test on 2026-10-28.
- The class is judgement, so no gate decides it. A gate may only hold what is mechanical.

## What shows it is patched

A session writing a document opens the governing principles without being named, and the text it produces carries no sentence whose subject is the document, the session, or the edit. The observable is the tool record plus a reading; a case can be built over the pair in the tree, since one of the two files is right and one is not.

## Not in scope

Rewriting the corpus, adding a gate, and rewriting the duplicate itself: `greenfield.md` is the artifact, and the duplicate is not committed.
