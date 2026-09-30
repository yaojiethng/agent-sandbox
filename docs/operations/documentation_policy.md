# Documentation Policy

Documentation describes the **current system reality**. It must stay concise, readable, and specific to its purpose. Future work belongs in `roadmap.md`.

Skill files and prompt templates are not documentation. They reference or inline rules from policy documents. See [`agent_workflow.md`](../concepts/agent_workflow.md#how-the-workflow-is-expressed) for those rules.

The document taxonomy -- what document types exist, their durability, and which policy or ADR governs each -- is the concept document [`documentation_taxonomy.md`](../concepts/documentation_taxonomy.md). Diagnostic checklists for compliance live in [`workflow/coding-agent/audits/documentation-pass.md`](../../workflow/coding-agent/audits/documentation-pass.md).

---

## Folder Structure

Each document belongs to **exactly one** of the following categories:

| Folder | Purpose |
|---|---|
| `architecture/` | Implementation design and decisions |
| `concepts/` | The conceptual models the system runs on: abstract state transitions, multi-component interactions, principles of interaction. The *what* at the conceptual level. |
| `operations/` | How to run the system |
| `development/` | Contributor workflow and development conventions |
| `adr/` | The rationale (the *why*) behind standing principles, interface shapes, and contracts. Superseded or awaiting-review ADRs live in `adr/archive/`. |

Architecture documents must not describe things a frozen layer does not yet do. The layer model, the per-layer freeze status, and the freeze rule live in [`system_overview.md`](../architecture/system_overview.md#architecture-layer-model); `documentation_policy.md` applies them to document drafting.

---

## Enforcement Rules

### No future language in `architecture/`

Do not use these words in architecture documents; they indicate speculative design:

`will` `plan` `future` `later` `eventually` `may support`

Move such content to `roadmap.md`.

### No TODOs in `architecture/`

Prohibited content:

```text
TODO: add sandbox enforcement
TODO: implement agent queue
```

Move TODO items to `roadmap.md`, which is the only task list. Architecture documents must stay stable and authoritative.

### PR gate

Every pull request answers: **"Does this change system behaviour?"**

- **Yes** -- update the relevant architecture document before merging.
- **No** -- no documentation changes required.

This question appears in the pull request template as a required checkbox.

### Record invariant shifts as they happen

Record a change to an invariant, interface, or contract when you make it. If the record waits for iteration close, a stale document governs the work in the meantime.

### Code example propagation

When you update an architecture or concepts document, check every code block, variable name, path, and function signature against the current implementation. A document updated across several sessions collects stale examples that contradict the system as built.

Before closing a session that touched such a document, update or remove every stale example.

### Markdown lint gate

The repository holds zero Markdown lint findings. The Markdown gate runs `markdownlint-cli2` with the repository config [`.markdownlint-cli2.mjs`](../../.markdownlint-cli2.mjs) and the custom rules `doc-ascii` (plain-ASCII prose, in [`scripts/lint/doc-ascii.mjs`](../../scripts/lint/doc-ascii.mjs)) and `doc-wrap` (one paragraph per physical line, in [`scripts/lint/doc-wrap.mjs`](../../scripts/lint/doc-wrap.mjs)). The `doc-wrap` rule is live (M3.1 roadmap, iteration `20260921-11`) and carries a config-driven `legacyFiles` exemption seam for any carve-out. A finding is a defect: fix it in the same change.

`make lint` runs [`scripts/lint.sh`](../../scripts/lint.sh), which runs the ShellCheck gate in [`scripts/check_shell.sh`](../../scripts/check_shell.sh) and the Markdown gate in [`scripts/check_markdown.sh`](../../scripts/check_markdown.sh). Run `make lint` before an iteration closes. When `make` is not available, run `bash scripts/lint.sh` for both gates.

The config enables the rules that match this policy. It disables `MD013` because `### Line wrapping` forbids breaking prose at a column limit, and `MD060` because the repository writes compact tables. Do not silence a finding with a per-file disable; fix the text or change the config.

---

## Communication Standards

### Document depth and verbosity

Put a rule where the reader meets it. A rule governing Step 6 of the minor loop belongs in the Step 6 entry of the workflow table, not in a separate document.

Duplicate content is a defect. When the same rule appears in two documents, one document is the canonical owner and the other links to it. The canonical owner is the document an agent reads first when it needs the rule.

Workflow table Action cells hold one imperative sentence plus a link to the governing section; detail defers to the child document. Negative cases that mark a rule's limit stay in the table cell; illustrative examples belong in the child document.

### Simplified Technical English

New and changed prose meets ASD-STE100.

Phrasing rules (a working subset of the full dictionary, not a replacement for it):

- Active voice. Name the actor: "the seeder copies the repository", never "the repository is copied".
- Short sentences. Aim under 20 words; one idea per sentence.
- One term, one meaning. Pick one word for a thing and keep it. Rotating synonyms ("volume" / "sandbox" / "workspace" for one object) is a defect.
- Common verbs. Prefer: is, has, uses, copies, reads, writes, runs, starts, stops, shows, checks, rejects. Avoid ornate verbs ("leverages", "facilitates", "encompasses").
- No idioms, no metaphors, no hedging ("somewhat", "fairly", "arguably").
- Place the defined noun phrase before the imperative command. The reader must know exactly what object is discussed before being told what to do with it.
- Define a term the reader has not met first, in its own clause, then apply it ("Negative cases are scope constraints", then "Keep scope constraints in the cell").
- Avoid thin subjects that rely on a trailing dash clause for their definition; the main clause must not depend on its afterthought.
- Keep technical nouns the reader needs. STE100 simplifies structure and verbs, not precision.
- State the allowed form and name the action; do not state only what to avoid. Write "a space-separated hyphen", not "do not use an em-dash"; say "apply the durable fix the entry's `scoped:` row names", not "avoid or re-check those patterns".

Evaluate prose with two tests:

- **Delete test.** Can a reader delete a word, phrase, or sentence without changing the required meaning? Delete what the test removes, including empty openers such as "it is worth noting that".
- **Literal-reader test.** A literal reader follows the words exactly and infers no intent. Could the reader turn the sentence into a task, an action, or an inference that was not intended? If yes, rephrase it with the phrasing rules.

**Reserved technical terms** are defined in [`docs/concepts/terminology.md`](../concepts/terminology.md). When a policy, concept, or architecture document uses a reserved term in its technical sense, link to the term's section on first mention. Do not redefine a reserved term locally.

### Character set

Documents use plain ASCII punctuation.

- Write a dash as a space-separated hyphen (` - `), or as a double hyphen (`--`) in prose. In headings, use the space-separated form.
- To reference a document or section, write its name, or link with an anchor.
- Write status markers as `[x]` / `[ ]` (tables) or `- [x]` / `- [ ]` (lists). Do not use checkmark or cross emoji.
- Do not use non-ASCII punctuation (section sign U+00A7, pilcrow U+00B6) or control and formatting symbols (space glyphs, chapter symbols).

**Exception -- ASCII-art diagrams.** Box-drawing characters (U+2502 vertical, U+251C left tee, U+2514 corner, U+2500 horizontal) may appear inside ASCII-art diagrams (for example directory trees), where they carry the diagram's geometry. Use them nowhere else; convert banners, table rules, and decoration to ASCII hyphens.

### Line wrapping

Prose is one paragraph per physical line, however long the line. Never break inside a paragraph -- not at sentence boundaries, not at a column limit; editors and viewers soft-wrap. Hard breaks separate blocks only: paragraphs, headings, list items. The rule covers all prose: guidance blocks, `AGENTS.md`, provider-layer files. Code comments wrap at about 80 columns. Fenced code blocks and table rows are exempt.

### References

Make references with links. Link what the reader might need next; a well-linked document is a good one. Link a document the reader may need to open; otherwise write its name. Inline code (backticks) is not a substitute for a link.

Prefer durable targets. Link a durable document to the durable document that records the fact, not to its evidence: documentation and policy link to an ADR, and the ADR links to the handover that evidences its decision. When a durable document must name transient evidence, write the name as plain text and do not link it.

Place handoff links at the point of use. When a workflow document (such as `iteration_policy.md`) hands off to a subprocess governed by a child policy document, link that policy where the handoff happens -- not only in a References table -- and name the specific section. A References table is navigation, not a handoff.

A number is valid only in the conversation or document where it appears. Use a numbered list when order matters or readers refer to items by number; otherwise use bullets. A durable artifact -- a roadmap task, a code comment -- does not take a number from a transient list; give it a descriptive name. When many references point to one item, move it to a heading.

**One indexable axis per presentation.** When the operator may refer to items by index, present one numbering or lettering scheme, so a reply is unambiguous. Do not place two numbered or lettered sets side by side (for example a review's numbered findings beside the agent's lettered option choices); the reply then maps to the wrong axis. If several sets must appear together, name each axis so a reply is self-mapping (`finding 1`, `option A`).

Form the link precisely. Step-level references carry a section anchor; document-level references use a plain document link. When an agent may need to locate a section programmatically, give a grep command instead of a link.

### No bridge documents

A bridge document exists only to connect two documents that could reference each other directly. Bridge documents are prohibited -- collapse them into the more relevant destination document.

### Read pass economics

Structure documents so agents can grep section headers and range-read only what they need. Every section an agent might need in isolation has a `##` or `###` header -- unnamed blocks are not grep-targetable.

A document that must be read in full to extract one fact is structured wrong. If a fact is needed at a specific moment in a workflow, put it in a named section or inline it at the point of use.

---

## Document Types

This section holds the obligations that apply per document type; it describes no genre.

### Rule authority

A rule is authoritative only where a policy document canonically states it. A rule that exists only in a skill file or prompt template is not authoritative: bypass the skill and the constraint disappears. A concept document or ADR may describe a rule in readable form, but it links to the policy and is not the rule's home. A rule with no policy home is descriptive, not binding.

A statement is a rule when it imposes an obligation a document or its author must meet, and belongs in policy. A statement is a model when it describes the system's structure as a consequence of earlier decisions, and belongs in a concept document, which states it readably and links the rules behind it.

### Concept document obligations

A concept document is standalone and content-complete: a reader new to the area understands the model and what it guarantees without another document. Outbound links are for further reading, not prerequisites.

**Requirements as behavioral contracts.** Restate requirements as user-observable guarantees, without seam vocabulary -- requirement numbers, promotion history, internal component names. The ADR owns the numbering, the design mapping, and the history; the concept doc owns the readable form.

**Interface-level descriptions.** Describe components as interfaces, contracts, or diagrams. Exact commands and variable values appear only for external interactions the harness does not control (for example `docker` CLI mappings). Internal command sequences, function names, and file paths belong in the architecture docs or the ADR.

### ADR obligations

When and how to create or distill an ADR: see [`adr_policy.md`](adr_policy.md) -- When an ADR begins. A concept document links to its ADR and does not restate the ADR's record.

---

## Record Lifecycle

### Folder placement

Pick the folder category before drafting. Update only the sections the change affects -- targeted edits beat rewrites. Add a document only when it serves a structural purpose no existing document covers. Content about what the system does not yet do belongs in `roadmap.md`, not in `concepts/` or `architecture/`.

### Skeleton first for record-layer documents

Before writing an ADR, concept doc, or architecture doc, propose the skeleton in chat -- section list and what each section holds -- and get operator confirmation. Write prose only against the confirmed skeleton. Drafting full prose before the structure is agreed has produced full rewrites. The skeleton costs minutes; a rewrite costs more.

### Records state, not session history

A durable record states the current state of its subject; the concept document [`documentation_taxonomy.md`](../concepts/documentation_taxonomy.md) classifies what endures. A durable record does not narrate the session that produced it: no session ids, no handover names, no commit hashes, no change-of-mind narration, no "as discussed" pointers. The session's path from disagreement to decision belongs in the handover and the design discussion doc; the durable record holds the settled state. When a reader needs the history, the record links to it once.

A design document records the completed design, not the open-questions-and-replies transcript that produced it. When a question is answered during the design, write the answer into the body of the document at the place the answer belongs; do not keep it as a reply. Keep a short section of the designs that were considered and rejected, and why each was rejected. Put the final design at the forefront of the document.

### Document header format

All documents in `docs/` open with a consistent header block, so status and scope are visible without reading the body and `grep -n "^##"` returns a usable section map.

**Standard opening sequence:**

```text
# <Title>
<blank line>
**Status:** <value>         (stories and investigations only)
**Location:** <path>        (only if the file has been moved or renamed)
<blank line>
> **Superseded / Resolved.** <one sentence pointing to the authoritative document.>
```

Rules:

- `**Status:**` is the first line after the title on all `story_` and `investigation_` documents. No preamble before it.
- Superseded and resolved documents carry a blockquote redirect immediately after the status line, naming the target document.
- Architecture, concepts, and policy documents carry no status line -- the layer-freeze table in `system_overview.md` governs them.
- ADR headers and entry structure are defined in [`adr_policy.md`](adr_policy.md), not here.
- Top-level sections use `##`; subsections use `###`. Use `####` only inside long task lists where grouping is genuinely needed -- not for general document structure.

### Post-close document corrections

**Principle.** A closed record's content does not change; whether a record is durable or transient is classified in the concept document [`documentation_taxonomy.md`](../concepts/documentation_taxonomy.md#durability). It gains the marker its type carries, and a record that tracks state also gains a successor entry. The mechanic follows what the record is for: a record that states what is true is corrected in place, and a record that tracks open and closed tasks is corrected by addition.

**Direction.** A closed record is corrected at the operator's direction. The agent may notice a correction and propose it in one line, and may not apply one unasked. The agent never deletes a record; deletion is an operator action. Applying a correction is bounded by two stops and one smell:

- **Stop -- the correction changes the unit's scope or carries new work.** New work belongs in a new iteration.
- **Stop -- an edit to a closed record would carry no marker.** An untraceable edit is a rewrite, not a correction.
- **Smell -- folding the correction needs an interactive rebase with several conflict edits.** Report the smell and stop; the operator rules on it. Past that size the instrument is a port, not a correction: see [`rebase.md`](../../workflow/coding-agent/prompts/rebase.md).

**Propagation.** A correction inherits the record set of the unit it corrects. A unit that changed code, a task description and a handover is corrected in all three, and every closed record among them takes its marker. A correction that leaves a closed record contradicting its successor is incomplete.

**Archival is not amendment.** Moving a closed milestone's entries from the roadmap to the changelog is a length boundary, not a correction, and carries no marker. The changelog is the roadmap's archived half; the two share a format, a mechanic and a vocabulary.

**Forms by document type:**

| Document type | Nature | Form | See |
|---|---|---|---|
| Handover | states what the iteration did | rewrite the paragraph, or reopen the record and close it again; either way a `[CORRECTION -- YYYY-MM-DD: <...>]` tag at the end of the corrected section | [`handover_policy.md`](handover_policy.md#corrections-to-closed-handovers) |
| Roadmap entry | tracks open and closed tasks | keep the entry, add the superseded marker, add the successor entry | [`roadmap_policy.md`](roadmap_policy.md#corrections-to-closed-roadmap-and-changelog-entries) |
| Changelog entry | tracks closed tasks, archived | as a roadmap entry | [`roadmap_policy.md`](roadmap_policy.md#corrections-to-closed-roadmap-and-changelog-entries) |
| Study or investigation | states what was found | rewrite, tag | [`study_policy.md`](study_policy.md#corrections-to-closed-investigations) |
| ADR, concept, architecture, policy | states what the system does | rewrite, tag | this section |

### Missing documents

If a document the agent expects is absent:

- The referencing link carries a `[REMOVED]` marker: the absence is expected. No error.
- The referencing link has no `[REMOVED]` marker: flag an error and ask the operator. Do not assume the document is optional; do not proceed unresolved.
