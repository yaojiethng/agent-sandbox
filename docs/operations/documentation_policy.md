# Documentation Policy

Documentation describes the **current system reality**. It must stay concise, readable, and specific to its purpose. Future work belongs in `roadmap.md`.

Skill files and prompt templates are not documentation. They reference or inline rules from policy documents. See [`agent_workflow.md`](../concepts/agent_workflow.md#how-the-workflow-is-expressed) for those rules.

The policy has five parts: where documents live (Folder Structure), hard gates (Enforcement Rules), how to write prose (Writing Rules), the document types (Document Types), and how records are produced and maintained (Record Lifecycle). Diagnostic checklists for compliance live in [`workflow/coding-agent/documentation-pass.md`](../../workflow/coding-agent/documentation-pass.md).

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

Architecture documents must not describe things a frozen layer does not yet do. The layer model and freeze definitions are in [`system_overview.md`](../architecture/system_overview.md#architecture-layer-model); freeze status per file is tracked in [`project_index.md`](../development/project_index.md).

---

## Enforcement Rules

### No future language in `architecture/`

Do not use these words in architecture documents; they indicate speculative design:

`will` `plan` `future` `later` `eventually` `may support`

Move such content to `roadmap.md`.

### No TODOs in `architecture/`

Prohibited content:

```
TODO: add sandbox enforcement
TODO: implement agent queue
```

Move TODO items to `roadmap.md` or the issue tracker. Architecture documents must stay stable and authoritative.

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

**Reserved technical terms** are defined in [`docs/concepts/terminology.md`](../concepts/terminology.md). When a policy, concept, or architecture document uses a reserved term in its technical sense, link to the term's section on first mention. Do not redefine a reserved term locally.

### Character set

Documents use plain ASCII punctuation.

- Write a dash as a space-separated hyphen (` - `), or as a double hyphen (`--`) in prose. In headings, use the space-separated form.
- To reference a document or section, write its name, or link with an anchor.
- Write status markers as `[x]` / `[ ]` (tables) or `- [x]` / `- [ ]` (lists). Do not use checkmark or cross emoji.
- Do not use non-ASCII punctuation (`§`, `¶`) or control and formatting symbols (space glyphs, chapter symbols).

**Allowed exception -- box-drawing characters.** Box-drawing characters (`│ ├ └ ─`) may appear inside ASCII-art diagrams (for example directory trees), where they carry the diagram's geometry. Use them nowhere else; convert banners, table rules, and decoration to ASCII hyphens.

### Line wrapping

Prose is one paragraph per physical line, however long the line. Never break inside a paragraph -- not at sentence boundaries, not at a column limit; editors and viewers soft-wrap. Hard breaks separate blocks only: paragraphs, headings, list items. The rule covers all prose: guidance blocks, `AGENTS.md`, provider-layer files. Code comments wrap at about 80 columns. Fenced code blocks and table rows are exempt.

### Numbering and cross-references

A number is valid only in the conversation or document where it appears. Use a numbered list when order matters or readers refer to items by number; otherwise use bullets. Outside the defining place, use the item's descriptive name or a link. A persistent record (a roadmap task, a handover entry, a code comment) does not take a number from a transient list; rename the item descriptively. When many references point to one item, move it to a heading.

### No bridge documents

A bridge document exists only to connect two documents that could reference each other directly. Bridge documents are prohibited -- collapse them into the more relevant destination document.

### Link sparingly, at points of use

When a document names another document and the reader may need to open it at that point, use a markdown link, not inline code or plain text. Link what the reader might need next; a well-linked document is a good one.

The defect to avoid is over-linking **transient documents**: handovers, discussion docs, session exports. These are scratch and log documents -- timestamped evidence for the session that produced them. They decay quickly, and the harness does not maintain them. Link a transient document only where the document format calls for it (for example a handover's evidence table, or a design doc's parent link), and prefer plain text otherwise. The maintained tier -- policies, ADRs, concept docs, architecture docs -- is always the right link target, and linking into it freely is encouraged.

Inline code (backticks) is for command names, flag values, variable names, and short code fragments that are not navigable documents. It is not a substitute for a link when the target is a file the reader may need to open.

### Link to policy documents at workflow handoff points

When a workflow document (such as `iteration_policy.md`) hands off to a subprocess governed by a child policy document, the instruction carries a markdown link to that policy at the point of handoff -- not only in a References table. Name the specific section if the document has several.

**Pattern:**
```
Perform X per [`policy_document.md`](path/to/policy_document.md) -- Section Name.
```

**Rationale:** A References table is navigation, not a handoff. An agent at step 9a who sees "mark completions" must remember the policy exists. An agent who sees "mark completions per [`roadmap_policy.md`](roadmap_policy.md) -- Step 9a" has the handoff at the moment it is needed.

### Link anchors

Step-level references carry section anchors to the governing section. Document-level references (Child Documents tables, References tables) use plain document links; an anchor there implies a narrower scope than intended.

When a document is long enough that an agent might need to locate a section programmatically, give a grep command in code backticks instead of a link. A link says "open the document"; a grep says "find the section".

```
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

### Document header format

All documents in `docs/` open with a consistent header block, so status and scope are visible without reading the body and `grep -n "^##"` returns a usable section map.

**Standard opening sequence:**

```
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
- Architecture, concepts, and policy documents carry no status line -- the freeze table in `project_index.md` governs them.
- ADR headers and entry structure are defined in [`adr_policy.md`](adr_policy.md), not here.
- Top-level sections use `##`; subsections use `###`. Use `####` only inside long task lists where grouping is genuinely needed -- not for general document structure.

### Post-close document corrections

**Principle.** Closed documents are not re-issued. Correct an error in a closed document in place, with a marked, minimal annotation; the document stays a readable record and the correction is visible at the point of change. The agent never deletes documents -- deletion is an operator action. The agent applies the correct correction form and marks referencing links where applicable.

**Correction forms by document type:**

| Document type | See |
|---|---|
| Handover | [`handover_policy.md`](handover_policy.md#corrections-to-closed-handovers) -- Corrections to Closed Handovers |
| Changelog | [`roadmap_policy.md`](roadmap_policy.md#corrections-to-closed-roadmap-and-changelog-entries) -- Corrections to Closed Roadmap and Changelog Entries |
| Roadmap entry | [`roadmap_policy.md`](roadmap_policy.md#corrections-to-closed-roadmap-and-changelog-entries) -- Corrections to Closed Roadmap and Changelog Entries |
| Study | [`study_policy.md`](study_policy.md#corrections-to-closed-investigations) -- Corrections to Closed Investigations |

### Missing documents

If a document the agent expects is absent:

- The referencing link carries a `[REMOVED]` marker: the absence is expected. No error.
- The referencing link has no `[REMOVED]` marker: flag an error and ask the operator. Do not assume the document is optional; do not proceed unresolved.
