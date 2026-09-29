# Documentation Policy

Documentation describes the **current system reality**. It must stay concise, readable, and specific to its purpose. Future work belongs in `roadmap.md`.

Skill files and prompt templates are not documentation. They reference or inline rules from policy documents. See [`agent_workflow.md`](../concepts/agent_workflow.md#how-the-workflow-is-expressed) for those rules.

The policy has five parts: where documents live (Folder Structure), hard gates (Enforcement Rules), how to write prose (Writing Rules), the document types (Document Types), and how records are produced and maintained (Record Lifecycle). Diagnostic checklists for compliance live in [`workflow/coding-agent/audits/documentation-pass.md`](../../workflow/coding-agent/audits/documentation-pass.md).

---

## Folder Structure

Each document belongs to **exactly one** of the following categories:

| Folder | Purpose |
|---|---|
| `architecture/` | Implementation design and decisions |
| `concepts/` | The conceptual models the system runs on: abstract state transitions, multi-component interactions, principles of interaction. The *what* at the conceptual level. |
| `operations/` | How to run the system |
| `development/` | Contributor workflow, policy, and active planning |
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

## Writing Rules

### Document depth and verbosity

Policy documents are the authoritative source for workflow rules. A rule that exists only in a skill file or prompt template is not authoritative -- if the operator bypasses the skill, the constraint disappears.

Put a rule where the reader meets it. A rule that governs Step 6 of the minor loop belongs in the Step 6 entry of the workflow table, not in a separate document.

Duplicate content is a defect. When the same rule appears in two documents, one is the canonical owner and the other links to it. The owner is the document an agent reads first when it needs the rule.

Workflow table Action cells hold one imperative sentence plus a link to the governing section. Detail defers to the child document. Negative cases that mark a rule's limit are scope constraints: keep them in the table cell. Illustrative examples belong in the child document.

### Simplified Technical English

New and changed prose meets ASD-STE100. The test for each word, phrase, and sentence: *can a reader delete it without changing the required meaning?* Delete what the test removes. Delete any word, phrase, or sentence that adds no information (for example a throat-clearing opener such as "it is worth noting that").

Quick rules for writers (a working subset, not the full dictionary):

- Active voice. Name the actor: "the seeder copies the repository", never "the repository is copied".
- Short sentences. Aim under 20 words; one idea per sentence.
- One term, one meaning. Pick one word for a thing and keep it. Rotating synonyms ("volume" / "sandbox" / "workspace" for one object) is a defect.
- Common verbs. Prefer: is, has, uses, copies, reads, writes, runs, starts, stops, shows, checks, rejects. Avoid ornate verbs ("leverages", "facilitates", "encompasses").
- No idioms, no metaphors, no hedging ("somewhat", "fairly", "arguably").
- Place the defined noun phrase before the imperative command: the reader must know exactly what object is being discussed before being told what to do with it. If the sentence uses a term the reader has not met, define it first, in its own clause ("Negative cases are scope constraints"), then apply it ("Keep scope constraints in the cell"). Avoid thin subjects that rely on a trailing dash clause for definition; the main clause must not depend on its afterthought.
- Keep technical nouns the reader needs. STE100 simplifies structure and verbs, not precision.

State encoding rules as instructions, not prohibitions. "Write a dash as a space-separated hyphen" beats "do not use an em-dash": the instruction gives the allowed form directly.

Apply the literal-reader test to every instruction. A literal reader follows the words exactly and infers no intent. Ask: could a literal reader turn this sentence into a task, an action, or an inference that was not intended? If yes, rephrase as a positive, bounded, noun-first imperative. Name the actor and the object. State what the reader does, never what it avoids. An instruction that tells the reader to "avoid or re-check those patterns" leaves the action undefined; an instruction that says "apply the durable fix the entry's `scoped:` row names" names the object and the action.

**Reserved technical terms** are defined in [`docs/concepts/terminology.md`](../concepts/terminology.md). When a policy, concept, or architecture document uses a reserved term in its technical sense, link to the term's section on first mention. Do not redefine a reserved term locally.

### Character set

Documents use plain ASCII punctuation.

- Write a dash as a space-separated hyphen (` - `), or as a double hyphen (`--`) in prose. In headings, use the space-separated form.
- To reference a document or section, write its name, or link with an anchor.
- Write status markers as `[x]` / `[ ]` (tables) or `- [x]` / `- [ ]` (lists). Do not use checkmark or cross emoji.
- Do not use non-ASCII punctuation (section sign U+00A7, pilcrow U+00B6) or control and formatting symbols (space glyphs, chapter symbols).

**Allowed exception -- box-drawing characters.** Box-drawing characters (U+2502 vertical, U+251C left tee, U+2514 corner, U+2500 horizontal) may appear inside ASCII-art diagrams (for example directory trees), where they carry the diagram's geometry. Use them nowhere else; convert banners, table rules, and decoration to ASCII hyphens.

### Line wrapping

Prose is one paragraph per physical line, however long the line. Never break inside a paragraph -- not at sentence boundaries, not at a column limit; editors and viewers soft-wrap. Hard breaks separate blocks only: paragraphs, headings, list items. The rule covers all prose: guidance blocks, `AGENTS.md`, provider-layer files. Code comments wrap at about 80 columns. Fenced code blocks and table rows are exempt.

### Numbering and cross-references

A number is valid only in the conversation or document where it appears. Use a numbered list when order matters or readers refer to items by number; otherwise use bullets. Outside the defining place, use the item's descriptive name or a link. A persistent record (a roadmap task, a handover entry, a code comment) does not take a number from a transient list; rename the item descriptively. When many references point to one item, move it to a heading.

**One indexable axis per presentation.** When the operator may refer to items by index, present exactly one numbering or lettering scheme in an exchange, so an index reply is unambiguous. Do not place two numbered or lettered sets side by side (for example a review's numbered findings beside the agent's lettered option choices) and let the operator index one of them; the reply then maps to the wrong axis and the agent must guess. If several sets must appear together, name each axis explicitly so a reply is self-mapping (`finding 1`, `option A`).

### No bridge documents

A bridge document exists only to connect two documents that could reference each other directly. Bridge documents are prohibited -- collapse them into the more relevant destination document.

### Link sparingly, at points of use

When a document names another document and the reader may need to open it at that point, use a markdown link, not inline code or plain text. Link what the reader might need next; a well-linked document is a good one.

The defect to avoid is over-linking **transient documents**: handovers, discussion docs, session exports. These are scratch and log documents -- timestamped evidence for the session that produced them. They decay quickly, and the harness does not maintain them. Link a transient document only where the document format calls for it (for example a handover's evidence table, or a design doc's parent link), and prefer plain text otherwise. The maintained tier -- policies, ADRs, concept docs, architecture docs -- is always the right link target, and linking into it freely is encouraged.

Inline code (backticks) is for command names, flag values, variable names, and short code fragments that are not navigable documents. It is not a substitute for a link when the target is a file the reader may need to open.

### Link to policy documents at workflow handoff points

When a workflow document (such as `iteration_policy.md`) hands off to a subprocess governed by a child policy document, the instruction carries a markdown link to that policy at the point of handoff -- not only in a References table. Name the specific section if the document has several.

**Pattern:**

```text
Perform X per [`policy_document.md`](path/to/policy_document.md) -- Section Name.
```

**Rationale:** A References table is navigation, not a handoff. An agent at step 9a who sees "mark completions" must remember the policy exists. An agent who sees "mark completions per [`roadmap_policy.md`](roadmap_policy.md) -- Step 9a" has the handoff at the moment it is needed.

### Link anchors

Step-level references carry section anchors to the governing section. Document-level references (Child Documents tables, References tables) use plain document links; an anchor there implies a narrower scope than intended.

When a document is long enough that an agent might need to locate a section programmatically, give a grep command in code backticks instead of a link. A link says "open the document"; a grep says "find the section".

```bash
grep -n "## Section Name" docs/operations/policy.md
```

### Read pass economics

Structure documents so agents can grep section headers and range-read only what they need. Every section an agent might need in isolation has a `##` or `###` header -- unnamed blocks are not grep-targetable.

The corollary: a document that must be read in full to extract one fact is structured wrong. If a fact is needed at a specific moment in a workflow, put it in a named section or inline it at the point of use.

---

## Document Types

### `roadmap.md`

`roadmap.md` lives in `development/` and receives future language and TODO items removed from architecture documents. Milestones organize it; each milestone is a feature completion boundary.

### Agent-facing documents

Four documents govern agent behaviour. Each answers one question and duplicates none of the others.

**`readme.md`** -- entry point for humans and agents. System invariants, architecture layer model, documentation guide path.

**`AGENTS.md`** -- provider-specific notes, collaboration protocol, role definition, read discipline, output format rules. Governs all agents regardless of provider. Swapped out when the provider changes.

**`devlog/handovers/YYYYMMDD-NN-TYPE-description.md`** -- session log, not a document. Not subject to this policy. See [`handover_policy.md`](handover_policy.md) for format rules.

### Concepts docs

A concepts doc states a conceptual model the system runs on: abstract state transitions, multi-component interactions, or principles of interaction that no single component owns. It states the *what*, not the *how*. It is not an introduction to one component.

A concept doc is **standalone and content-complete for onboarding**: a reader new to the area needs no other document to understand the model and what it guarantees. Outbound links exist for further reading, not as prerequisites.

**Requirements as behavioral contracts.** Restate requirements as user-observable guarantees, without seam vocabulary -- requirement numbers, promotion history, internal component names. Do not link to the ADR's requirement table instead of restating. The ADR owns the numbering, the design mapping, and the history; the concept doc owns the readable form.

**Interface-level descriptions.** Describe components as interfaces, contracts, or diagrams. Exact commands and variable values appear only for external interactions the harness does not control (for example `docker` CLI mappings). Internal command sequences, function names, and file paths belong in the architecture docs or the ADR.

**Defect history lives in the ADR.** A concept doc carries no incident narratives, no previous-implementation comparisons, no handover references, no session ids, no "discovered in" pointers. When a defect shapes the model, its lasting content is a requirement (owned by the ADR); the ADR entry for the fixing solution owns the failure record.

A concept doc links to the ADR that explains why the model was chosen. The ADR workflow lives in [`adr_policy.md`](adr_policy.md).

Suggest an ADR when:

- The feature introduces a primitive or model other components must reason about
- The area has non-obvious invariants that cannot be stated concisely in the architecture doc
- A design doc exists for the area and is too long or branched to serve as a stable reference

Distill a design doc into an ADR:

1. Remove delivery-sequence framing -- "Change N", "prerequisite", "introduced in".
2. Remove command shapes and implementation detail that belong in the architecture doc.
3. Keep primitives, invariants, design rationale, and collision or interaction tables.
4. During active development, links to design and discussion documents are expected.

---

## Record Lifecycle

### Folder placement

Pick the folder category before drafting. Update only the sections the change affects -- targeted edits beat rewrites. Add a document only when it serves a structural purpose no existing document covers. Content about what the system does not yet do belongs in `roadmap.md`, not in `concepts/` or `architecture/`.

### Skeleton first for record-layer documents

Before writing an ADR, concept doc, or architecture doc, propose the skeleton in chat -- section list and what each section holds -- and get operator confirmation. Write prose only against the confirmed skeleton. Drafting full prose before the structure is agreed has produced full rewrites. The skeleton costs minutes; a rewrite costs more.

### Records state, not session history

A durable record (ADR, concept, architecture, policy) describes the current state of its subject. It does not narrate the session that produced it: no session ids, no handover names, no commit hashes, no change-of-mind narration, no "as discussed" pointers. The session's path from disagreement to decision belongs in the handover and the design discussion doc; the durable record holds the settled state. When a reader needs the history, the record links to it once.

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

**Principle.** A closed record's content does not change. It gains the marker its type carries, and a record that tracks state also gains a successor entry. The mechanic follows what the record is for: a record that states what is true is corrected in place, and a record that tracks open and closed tasks is corrected by addition.

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
