---
name: project-documentation
description: "Apply when writing or editing project documentation under `docs/`: which folder it belongs to, how it opens, what it may contain, and what its type owes."
---

# project-documentation

## Folder tree

This convention covers the project documentation under `docs/`. The `devlog/` records are the `work-log` convention's, the roadmap and changelog are `task-list`'s, and ADR entry structure is `decision-records`'s.

| Folder | Holds | Ships |
|---|---|---|
| `docs/reference/` | how the harness works: contracts, states and sequences, the glossary | yes |
| `docs/development/` | contributor workflow and the procedures for changing the harness | no |
| `docs/adr/` | settled decisions, with superseded ones under `adr/archive/` | no |

Each document belongs to exactly one folder. Which folder holds what, and each type's durability, is [`documentation_taxonomy.md`](../../../docs/reference/documentation_taxonomy.md#folder-taxonomy).

An architecture document describes what the layers do today. Future work belongs in the task-list. The layer model and the stabilization rule are [`system_overview.md`](../../../docs/reference/system_overview.md#architecture-layer-model).

## How a document opens

A document under `docs/` opens with its title, then a frontmatter block declaring `reader` as `agent`, `operator` or `maintainer`. A document serving only the maintainer does not ship, so the frontmatter gate fails one under `reference/` or `policies/`.

- Top-level sections use `##` and subsections use `###`. Use `####` only inside a long task list where grouping is genuinely needed.
- A reference document carries no status line: the layer table in `system_overview.md` governs it.
- A record's status line, its redirect and ADR entry structure are `work-log`'s and `decision-records`'s.

## What a document may contain

**Plain ASCII.** A dash is a space-separated hyphen (` - `), or a double hyphen (`--`) in prose and never in a heading. Status markers are `[x]` and `[ ]`, never an emoji. Non-ASCII punctuation and formatting symbols are banned, except box-drawing inside an ASCII-art diagram such as a directory tree, where they carry its geometry. Convert banners, table rules and decoration to ASCII hyphens. `scripts/lint/doc-ascii.mjs` decides it.

**One paragraph per physical line, however long.** Hard breaks separate blocks: paragraphs, headings, list items. The rule covers every prose surface, including guidance blocks and the `AGENTS.md` layers. Code comments wrap at about 80 columns; fenced code and table rows are exempt. `scripts/lint/doc-wrap.mjs` decides it.

**A pointer the reader can open.** What a document links, where a handoff link belongs and how to form one is the `linking` convention's; the judgement behind it is `communication-principle-link-what-the-reader-can-open`. A shipped document's link target must exist in the image, so a pointer into the repository rather than the image is named in a code span instead of linked.

**Numbers where an order matters.** Which unit takes a number, which takes an identity code and how a chat pick reaches a record is the `numbering` convention's; the judgement behind a numbered list is `communication-principle-one-addressing-axis`.

**Reserved terms linked, never redefined.** The reserved technical terms are [`terminology.md`](../../../docs/reference/terminology.md). A policy, concept or architecture document links a reserved term to its section on first mention and states no local definition.

## Structure for grep navigation

Give every fact its own `##` or `###` heading, so the section name alone reaches it. A fact needed at one moment of a workflow sits in that named section or inline at its point of use.

State a document's section order as a fenced Markdown skeleton with each section's purpose on the line below its heading in angle brackets. Use a table only when a type carries a column the skeleton cannot, such as a status table's valid transitions.

## Drafting

Pick the folder before the first sentence. Update only the sections a change affects. Add a document only when it serves a structural purpose no existing document covers.

Propose the skeleton of an ADR or a reference document in chat before writing prose: the section list and what each section holds, confirmed by the operator.

A document whose subject exists in the code and nowhere in the document set is greenfield: [`references/greenfield.md`](references/greenfield.md) scopes it against the documents that already exist before any prose is written.

Write for the reader of the artifact, not for the session that produced it. Before a draft lands, read it back against two judgements: a sentence that needs the session, and a sentence the reader could drop without losing an action. `communication-principle-write-for-the-reader` and `communication-principle-cut-what-carries-nothing` state them.

**Voice.** Write in the voice the operator heard when the decision was made: active, first person where a person did it, the claim first, one clause of reason. Read each sentence back as speech, and rewrite it if you would not say it to the operator. Address the record to the next agent session, which holds the tree, the conventions and the handover chain and can act as soon as it understands; stop there. Do not match the register of the records around you, which run heavier, and lighten any sentence of a record you are already rewriting. Where the decision was already put to the operator, carry that sentence rather than write a second version of it.

A code block derives from the file that owns it: the document names that file and lets the reader open it rather than copying its lines into a fence. A block with no owner to point at, such as a diagram, a section skeleton or output quoted from a tool, declares itself with a marker the gate reads. The four patterns, the markers and the gate are [`references/code-snippets.md`](references/code-snippets.md).

## What each document type owes

A concept document stands alone and reads complete: a reader new to the area understands the model and what it guarantees without opening another document, and its outbound links are further reading rather than prerequisites. It links its ADR and does not restate the ADR's record.

A concept document restates its requirements as user-observable guarantees, without seam vocabulary: no requirement numbers, no promotion history, no internal component names. The ADR owns the numbering, the design mapping and the history.

A concept document describes components as interfaces, contracts or diagrams. An exact command or variable value appears only for an external interaction the harness does not control, such as a `docker` CLI mapping; internal command sequences, function names and file paths belong in the architecture documents or the ADR.

When an ADR begins, and how one is distilled, is the `decision-records` convention's.

## Checking

A document that leaves a session is read by the `doc-maintenance` runbook, at [`runbooks/doc-maintenance/SKILL.md`](runbooks/doc-maintenance/SKILL.md). It reports claims the tree contradicts; the gates decide what is mechanical, and this convention decides what a document of each type owes.
