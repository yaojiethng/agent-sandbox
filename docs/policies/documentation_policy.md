---
description: "Owns the documentation rules: rule authority, folder placement, the document header and format rules, the concept-document and ADR obligations, and the lint gate over `docs/`."
scope: ["docs/", "devlog/"]
reader: [agent]
---

# Documentation Policy

Skill files and prompt templates are not documentation. They hold the rules their own procedure runs, and they point at the home of every rule they borrow, per [`agent_workflow.md`](../reference/agent_workflow.md#how-the-workflow-is-expressed).

The document taxonomy, meaning the document types, their durability, and the policy or ADR that governs each, is the concept document [`documentation_taxonomy.md`](../reference/documentation_taxonomy.md). Compliance checklists live in the `doc-maintenance` skill at `workflow/coding-agent/skills/doc-maintenance/SKILL.md`.

## Rule authority

The kinds of norm and the home each has are defined once in [`agent_workflow.md`](../reference/agent_workflow.md#norm-kinds). This section applies them to this file.

`scripts/lint/norm-ownership.tsv` records the kind, observer and home of every prose line in this file and in `docs/development/prompt-authoring-conventions.md`. `scripts/check_norm_ownership.sh` holds the ledger against both files in both directions, so a new line arrives unclassified and an edited sentence loses its kind. The script derives a home from the skill path the line cites and rejects a hand-edited one.

A norm's home, and what makes a second copy a defect, is `principle-one-home-per-rule` at `$AGENT_HOME/agent/skills/principle-one-home-per-rule/SKILL.md`.

## Folder Structure

Each `docs/` document belongs to exactly one folder: `reference/`, `policies/`, `development/`, or `adr/`. What each folder holds and why is in [`documentation_taxonomy.md`](../reference/documentation_taxonomy.md#folder-taxonomy). Superseded or awaiting-review ADRs live in `adr/archive/`.

Records outside `docs/` live in `devlog/`: the roadmap, the changelog, handovers, and discussion documents. [`documentation_taxonomy.md`](../reference/documentation_taxonomy.md) governs their placement.

An architecture document must not describe what a frozen layer does not yet do. The layer model, the freeze status per layer, and the freeze rule are in [`system_overview.md`](../reference/system_overview.md#architecture-layer-model), and this policy applies them to drafting.

## Communication Standards

### Rule placement

Put a rule where the reader meets it. A rule that governs Step 6 of the iteration belongs in the Step 6 entry of the workflow table, not in a separate document.

A workflow table Action cell holds one imperative sentence and a link to the governing section, so detail defers to the child document. Negative cases that mark a rule's limit stay in the cell, and illustrative examples belong in the child document.

### Simplified Technical English

New and changed prose meets ASD-STE100, with one exception. Where the work belongs to a well-specified technical domain and the reader works in that domain, its terms are the precise words, so use them and use no other field's. A word that names a thing in the domain is its term, and no list of banned words overrides it. A term the reader may not hold is defined at first use, per `principle-define-terminology-before-use` at `$AGENT_HOME/agent/skills/principle-define-terminology-before-use/SKILL.md`.

Phrasing rules, a working subset of the full dictionary rather than a replacement for it:

- Sentence structure. Active voice with a named actor, and a main clause that does not depend on its afterthought. Judgement: `communication-principle-attach-as-you-read`.
- Short sentences. Aim under 20 words, one idea per sentence.
- One term, one meaning. Pick one word for a thing and keep it. Rotating synonyms ("volume" / "sandbox" / "workspace" for one object) is a defect.
- Common verbs. Prefer is, has, uses, copies, reads, writes, runs, starts, stops, shows, checks, rejects. Avoid ornate verbs ("leverages", "facilitates", "encompasses").
- No idioms, no metaphors, no hedging ("somewhat", "fairly", "arguably"). The hedging rule governs what you checked, not what you cannot check, so a claim about an unobservable state is not hedging when the sentence marks it as an inference.
- STE100 simplifies structure and verbs, not precision.
- State the allowed form and name the action. Judgement: `communication-principle-write-for-the-reader`.

The judgements named above are skills under `$AGENT_HOME/agent/skills/`. Evaluate prose with two tests:

- **Delete test.** Judgement: `communication-principle-cut-what-carries-nothing`.
- **Literal-reader test.** A literal reader follows the words exactly and infers no intent. Could the reader turn the sentence into a task, an action, or an inference that was not intended? If yes, rephrase it with the phrasing rules.

### Reserved terminology

Reserved technical terms are defined in [`terminology.md`](../reference/terminology.md). When a policy, concept, or architecture document uses a reserved term in its technical sense, link to its section on first mention. Do not redefine it locally.

## Format

### Document header format

Documents in `docs/` open with a consistent header block, so status and scope are visible without reading the body and `grep -n "^##"` returns a usable section map.

```text
# <Title>
<blank line>
**Status:** <value>         (discussion documents only)
**Location:** <path>        (only if the file has been moved or renamed)
<blank line>
> **Superseded / Resolved.** <one sentence pointing to the authoritative document.>
```

Rules:

- `**Status:**` is the first line after the title on every discussion document (story, study, design, report), with no preamble before it.
- A superseded or resolved document carries a blockquote redirect immediately after the status line, naming the target document.
- Reference and policy documents carry no status line, because the layer-freeze table in `system_overview.md` governs them.
- ADR headers and entry structure are defined in [`adr_policy.md`](adr_policy.md).
- Top-level sections use `##` and subsections use `###`. Use `####` only inside a long task list where grouping is genuinely needed.
- Policy files (`docs/**/*_policy.md`) open with YAML frontmatter holding a `description` and a `scope`, then a blank line, then the title. `description` is one quoted line naming the rules the file owns, and `scope` is a single-line flow list of the records and runbooks it governs.
- `reader` names who must read the document to do their job: one or more of `agent`, `operator` and `maintainer`. A document serving only the maintainer does not ship, so the frontmatter gate fails one that sits in `docs/reference/` or `docs/policies/`.

### Character set

Documents use plain ASCII punctuation.

- Write a dash as a space-separated hyphen (` - `), or as a double hyphen (`--`) in prose. In headings use the space-separated form.
- Write status markers as `[x]` / `[ ]` in tables or `- [x]` / `- [ ]` in lists. Do not use checkmark or cross emoji.
- Do not use non-ASCII punctuation (section sign U+00A7, pilcrow U+00B6) or control and formatting symbols (space glyphs, chapter symbols).
- Box-drawing characters (U+2502 vertical, U+251C left tee, U+2514 corner, U+2500 horizontal) may appear inside an ASCII-art diagram such as a directory tree, where they carry the diagram's geometry. Use them nowhere else; convert banners, table rules and decoration to ASCII hyphens.

### Line wrapping

Prose is one paragraph per physical line, however long the line. Never break inside a paragraph, not at a sentence boundary and not at a column limit, because editors and viewers soft-wrap. Hard breaks separate blocks only: paragraphs, headings, list items. The rule covers all prose, including guidance blocks, `AGENTS.md` and provider-layer files. Code comments wrap at about 80 columns. Fenced code blocks and table rows are exempt.

### Reference handling

The judgement behind a pointer is `communication-principle-link-what-the-reader-can-open` at `$AGENT_HOME/agent/skills/communication-principle-link-what-the-reader-can-open/SKILL.md`: link what the reader can open, name what they cannot, and resolve the pointer where the text is read. The structure - what a document kind links, where a handoff link belongs, and how to form one - belongs to the project's reference convention, where the project states one.

### Numbering

The numbering scheme - which unit takes a number, which takes an identity code, the form of a reference, the chat label, and how a chat pick reaches a record - is stated once, in the project's numbering convention, where the project states one. The judgement behind a numbered list is `communication-principle-one-addressing-axis` at `$AGENT_HOME/agent/skills/communication-principle-one-addressing-axis/SKILL.md`, which also carries the rule that a heavily cited item moves to a heading.

### Structure for grep navigation

Structure documents so an agent can grep section headers and range-read only what it needs. Every section an agent might need in isolation has a `##` or `###` header, because an unnamed block is not grep-targetable; a document that must be read in full to extract one fact is structured wrong. A fact needed at a specific moment in a workflow belongs in a named section, or inline at the point of use.

### Section-order templates

When a policy or convention states a document's section order, present it as a fenced Markdown skeleton, with each section's purpose on the line below its heading in angle brackets, so the block doubles as a fill-in template:

```markdown
# <Title>
**Status:** <draft | active | settled | superseded>

## Context
<what this section holds; 2-4 sentences>

## Decision
<the recommended approach and why>
```

Order and purpose then read together, and the block is copied directly into a new document. Use a table only when a type carries a column the skeleton cannot, such as the valid state transitions of a status table.

## Drafting

### Folder placement

Pick the folder category before drafting. Update only the sections the change affects, because targeted edits beat rewrites. Add a document only when it serves a structural purpose no existing document covers.

### Skeleton first for record-layer documents

Before writing an ADR or a reference document, propose the skeleton in chat, meaning the section list and what each section holds, and get operator confirmation. Write prose only against the confirmed skeleton, because drafting full prose before the structure is agreed has produced full rewrites.

### Subject, not the session

The judgement for a durable record is `communication-principle-write-for-the-reader` at `$AGENT_HOME/agent/skills/communication-principle-write-for-the-reader/SKILL.md`, which is the judgement's only home. The concept document [`documentation_taxonomy.md`](../reference/documentation_taxonomy.md) classifies what endures.

A design record carries no question-and-reply pair, and every question it lists is still open. Keep a short section of the designs considered and rejected, with the reason for each, and put the final design at the forefront.

## Prohibited content

### No speculative language or TODO content in `reference/`

A reference document describes its layer as built, so a sentence that forecasts or a TODO item is prohibited. The words `will` `plan` `future` `later` `eventually` and `may support` usually mark a forecast. Judgement: `communication-principle-dont-forecast-undone-work` at `$AGENT_HOME/agent/skills/communication-principle-dont-forecast-undone-work/SKILL.md`.

### Stale code examples

Reference documents keep their code examples current. Every code block, variable name, path and function signature matches the implementation as built. A document updated across several sessions collects examples that contradict the system, so when you update one, check each example against the implementation and update the ones that changed.

## Tooling checks

This section holds the document lint rules and the gate that enforces them. Code lint is not documentation policy.

### Markdown lint gate

The repository holds zero Markdown lint findings. The gate runs `markdownlint-cli2` with the repository config `.markdownlint-cli2.mjs`, and a finding is a defect to fix in the same change. Run it with `make lint` or `bash scripts/lint.sh`.

### The lint rule set

The config enables the rules that match this policy. It disables `MD013` because [`### Line wrapping`](#line-wrapping) forbids breaking prose at a column limit, and `MD060` because the repository writes compact tables. Three repository rules enforce parts of this policy: `doc-ascii` (plain-ASCII prose, in `scripts/lint/doc-ascii.mjs`, per [`### Character set`](#character-set)), `doc-wrap` (one paragraph per physical line, in `scripts/lint/doc-wrap.mjs`, per [`### Line wrapping`](#line-wrapping)), and `linking` (link targets exist and fragments name a heading, in `scripts/lint/linking.mjs`, per [`### Reference handling`](#reference-handling)). Do not silence a finding with a per-file disable; fix the text or change the config.

A rule the config registers but does not enable is a defect. `config.default` is `false`, so a rule named nowhere in the config never runs and reports nothing, and the gate prints a clean verdict over an empty rule set. Naming a rule here and enabling it there are one obligation.

## Document Types

This section holds the obligations that apply per document type. It describes no genre.

### Concept document obligations

A concept document is standalone and content-complete: a reader new to the area understands the model and what it guarantees without another document, and outbound links are for further reading rather than prerequisites. It links to its ADR and does not restate the ADR's record.

#### Requirements as behavioral contracts

Restate requirements as user-observable guarantees, without seam vocabulary such as requirement numbers, promotion history, or internal component names. The ADR owns the numbering, the design mapping and the history, and the concept doc owns the readable form.

#### Interface-level descriptions

Describe components as interfaces, contracts, or diagrams. Exact commands and variable values appear only for external interactions the harness does not control, such as `docker` CLI mappings. Internal command sequences, function names, and file paths belong in the architecture docs or the ADR.

### ADR obligations

When and how to create or distill an ADR is in [`adr_policy.md`](adr_policy.md) -- When an ADR begins.

## Record maintenance

### Post-close document corrections

**Principle.** A closed record's content does not change. Whether a record is durable or transient is classified in [`documentation_taxonomy.md`](../reference/documentation_taxonomy.md#durability), which also says what marker its type carries. The form follows what the record is for: a record that states what is true is corrected in place, and a record that tracks open and closed tasks is corrected by addition, with a successor entry.

**Direction.** A closed record is corrected at the operator's direction. The agent may notice a correction and propose it in one line, and may not apply one unasked. The agent never deletes a record, because deletion is an operator action. Two stops and one smell bound the work:

- **Stop -- the correction changes the unit's scope or carries new work.** New work belongs in a new iteration.
- **Stop -- an edit to a closed record would carry no marker.** An untraceable edit is a rewrite, not a correction.
- **Smell -- folding the correction needs an interactive rebase with several conflict edits.** Report the smell and stop, because past that size the instrument is a port and the git policy names the operation.

**Propagation.** A correction inherits the record set of the unit it corrects. A unit that changed code, a task description and a handover is corrected in all three, and every closed record among them takes its marker. A correction that leaves a closed record contradicting its successor is incomplete.

**Archival is not amendment.** Moving a closed milestone's entries from the roadmap to the changelog is a length boundary, not a correction, and carries no marker.

| Document type | Nature | Form | See |
|---|---|---|---|
| Handover | states what the iteration did | rewrite the paragraph, or reopen the record and close it again; either way a `[CORRECTION -- YYYY-MM-DD: <...>]` tag at the end of the corrected section | the `record-correction` procedure |
| Roadmap entry | tracks open and closed tasks | keep the entry, add the superseded marker, add the successor entry | the project's `task-list` convention |
| Changelog entry | tracks closed tasks, archived | as a roadmap entry | the project's `task-list` convention |
| Discussion record (story, study, design, report) | states reasoning and evidence | rewrite, tag | this section |
| ADR, concept, architecture, policy | states what the system does | rewrite, tag | this section |

### Missing documents

If a document the agent expects is absent, read its referencing link. A `[REMOVED]` marker there makes the absence expected, with no error. With no marker, flag an error and ask the operator, because the document is not assumed optional and the work does not proceed unresolved.
