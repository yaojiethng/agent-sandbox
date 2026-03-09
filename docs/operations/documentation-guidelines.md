# Documentation Guidelines

Documentation describes the **current system reality**. It must remain concise, readable, and purpose-specific. Future work belongs in `roadmap.md`.

---

## Folder Structure

Each document belongs to **exactly one** of the following categories:

| Folder | Purpose |
|---|---|
| `architecture/` | Stable system design |
| `concepts/` | Conceptual model |
| `operations/` | How to run the system |
| `development/` | Contributor workflow |
| `references/` | Glossary and schemas |

---

## Layer Model

The system is organized into five architectural layers. The layer model and bottom-up stabilization principle are defined in [`architecture/system_overview.md`](../architecture/system_overview.md). Current layer freeze status is tracked in [`doc-status.md`](doc-status.md).

---

## Architecture Freeze Policy

Architecture stabilizes per milestone. Once a milestone completes, its layers are frozen. If a lower layer requires modification, refactor **bottom-up** — update dependent layers afterward. Never introduce top-down changes without validating lower layers first.

Current milestone status and frozen layer inventory are maintained in [`doc-status.md`](doc-status.md).

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
- **No** — no architecture documentation changes required.

This question must appear in the pull request template as a required checkbox.

---

## Linking Convention

Dependencies between documents must flow in one direction: `references/` may reference `architecture/`, but `architecture/` must not reference `references/`. Stable lower layers do not reference higher ones.

When a document in `references/` depends on an architecture document, it must declare this explicitly in its opening line. Example:

> This document maps STRIDE threat categories defined in `architecture/threat_model_stride.md` to their corresponding operational responses.

The referenced architecture document should not link back.

### No bridge documents

A bridge document exists solely to connect two other documents that could reference each other directly. Bridge documents are prohibited — collapse them into the most relevant destination document instead.

---

## Conventions

### `roadmap.md`

`roadmap.md` lives in `development/` and serves as the designated destination for future language and TODO items removed from architecture documents. It is organized by milestone, where each milestone represents a feature completion boundary.

---

## Editing Guidelines

1. Identify the document's folder category.
2. Update only the sections affected by the change.
3. Preserve existing structure unless it is directly invalidated.

Do not rewrite entire documents when a targeted section change is sufficient. Add new documents only when they serve a distinct structural purpose that no existing document covers.
