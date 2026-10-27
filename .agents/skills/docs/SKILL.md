---
name: docs
description: agent-sandbox's docs convention - which folder a document belongs to, how it opens, what it may contain, how it is wrapped and numbered, and which obligations its type carries.
---

# docs

## Folder tree

This project's document tree lives at `docs/`, in four folders, beside the `devlog/` record set.

| Folder | Holds | Ships |
|---|---|---|
| `docs/reference/` | how the harness works: contracts, states and sequences, the glossary | yes |
| `docs/development/` | contributor workflow and the procedures for changing the harness | no |
| `docs/adr/` | settled decisions, with superseded ones under `adr/archive/` | no |
| `devlog/` | the roadmap, the changelog, the handovers and the discussion records | no |

Each document belongs to exactly one folder. What a folder holds and why is [`documentation_taxonomy.md`](../../../docs/reference/documentation_taxonomy.md#folder-taxonomy), which also governs the `devlog/` records and states each type's durability.

An architecture document describes what the layers do, not what a frozen layer has yet to do. The layer model, the freeze status per layer and the freeze rule are [`system_overview.md`](../../../docs/reference/system_overview.md#architecture-layer-model).

## How a document opens

Documents open with a consistent header, so status and scope read without the body and `grep -n "^##"` returns a usable section map.

```text
# <Title>
<blank line>
**Status:** <value>
<blank line>
> **Superseded / Resolved.** <one sentence pointing to the authoritative document.>
```

- `**Status:**` is the first line after the title on every discussion document, with no preamble before it.
- A superseded or resolved document carries the blockquote redirect immediately after its status line, naming the target.
- A reference document carries no status line: the freeze table in `system_overview.md` governs it.
- ADR headers and entry structure are the `decision-records` convention's.
- Top-level sections use `##` and subsections use `###`. Use `####` only inside a long task list where grouping is genuinely needed.
- A `docs/` document declares `reader` among `agent`, `operator` and `maintainer`. A document serving only the maintainer does not ship, so the frontmatter gate fails one under `reference/` or `policies/`.

## What a document may contain

**Plain ASCII.** A dash is a space-separated hyphen (` - `), or a double hyphen (`--`) in prose and never in a heading. Status markers are `[x]` and `[ ]`, never an emoji. Non-ASCII punctuation and formatting symbols are banned, with one exception: box-drawing characters inside an ASCII-art diagram such as a directory tree, where they carry its geometry. Convert banners, table rules and decoration to ASCII hyphens. `scripts/lint/doc-ascii.mjs` decides it.

**One paragraph per physical line, however long.** A soft-wrapping viewer does the breaking, so a hard break inside a paragraph costs every later edit a reflow. Hard breaks separate blocks: paragraphs, headings, list items. The rule covers every prose surface, including guidance blocks and the `AGENTS.md` layers. Code comments wrap at about 80 columns; fenced code and table rows are exempt. `scripts/lint/doc-wrap.mjs` decides it.

**A pointer the reader can open.** What a document links, where a handoff link belongs and how to form one is the `linking` convention's; the judgement behind it is `communication-principle-link-what-the-reader-can-open`. A shipped document's link target must exist in the image, so a pointer into the repository rather than the image is named in a code span instead of linked.

**Numbers where an order matters.** Which unit takes a number, which takes an identity code and how a chat pick reaches a record is the `numbering` convention's; the judgement behind a numbered list is `communication-principle-one-addressing-axis`.

**Reserved terms linked, never redefined.** The reserved technical terms are [`terminology.md`](../../../docs/reference/terminology.md). A policy, concept or architecture document links a reserved term to its section on first mention and does not state a local definition.

## Structure for grep navigation

Every section an agent might need in isolation takes a `##` or `###` header, because an unnamed block is not grep-targetable. A document that must be read whole to extract one fact is structured wrong. A fact needed at one moment of a workflow belongs in a named section or inline at its point of use.

State a document's section order as a fenced Markdown skeleton with each section's purpose on the line below its heading in angle brackets, so the block doubles as a fill-in template. Use a table only when a type carries a column the skeleton cannot, such as a status table's valid transitions.

## Drafting

Pick the folder before the first sentence. Update only the sections a change affects, because a targeted edit beats a rewrite. Add a document only when it serves a structural purpose no existing document covers.

Propose the skeleton of an ADR or a reference document in chat before writing prose: the section list and what each section holds, confirmed by the operator. Full prose written before the structure is agreed has produced full rewrites.

Write for the reader of the artifact, not for the session that produced it; `communication-principle-write-for-the-reader` is that judgement's only source of truth. A design record carries no question-and-reply pair, every question it lists is still open, and the designs considered and rejected sit in one short section with a reason each, after the final design.

**Voice.** Write in the voice the operator heard when the decision was made: active, first person where a person did it, the claim first, one clause of reason. Read each sentence back as speech, and rewrite it if you would not say it to the operator. Address the record to the next agent session, which holds the tree, the conventions and the handover chain and can act as soon as it understands; stop there. Do not match the register of the records around you, which run heavier, and lighten any sentence of a record you are already rewriting. Where the decision was already put to the operator, carry that sentence rather than write a second version of it.

A reference document keeps its code examples current: every code block, variable name, path and function signature matches the implementation as built. A document edited across several sessions collects examples that contradict the system, so an update checks each example against the implementation and corrects the ones that changed.

## What each document type owes

A concept document stands alone and reads complete: a reader new to the area understands the model and what it guarantees without opening another document, and its outbound links are further reading rather than prerequisites. It links its ADR and does not restate the ADR's record.

A concept document restates its requirements as user-observable guarantees, without seam vocabulary: no requirement numbers, no promotion history, no internal component names. The ADR owns the numbering, the design mapping and the history.

A concept document describes components as interfaces, contracts or diagrams. An exact command or variable value appears only for an external interaction the harness does not control, such as a `docker` CLI mapping; internal command sequences, function names and file paths belong in the architecture documents or the ADR.

When an ADR begins, and how one is distilled, is the `decision-records` convention's.
