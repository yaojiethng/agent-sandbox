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

Current milestone status and frozen layer inventory are maintained in [`doc_status.md`](doc_status.md).

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

**`agents.md`** — provider-specific notes. Capabilities and limitations of the current agent interface (Claude Chat, OpenCode, etc.). Swapped out when the provider changes. Must not contain protocol rules that belong in `agent_context_brief.md`.

**`YYYYMMDD_agent_handover.md`** — session log, not a document. Ephemeral — records what was done and what is next. Not subject to this policy. See `task_policy.md` — Session Handover for format rules.

If content is useful to a human reader, it belongs in `readme.md` or the appropriate architecture or concepts document. If content governs all agents, it belongs in `agent_context_brief.md`. If it is provider-specific, it belongs in `agents.md`. None of these files duplicate each other.

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

## Editing Guidelines

1. Identify the document's folder category.
2. Update only the sections affected by the change.
3. Preserve existing structure unless it is directly invalidated.

Do not rewrite entire documents when a targeted section change is sufficient. Add new documents only when they serve a distinct structural purpose that no existing document covers.

Before drafting any output destined for a repo file, identify the destination folder and verify the content against the rules for that folder. Content describing what the system does not yet do belongs in `roadmap.md`, not in `concepts/` or `architecture/`. Producing a draft and checking it afterward is a policy violation — the check comes first.
