# Documentation Policy

Documentation describes the **current system reality**. It must remain concise, readable, and purpose-specific. Future work belongs in `roadmap.md`.

Skill files and prompt templates are not documentation. They are consumers of documentation — referencing or selectively inlining rules defined in policy documents for context efficiency. The rules governing how skill files and prompt templates relate to policy documents are defined in [`agent_workflow.md`](../concepts/agent_workflow.md#how-the-workflow-is-expressed).

---

## Folder Structure

Each document belongs to **exactly one** of the following categories:

| Folder | Purpose |
|---|---|
| `architecture/` | Implementation design and decisions |
| `concepts/` | Conceptual model and principles |
| `operations/` | How to run the system |
| `development/` | Contributor workflow, policy, and active planning |
| `discussions/` | Investigation and story documents — reasoning records, not current system description |

Architecture documents must not describe things a frozen layer does not yet do. The layer model and freeze definitions are in [`system_overview.md`](../architecture/system_overview.md#architecture-layer-model); current freeze status per file is tracked in [`project_index.md`](../development/project_index.md).

---

## Enforcement Rules

### No future language in `architecture/`

The following words indicate speculative design and are prohibited in architecture documents:

`will` `plan` `future` `later` `eventually` `may support`

Move any such content to `roadmap.md`.

### No TODOs in `architecture/`

Examples of prohibited content:

```
TODO: add sandbox enforcement
TODO: implement agent queue
```

Move all TODO items to `roadmap.md` or the issue tracker. Architecture documents must remain stable and authoritative.

### PR gate

Every pull request must answer: **"Does this change system behaviour?"**

- **Yes** — update the relevant architecture document before merging.
- **No** — no documentation changes required.

This question must appear in the pull request template as a required checkbox.

### Code example propagation check

When updating an architecture or concepts document, verify that every code block, variable name, path, and function signature in the document reflects the current implementation. A document partially updated across multiple sessions accumulates stale examples that silently contradict the system as built.

Check before closing any session that touched an architecture or concepts document: does every code example in the document still use current variable names and call signatures? If not, update or remove the stale example before the session closes.

---

## Linking Convention

Dependencies between documents must flow in one direction: lower layers do not reference higher ones. Stable documents do not reference volatile ones.

### No bridge documents

A bridge document exists solely to connect two other documents that could reference each other directly. Bridge documents are prohibited — collapse them into the most relevant destination document instead.

### Link to relevant documents wherever possible

When a document references another document, file, or script by name, it should be a markdown link rather than inline code or plain text. A reader should be able to navigate to the referenced document directly from the reference point, not only from a References table at the bottom.

Inline code (backticks) is appropriate for: command names, flag values, variable names, and short code fragments that are not navigable documents. It is not a substitute for a link when the target is a file the reader may need to open.

### Link to policy documents at workflow handoff points

When a workflow document (such as `iteration_policy.md`) instructs the agent to perform a subprocess governed by a child policy document, the instruction must carry a markdown link to that policy document at the point of handoff — not only in a References table. The link should name the specific section within the policy document where the relevant rules begin, if the document has multiple sections.

**Pattern:**
```
Perform X per [`policy_document.md`](path/to/policy_document.md) — Section Name.
```

**Rationale:** A References table at the end of a document is navigation aid, not a handoff. An agent executing step 9a that sees "mark completions" without a link to `roadmap_policy.md` must remember to consult it. An agent that sees "mark completions per [`roadmap_policy.md`](roadmap_policy.md) — Step 9a" has the handoff made explicit at the moment it is needed. The link is the instruction to read the policy, not an afterthought.

### Link anchors

Step-level references carry section anchors pointing to the specific governing section of the target document. Document-level references — Child Documents tables, References tables — use plain document links. Adding an anchor to a document-level reference implies a narrower scope than intended and should be avoided.

When a document is long enough that an agent might need to locate a section programmatically, use a grep command in code backticks rather than a markdown link. A link instructs the agent to open the document; a grep command instructs the agent to locate the relevant section within it.

```
grep -n "## Section Name" docs/operations/policy.md
```

### Read pass economics

Documents must be structured so agents can grep for section headers and range-read only what they need. Every section that an agent might need to locate in isolation must have a `##` or `###` header — unnamed blocks are not grep-targetable.

The corollary: a document that must be read in full to extract one fact is structured incorrectly. If a specific fact is needed at a specific moment in a workflow, it belongs in a named section or it belongs inlined at the point of use.

---

## Conventions

### Document depth and verbosity

Policy documents are the authoritative source for workflow rules. A rule that exists only in a skill file or prompt template is not authoritative — if an operator bypasses the skill, the constraint disappears.

Rules live where they will be read and are most valuable contextually. A rule governing Step 6 of the minor loop belongs in the Step 6 entry of the workflow table, not extracted into a separate document that must be consulted separately.

Duplicate content is a defect. When the same rules appear in two documents, one becomes the canonical owner and the other links to it. The owner is whichever document an agent is most likely to read when they need the rule.

In workflow table Action cells: one imperative sentence stating what happens, followed by a link to the governing section. Detail defers to the child document. Negative cases that define a boundary condition stay in the table cell — they are not detail, they are constraints. Illustrative examples of what satisfies a condition belong in the child document, not in the table.

### `roadmap.md`

`roadmap.md` lives in `development/` and serves as the designated destination for future language and TODO items removed from architecture documents. It is organized by milestone, where each milestone represents a feature completion boundary.

---

### Agent-facing documents

Four documents govern agent behaviour. Each answers a distinct question and must not duplicate the others.

**`readme.md`** — entry point for humans and agents. System invariants, architecture layer model, and documentation guide path.

**`agent_context_brief.md`** — governs all agents regardless of provider. Collaboration protocol, role definition, read discipline, and output format rules.

**`AGENTS.md`** — provider-specific notes. Swapped out when the provider changes. Must not contain protocol rules that belong in `agent_context_brief.md`.

**`docs/devlog/handovers/YYYYMMDD-NN-TYPE-description.md`** — session log, not a document. Not subject to this policy. See [`handover_policy.md`](handover_policy.md) for format rules.

---

### Concepts docs

A concepts doc gives architecture docs a stable reference target for conceptual grounding — when a feature has non-obvious invariants, introduces a new primitive, or interacts with enough other components that the architecture doc alone is insufficient.

Concepts docs live in `docs/concepts/`. Created on demand, not on schedule — the trigger is repeated clarifying questions about the same area, or a feature that agents will need to reason about frequently when designing future changes.

**When to recommend one (Step 3 assessment):** present a recommendation when any of the following apply:

- The feature introduces a new primitive or model that other components will need to reason about
- The area has non-obvious invariants that cannot be stated concisely in the architecture doc
- A design doc exists for the area and is too long or branched to serve as a stable reference link

If none apply, recommend skipping and state why. If no design doc exists, note that — distillation requires source material.

**How to produce one (distillation pass):** produce by distillation from the design doc, not from scratch:

1. Remove delivery-sequence framing — "Change N", "prerequisite", "introduced in" language.
2. Remove command shapes and implementation detail that belong in the architecture doc.
3. Keep: primitives, invariants, design rationale, and collision or interaction tables.
4. During active development, links to design and discussion documents are expected.

**Trigger B cleanup:** at sub-milestone close, if a concepts doc was produced:

1. Firm up any invariants that shifted during implementation.
2. Replace links to design and discussion documents with links to the architecture docs that now exist.
3. Update any status note to name the condition that triggered cleanup, not the workflow mechanism name.

This is a link-and-invariant pass, not a rewrite. When in doubt whether a concepts doc is warranted, recommend skipping.

---

## Document Header Format

All documents in `docs/` must open with a consistent header block so that status and scope are visible without reading the file body, and so that `grep -n "^##"` reliably returns a usable section map.

**Standard opening sequence:**

```
# <Title>
<blank line>
**Status:** <value>         ← stories and investigations only
**Location:** <path>        ← only if the file has been moved or renamed
<blank line>
> **Superseded / Resolved.** <one sentence pointing to the authoritative document.>
```

Rules:

- `**Status:**` must be the first line after the title on all `story_` and `investigation_` documents. No preamble before it.
- Superseded and resolved documents must have a blockquote redirect immediately after the status line, naming the target document explicitly.
- Architecture, concepts, and policy documents do not carry a status line — they are governed by the freeze table in `project_index.md`.
- Top-level sections use `##`. Subsections use `###`. Use `####` only inside long task lists where grouping is genuinely needed — not for general document structure.

---

## Post-Close Document Corrections

### Principle

Closed documents are not re-issued. When an error is found in a closed document, it is corrected in-place with a marked, minimal annotation. The document remains a readable record; the correction is visible at the point of change.

The agent never deletes documents. Deletion is an operator action. The agent's responsibility is to apply the correct correction form and, where applicable, mark referencing links.

### Correction forms by document type

| Document type | Correction form |
|---|---|
| Handover | Dated `[CORRECTION: ...]` amendment block appended at the bottom — see [`handover_policy.md`](handover_policy.md) — Corrections to Closed Handovers |
| Changelog | Inline `[SUPERSEDED in MX.X]` or `[REMOVED in MX.X]` tag appended to the affected sentence — see [`roadmap_policy.md`](roadmap_policy.md) — Corrections to Closed Roadmap and Changelog Entries |
| Roadmap entry | Inline `[SUPERSEDED in MX.X]` or `[REMOVED in MX.X]` tag appended to the affected claim — see [`roadmap_policy.md`](roadmap_policy.md) — Corrections to Closed Roadmap and Changelog Entries |
| Investigation — valid content, minor error | Edits directly in the body + dated `[CORRECTION: ...]` amendment block at the bottom — see [`investigation_policy.md`](investigation_policy.md) — Corrections to Closed Investigations |
| Investigation — invalid or superseded content | `[SUPERSEDED]` status header with link to correct source — see [`investigation_policy.md`](investigation_policy.md) — Corrections to Closed Investigations |

### Amendment block format

Used at the bottom of handover and investigation documents:

```
---
[CORRECTION — YYYY-MM-DD]: <description of what was wrong and what was changed>
```

### Missing documents

If a document the agent expects to find is absent:

- If its referencing link carries a `[REMOVED]` marker — the absence is expected. No error.
- If its referencing link has no `[REMOVED]` marker — flag as an error and prompt the operator before proceeding. Do not assume the document is optional and do not proceed without resolution.

---

## Editing Guidelines

Identify the document's folder category before drafting. Update only the sections affected by the change — do not rewrite entire documents when a targeted edit suffices. Add new documents only when they serve a distinct structural purpose no existing document covers. Content describing what the system does not yet do belongs in `roadmap.md`, not in `concepts/` or `architecture/`. Verify folder placement before drafting, not after.

---

## Audit Checks

Use these when reviewing documentation for policy compliance. They are diagnostic — they identify what has gone wrong, not what to do instead. The corresponding prescriptive rules for documents are in the sections above; rules governing skill files and prompt templates are in [`agent_workflow.md`](../concepts/agent_workflow.md#how-the-workflow-is-expressed). The canonical owner test appears in both `### Document depth and verbosity` (prescriptive) and here (diagnostic) — this is intentional; the two registers serve different readers.

**Canonical owner test.** When a rule appears in two documents, ask: which document will an agent read when they need this rule? That document is the canonical owner. The other should link to it, not restate it.

**Signs of duplication to check:**
- The same constraint stated in both a workflow table cell and a child policy section
- Exit conditions in iteration_policy that restate rules already in handover_policy
- Index maintenance rules appearing outside project_index.md
- Temperature definitions appearing outside project_index.md

**Signs of misplaced content to check:**
- Future language (`will`, `plan`, `eventually`) in any `architecture/` document
- TODO items in any `architecture/` document
- Prescriptive rules in a skill file or prompt template with no corresponding entry in a policy document
- A rule that only exists in a skill file — skills are fast paths, not sources of truth

**Signs of structural problems to check:**
- A section an agent would need to locate in isolation that has no `##` or `###` header
- A document that must be read in full to extract one fact
- A bridge document — one that exists solely to connect two documents that could reference each other directly
- A document-level reference link carrying a section anchor — anchors on document-level references imply narrower scope than intended
