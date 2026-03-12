# Investigation — Workspace Input Channel

**Status:** Resolved. Absorbed into the M1.5 directory restructuring. See Resolution section.

**Direction:** Direction 2 — Stack supplementation  
**Parent story:** [story_provider_knowledge_store.md](story_provider_knowledge_store.md)

---

> **Required reading before this document:**
> - [`docs/architecture/execution_model.md`](../architecture/execution_model.md) — container lifecycle, mount shape, and entrypoint sequence. The mount shape questions raised here intersect with M1.6 (session DB mount addition).
> - [`docs/architecture/security.md`](../architecture/security.md) — trust boundaries and security invariants.
> - [story_provider_knowledge_store.md](story_provider_knowledge_store.md) — context for why this option is being investigated.

---

## Summary

Rather than relying on the agent to autonomously navigate a large vault, the operator pre-scopes work by providing a task brief with explicit file paths via a dedicated input channel. The agent reads the brief and operates only on the nominated files, reducing search load and context window pressure. This is viable with OpenCode today and with any future provider.

---

## Roadmap Overlap

This investigation has two areas of overlap with existing roadmap work that must be resolved before implementation proceeds:

**M2 — Task Brief format (`TASK.md`)**
M2 defines a `TASK.md` per-run brief passed alongside `agent_context_brief.md`. The workspace input channel is the vault-specific near-term realisation of the same idea. The mechanism designed here should align with the M2 brief format rather than introduce a parallel convention. If M2's `TASK.md` format is defined first, this investigation should adopt it. If this investigation proceeds first, its design should be documented as a provisional format pending M2 alignment.

**M1.6 — Mount shape**
M1.6 adds a third container mount for the OpenCode session DB (`~/.local/share/opencode/`). Any mount shape changes made for the input channel must be coordinated with M1.6 to avoid conflicting mount designs. Both investigations should be resolved in the same implementation pass or sequenced explicitly.

---

## Open Design Questions

**1. Container awareness of sandbox and workspace**

Currently the container is aware of `sandbox/` (working copy of project files) but treats `.workspace/` only as an output channel. For the agent to read from an input channel in `.workspace/`, the provider entrypoint must make both paths and their purposes explicit — e.g. via a brief placed in `sandbox/` at startup that describes the available channels. This is a provider entrypoint concern and intersects with the M1.7 provider interface definition.

**2. Mount shape for the input channel**

Current mount shape:

| Host path | Container path | Mode |
|---|---|---|
| `PROJECT_ROOT/.bootstrap/` | `/home/agentuser/.bootstrap/` | read-only |
| `PROJECT_ROOT/.workspace/` | `/home/agentuser/.workspace/` | read-write |

Options for adding an input channel:
- Sub-path of the existing RW `.workspace/` mount (e.g. `.workspace/input/`) — simpler, but the container can write back into it, which is undesirable
- Separate RO mount at a distinct path — cleaner access control; container can read but not modify the brief

A separate RO mount is the preferred approach. Must be coordinated with M1.6 (third mount addition).

**3. Git history exposure**

The agent works from a snapshot copy in `sandbox/` specifically to avoid access to the host repository's git history. Whether read access to `.workspace/` changes this exposure needs to be confirmed before any mount shape change is made.

**4. Input channel lifecycle**

The brief in the input channel must have a defined lifecycle: written by operator before run, read by agent during run, cleared or overwritten before the next run. Retention and versioning of past briefs is a secondary consideration.

---

## Resolution

**Outcome:** Absorbed into M1.5 directory restructuring.

The operator input channel (`SANDBOX_DIR/input/`) was implemented in M1.5 as part of the directory restructuring. The open questions around mount shape (sub-path vs separate RO mount) and git history exposure were resolved by the M1.5 implementation. The decision on mount shape is documented in `execution_model.md`.

The `TASK.md` alignment question remains pending — it is a M2.5 (autonomous task execution) concern and is tracked there. This investigation is otherwise closed.
