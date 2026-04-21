# Documentation Policy

Documentation describes the **current system reality**. It must remain concise, readable, and purpose-specific. Future work belongs in `roadmap.md`.

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

---

## Layer Model

The implementation stack has three layers. Lower layers must stabilize before higher layers evolve — refactors are always bottom-up.

| Layer | Name | Responsibility |
|---|---|---|
| 0 | Infrastructure | Docker runtime, filesystem, container environment |
| 1 | Execution Mechanics | How a single agent runs tasks and generates diffs |
| 2 | Orchestration | Coordination between multiple agents |

Two elements frame the stack without belonging to it:

**Security Model** — a design constraint specified before implementation and applied to all layers. Architecture documents must satisfy the security spec; the spec does not depend on them.

**Human Workflow** — the outer frame of the system. The operator initiates every run and has final authority over all outputs. This is a system invariant, not a build layer.

---

## Architecture Freeze Policy

Architecture stabilizes per milestone. Once a milestone completes, its layers are frozen. If a lower layer requires modification, refactor **bottom-up** — update dependent layers afterward. Never introduce top-down changes without validating lower layers first.

Current milestone status is recorded in the active handover at the repo root. Frozen layer inventory is maintained in [`project_index.md`](../development/project_index.md).

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

---

## Conventions

### `roadmap.md`

`roadmap.md` lives in `development/` and serves as the designated destination for future language and TODO items removed from architecture documents. It is organized by milestone, where each milestone represents a feature completion boundary.

---

### Agent-facing documents

Four documents govern agent behaviour. Each answers a distinct question and must not duplicate the others.

**`readme.md`** — written for humans and agents alike. System invariants, architecture layer model, documentation guide path, and conceptual separation of workflow/security/roadmap. Entry point for anyone new to the repository.

**`agent_context_brief.md`** — written for all agents regardless of provider. Collaboration protocol, role definition, read discipline, output format rules, and operating workflow. References `readme.md` for system invariants — does not restate them.

**`AGENTS.md`** — provider-specific notes. Capabilities and limitations of the current agent interface (Claude Chat, OpenCode, etc.). Swapped out when the provider changes. Must not contain protocol rules that belong in `agent_context_brief.md`.

**`docs/devlog/handovers/YYYYMMDD-NN-TYPE-description.md`** — session log, not a document. Ephemeral — records what was done and what is next. Not subject to this policy. See [`handover_policy.md`](handover_policy.md) for format rules.

If content is useful to a human reader, it belongs in `readme.md` or the appropriate architecture or concepts document. If content governs all agents, it belongs in `agent_context_brief.md`. If it is provider-specific, it belongs in `AGENTS.md`. None of these files duplicate each other.

---

### Concepts docs

A concepts doc exists to give architecture docs a stable reference target for conceptual
grounding. Architecture docs link to it when they need to say "for why this model is shaped
this way, see X" — when a feature has non-obvious invariants, introduces a new primitive,
or interacts with enough other components that the architecture doc alone is insufficient
for an agent designing changes.

Concepts docs live in `docs/concepts/`.

Concepts docs are created on demand, not on schedule. The trigger is repeated clarifying
questions about the same conceptual area, or a feature area that agents will need to reason
about frequently when designing future changes.

**When to recommend one (Step 3 assessment):**

Present a recommendation to the operator at Step 3 of the minor loop when any of the
following apply:

- The feature introduces a new primitive or model that other components will need to reason
  about when designing changes
- The area has non-obvious invariants that cannot be stated concisely in the architecture
  doc itself
- A design doc exists for the area and is too long or branched to serve as a stable
  reference link from architecture docs

If none of these apply, recommend skipping Step 3 and state why. The operator makes the
final call. If no design doc exists for the area, note that explicitly — distillation
requires source material.

**How to produce one (distillation pass):**

When a concepts doc is confirmed, produce it by distillation from the design doc — not
from scratch. The distillation pass transforms a design doc into a stable conceptual
reference:

1. Remove delivery-sequence framing — "Change N", "prerequisite", "introduced in"
   language. The concepts doc describes the settled model, not how it was delivered.
2. Remove command shapes and implementation detail that belong in the architecture doc.
   The concepts doc describes *why* the model works this way, not *what* the system does.
3. Keep: primitives, invariants, design rationale, and any collision or interaction tables.
4. During active development, links may point to design and discussion documents as the
   reasoning record — this is expected.

**Trigger B cleanup:**

At sub-milestone close, if a concepts doc was produced during the milestone:

1. Firm up any invariants that shifted during implementation.
2. Replace links to design and discussion documents with links to the architecture docs
   that now exist — the architecture doc is the stable reference; the design doc becomes
   background reading.
3. Update the status note at the top of the concepts doc (if present) to name the
   condition that triggered cleanup rather than referencing a workflow mechanism name
   (e.g. "links updated now that `apply_workflow.md` is finalised" not "Trigger B
   cleanup complete").

This is a link-and-invariant pass, not a rewrite.

**Scope:**

Not every feature area warrants a concepts doc. A concepts doc that duplicates what the
architecture doc already states clearly is not earning its place. When in doubt, recommend
skipping.

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

1. Identify the document's folder category.
2. Update only the sections affected by the change.
3. Preserve existing structure unless it is directly invalidated.

Do not rewrite entire documents when a targeted section change is sufficient. Add new documents only when they serve a distinct structural purpose that no existing document covers.

Before drafting any output destined for a repo file, identify the destination folder and verify the content against the rules for that folder. Content describing what the system does not yet do belongs in `roadmap.md`, not in `concepts/` or `architecture/`. Producing a draft and checking it afterward is a policy violation — the check comes first.
