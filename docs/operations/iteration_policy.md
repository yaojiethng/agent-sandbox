# Iteration Policy

The authoritative workflow for all development in agent-sandbox. Defines the two loops that govern work: the major loop for milestone planning, and the minor loop for session execution. Principles here are stable; the child documents that govern each subprocess will evolve as the project matures.

Read this document at the start of any session. Read the relevant child document before performing that subprocess.

| Loop | Step | Governing document |
|---|---|---|
| **Major** | 1. Close prior milestone | [`roadmap_policy.md`](roadmap_policy.md#major-loop-close-trigger-a) — Trigger A |
| | 2. Orient to next milestone | `roadmap.md` |
| | **Gate** | wait for operator direction |
| | 3. Open stories | [`story_policy.md`](story_policy.md#when-to-open-a-story) |
| | 4. Commission investigations | [`investigation_policy.md`](investigation_policy.md#when-to-open-an-investigation) |
| | 5. Resolve stories → roadmap | [`story_policy.md`](story_policy.md#closure) — Closure |
| | 6. Confirm ready to session | [`milestone_policy.md`](milestone_policy.md#closing-the-major-loop) |
| **Minor** | 1. Open handover | [`handover_policy.md`](handover_policy.md#at-session-open-step-1) |
| | 2. Confirm scope | [`handover_policy.md`](handover_policy.md#at-scope-confirmation-step-2) |
| | **Gate 1** | wait for operator release before any output |
| | 3. Design | [`roadmap_policy.md`](roadmap_policy.md#rules) |
| | 4. Information gathering pass | [`documentation_policy.md`](documentation_policy.md) |
| | 5. Acceptance criteria | [`handover_policy.md`](handover_policy.md#at-step-5--acceptance-criteria) |
| | **Gate 2** | wait for operator release before implementation |
| | 6. Implementation | — |
| | 7. Pre-close verification | [`handover_policy.md`](handover_policy.md#at-pre-close-verification-step-7) |
| | **Gate 3** | wait for operator release before session close |
| | 8. Close session | [`roadmap_policy.md`](roadmap_policy.md#session-close-step-8) |
| | 9. Seed next session | [`handover_policy.md`](handover_policy.md#at-session-seed-step-9) |

---

## Principles

**Plan before executing.** No file, code, or structural change is produced without a confirmed plan. Proposals wait for operator confirmation before becoming outputs.

**Resolve open questions before advancing.** If a design or scope question cannot be answered, the session does not advance to the next step. Surface the question explicitly — do not assume an answer and proceed.

**Record decisions where the work lives.** Decisions belong in the documents where they were made (roadmap, architecture docs). The handover points to those documents — it does not reproduce their content.

**Confirm the spec before writing code.** The implementation spec — files, interfaces, naming — is confirmed by the operator before any code is produced. It is the agreement, not a starting point.

**Scope is fixed at spec time.** Adjacent issues discovered during implementation are flagged and deferred. They do not enter the current session silently.

**Documentation is part of the task, not a cleanup step.** Architecture and concepts documents are updated before implementation begins — they describe the agreed design the code is written against. If implementation reveals a divergence from the spec, correct the document before the session closes; do not defer it. A sub-milestone cannot close (Trigger B cannot fire) if any in-scope architecture or concepts document contradicts the system as built.

**All outputs are proposals.** The operator reviews, approves, and commits. The agent does not decide what is final.

**Tests for non-trivial logic.** Any function with meaningful branching, error handling, or external dependencies gets tests. Tests are produced alongside implementation, not deferred.

**Acceptance criteria describe outcomes, not implementations.** A criterion states what the operator runs and what they observe — not what a file contains or what internal state exists. A criterion satisfied by reading source rather than running the system is not an acceptance criterion.

**Roadmap reflects reality.** Completed items are marked promptly. Cleanup follows `roadmap_policy.md`.

---

## The Two Loops

Development operates at two cadences:

**Major loop** — triggered when a major milestone closes (e.g. M1 → M2). Plans the next major milestone: defines sub-milestones, opens stories, commissions investigations, and produces scoped roadmap entries. Operator-heavy. Output is a planned milestone ready for session execution.

**Minor loop** — a single session targeting one sub-milestone (e.g. M2.1). Assumes the sub-milestone is scoped. Proceeds through design, spec, implementation, and documentation in sequence. Output is working software and updated documents, closed in a handover.

The loops are sequential at the major level — a major milestone must be planned before its sub-milestones can be sessioned — but the minor loop repeats for each sub-milestone within the major milestone.

---

## Major Loop — Milestone Planning

Triggered after a major milestone closes. Performed once per major milestone before any session work begins. This is a planning and investigation cadence, not a coding one.

| Step | Action | Governing document |
|---|---|---|
| **1 — Close prior milestone** | Write changelog entry, extract milestone, promote next from `roadmap_future.md`. | [`roadmap_policy.md`](roadmap_policy.md#major-loop-close-trigger-a) — Trigger A |
| **2 — Orient to next milestone** | Read promoted milestone in `roadmap.md`. Present to operator: which sub-milestones are fully scoped, which have open design questions, and which depend on earlier implementation decisions and cannot yet be scoped. Wait for operator confirmation before proceeding. | `roadmap.md` |
| **Gate** | Wait for operator to confirm orientation and direct which areas to open stories or investigations for. Do not proceed to Step 3 without explicit direction. | — |
| **3 — Open stories** | For each unresolved design area the operator has directed, open a `story_` document in `docs/discussions/`. | [`story_policy.md`](story_policy.md#when-to-open-a-story) |
| **4 — Commission investigations** | For each story with multiple candidate approaches, open one `investigation_` document per candidate. | [`investigation_policy.md`](investigation_policy.md#when-to-open-an-investigation) |
| **5 — Resolve stories to roadmap entries** | When a story's questions are resolved, graduate it: close with a Resolution section, write the sub-milestone entry to `roadmap_future.md` or `roadmap.md`. Unresolvable stories are deferred and flagged for the relevant minor loop session. | [`story_policy.md`](story_policy.md#closure) — Closure |
| **6 — Confirm ready to session** | Major loop closes when the first sub-milestone has a complete roadmap entry with objective, resolved decisions, and task list. Later sub-milestones may still have open items. | [`milestone_policy.md`](milestone_policy.md#closing-the-major-loop) |

---

## Minor Loop — Session Workflow

The information gathering pass (step 4) reads in order: design decisions, conceptual docs, spec, architecture docs. Lapses are accumulated across all four documents and surfaced together before Gate 2 — related lapses grouped for easy review. Tags: `(always)` runs without exception; `(confirmed)` requires explicit operator release; `(assessed)` check runs, skip allowed when not applicable to session type.

| Step | Tag | Entry condition | Action | Exit condition |
|---|---|---|---|---|
| **1 — Open handover** | always | Session begins | Run recovery checks, then create and populate handover per [`handover_policy.md`](handover_policy.md#at-session-open-step-1). | Handover draft complete. |
| **2 — Confirm scope** | always | Handover draft complete | Present scope proposal per [`handover_policy.md`](handover_policy.md#at-scope-confirmation-step-2); wait for explicit release before any output. | Operator confirmed scope and sent explicit release. A confirmation without a clear forward signal does not satisfy this condition. |
| **Gate 1** | always | Scope confirmed | No output until operator releases. | Explicit release received. |
| **3 — Design** | confirmed | Gate 1 released. Skip if roadmap entry already has resolved decisions with recorded rationale — task list alone does not satisfy skip. | Gather requirements; resolve any deferred story that depends on this sub-milestone; record decisions in roadmap and handover per [`roadmap_policy.md`](roadmap_policy.md#rules). | All design questions resolved, recorded, and operator confirmed. |
| **4 — Information gathering pass** | assessed | Design confirmed | Read in order: design decisions, conceptual docs, spec, architecture docs. Accumulate lapses across all four; group related lapses across document boundaries; surface together before Gate 2. Per [`documentation_policy.md`](documentation_policy.md). | All lapses surfaced and resolved. No open questions. |
| **5 — Acceptance criteria** | confirmed | Information gathering pass complete | Define criteria per [`handover_policy.md`](handover_policy.md#at-step-5--acceptance-criteria). Every session touching architecture must include: *"Architecture documents in scope describe the system as built."* | Operator confirmed. `Not yet defined.` replaced. |
| **Gate 2** | always | Acceptance criteria confirmed | No implementation until operator releases. | Explicit release received. |
| **6 — Implementation** | confirmed | Gate 2 released | Produce code against confirmed spec; tests alongside. On spec divergence: correct architecture doc before continuing. Flag and defer all other adjacent issues. | All tasks complete. Tests pass. Architecture docs reflect system as built. |
| **7 — Pre-close verification** | confirmed | Implementation complete | Present pre-close summary per [`handover_policy.md`](handover_policy.md#at-pre-close-verification-step-7); wait for explicit release before Step 8. | Operator confirmed against AC and sent explicit release. Packaging changes do not release this gate. |
| **Gate 3** | always | Pre-close verified | No session close until operator releases. | Explicit release received. |
| **8 — Close session** | always | Gate 3 released | Mark tasks and run Trigger B if applicable per [`roadmap_policy.md`](roadmap_policy.md#session-close-step-8); verify all in-scope architecture and concepts docs describe the system as built — resolve divergences or record as explicit deferrals blocking Trigger B; close handover per [`handover_policy.md`](handover_policy.md#at-session-close-step-8). | Roadmap updated. Handover closed. No doc divergences without explicit deferral. |
| **9 — Seed next session** | always | Session closed | Populate handover Next session per [`handover_policy.md`](handover_policy.md#at-session-seed-step-9). If sub-milestone was last in major milestone, write "Major loop required" and link to [`iteration_policy.md`](iteration_policy.md#major-loop--milestone-planning). | Next session section actionable. |

---

## Index Maintenance

`project_index.md` is the complete registry. The active handover's Hot files section is the session-scoped list. Update rules, trigger moments, and temperature definitions are in [`project_index.md` — Maintenance Rules](../development/project_index.md#maintenance-rules).

---

## Child Documents

| Document | Governs |
|---|---|
| [`milestone_policy.md`](milestone_policy.md) | Major loop: milestone planning, story and investigation process |
| [`story_policy.md`](story_policy.md) | Story lifecycle: creation, investigation trigger, graduation, closure |
| [`investigation_policy.md`](investigation_policy.md) | Investigation lifecycle: structure, states, recommendation, closure |
| [`handover_policy.md`](handover_policy.md) | Handover format, naming, population rules, session continuity |

---

## References

| Document | Purpose |
|---|---|
| [`documentation_policy.md`](documentation_policy.md) | Document structure and folder ownership rules |
| [`roadmap_policy.md`](roadmap_policy.md) | Roadmap update sequence, milestone promotion, changelog format |