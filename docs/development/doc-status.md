# Documentation Status

This is the hot file for the agent-sandbox documentation system. It tracks current milestone state, frozen architecture layers, and the expected change frequency of every document in the repo. Update this file whenever a milestone completes or a document's status changes.

For documentation rules and structure, see [`documentation-guidelines.md`](documentation-guidelines.md). That file is frozen policy — this file is live state.

---

## Current Milestone

See [`roadmap.md`](roadmap.md) for the milestone summary table, task-level detail, and completion criteria.

---

## Frozen Architecture Layers

Layer names and responsibilities are defined in [`architecture/system_overview.md`](../architecture/system_overview.md).

| Layer | Name | Status |
|---|---|---|
| 0 | Infrastructure | Frozen at M1 |
| 1 | Execution Mechanics | Frozen at M1.1 (serve mode); in progress M1.2 |
| 2 | Orchestration | Not started |

Security Model and Human Workflow are design constraints and system invariants, not implementation layers. They do not appear in the freeze table.

---

## Document Discovery Flow

New contributors and agents should read documents in this order:

1. [`readme.md`](../../readme.md) — system overview and invariants
2. [`contributors.md`](../../contributors.md) — contribution rules and secrets handling
3. **This file** — current state, what's frozen, what's changing
4. [`documentation-guidelines.md`](documentation-guidelines.md) — documentation rules (read once, rarely revisit)
5. [`roadmap.md`](roadmap.md) — current tasks and open questions

From there, follow links into `architecture/` for implementation detail as needed.

---

## Document Temperature Map

Temperature reflects the stability of what a document describes — not how carefully it was written or how important it is. A cold document covers principles or invariants that are deliberately settled; frequent changes to a cold document are a signal that something is wrong in the design. A warm document tracks active implementation and evolves with milestones. A hot document is expected to change continuously and should always be read fresh.

**🔴 Hot** — changes continuously
**🟡 Warm** — changes per milestone
**🟢 Cold** — frozen policy or settled invariants; changes signal design instability

### Development (`docs/development/`)

| Document | Temp | Notes |
|---|---|---|
| `doc-status.md` | 🔴 Hot | This file. Update on every milestone transition. |
| `roadmap.md` | 🔴 Hot | Updated continuously as tasks complete. |
| `documentation-guidelines.md` | 🟢 Cold | Frozen policy. Only changes if the documentation model itself changes. |

### Architecture (`docs/architecture/`)

| Document | Temp | Notes |
|---|---|---|
| `system_overview.md` | 🟡 Warm | Update when major architectural components change. |
| `execution_model.md` | 🔴 Hot | Active implementation document. Evolves with each Execution Mechanics milestone. Last updated: M1.2. |
| `security.md` | 🟢 Cold | Design constraint and trust boundary spec. Changes signal a design-level shift. |
| `threat_model_stride.md` | 🟢 Cold | STRIDE analysis is implementation-agnostic. Revisit at major threat surface changes. |

### Concepts (`docs/concepts/`)

| Document | Temp | Notes |
|---|---|---|
| `agent_workflow.md` | 🟢 Cold | Staging principles and operator workflow. Changes signal a shift in core workflow design. |

### Operations (`docs/operations/`)

| Document | Temp | Notes |
|---|---|---|
| `standard_operating_procedures.md` | 🟡 Warm | Update when security mitigations or operational procedures change. |
| `quickstart.md` | 🟡 Warm | Verify on each milestone. Not yet confirmed against M1.2. |

### References (`docs/references/`)

| Document | Temp | Notes |
|---|---|---|
| `glossary.md` | 🟡 Warm | Update when new terms are introduced or definitions change. |

### Root

| Document | Temp | Notes |
|---|---|---|
| `readme.md` | 🟢 Cold | System invariants and entry point. Should rarely need updating. |
| `contributors.md` | 🟢 Cold | Contribution rules. Update only when workflow or security model changes. |
| `agent-context-brief.md` | 🟡 Warm | Update when agent collaboration protocol evolves. |
