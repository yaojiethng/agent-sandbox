# Iteration Policy

The authoritative workflow for all development in agent-sandbox. Defines the two loops that govern work: the major loop for milestone planning, and the minor loop for session execution. Principles here are stable; the child documents that govern each subprocess will evolve as the project matures.

Read this document at the start of any session. Read the relevant child document before performing that subprocess.

```
agent-sandbox workflow
│
├── Major loop  (triggers when a major milestone closes)
│   ├── 1. Close prior milestone       roadmap_policy.md — Trigger A
│   ├── 2. Orient to next milestone     roadmap.md
│   ├── 3. Open stories                story_policy.md
│   ├── 4. Commission investigations   investigation_policy.md
│   ├── 5. Resolve stories → roadmap   story_policy.md — Closure
│   └── 6. Confirm ready to session    milestone_policy.md
│
└── Minor loop  (one session per sub-milestone)
    ├── 1.  Open handover              handover_policy.md — At session open
    ├── 1b. Confirm scope              handover_policy.md — At scope confirmation
    ├── 2.  Design                     roadmap_policy.md — Rules
    ├── 3.  Conceptual docs            documentation_policy.md
    ├── 4.  Spec                       —
    ├── 5.  Architecture docs          documentation_policy.md
    ├── 6.  Acceptance criteria        handover_policy.md — At Step 6
    ├── 7.  Implementation             —
    ├── 7b. Pre-close verification     handover_policy.md — At pre-close verification
    ├── 8.  Close session              roadmap_policy.md — Session close + Trigger B if final session
    └── 9.  Seed next session          handover_policy.md — At session seed
```

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

See [`milestone_policy.md`](milestone_policy.md) for the full process governing stories, investigations, and roadmap entry production.

**1. Close the prior major milestone** — run Trigger A per [`roadmap_policy.md`](roadmap_policy.md#major-loop-close-trigger-a).

**2. Orient to the next major milestone** — read the promoted milestone in `roadmap.md`; identify which sub-milestones are scoped, which have open design questions, and which depend on earlier implementation decisions.

**3. Open stories for unresolved design areas** — one `story_` document per unsettled area in `docs/discussions/` per [`story_policy.md`](story_policy.md). Stories frame the problem; they do not propose solutions.

**4. Commission investigations** — one `investigation_` document per candidate approach per [`investigation_policy.md`](investigation_policy.md). Investigations run until a recommendation can be made.

**5. Resolve stories to roadmap entries** — close each story with a Resolution section per [`story_policy.md`](story_policy.md#closure) and write the sub-milestone entry into `roadmap_future.md` per [`roadmap_policy.md`](roadmap_policy.md). Stories that depend on earlier implementation decisions are deferred explicitly.

**6. Confirm the milestone is ready to session** — the first sub-milestone has a complete roadmap entry with an objective, resolved decisions, and a task list. Later sub-milestones may still have open items.

---

## Minor Loop — Session Workflow

A step does not advance until its exit condition is met and the operator has confirmed. Steps 1, 1b, 8, and 9 run every session; middle steps run when in scope for the session type.

| Step | Entry condition | Action | Exit condition |
|---|---|---|---|
| **1 — Open handover** | Session begins | Run Trigger B recovery check and compaction per [`roadmap_policy.md`](roadmap_policy.md#session-open-step-1). Create and populate handover per [`handover_policy.md`](handover_policy.md#at-session-open-step-1). | Handover draft complete. |
| **1b — Confirm scope** | Handover draft complete | Present scope proposal per [`handover_policy.md`](handover_policy.md#at-scope-confirmation-step-1b). Do not produce any output until operator explicitly releases this gate. | Operator confirmed scope and sent explicit release. |
| **2 — Design** | Scope confirmed. *Skip if* roadmap entry already has resolved decisions and recorded rationale. | Gather requirements, surface tensions, ask clarifying questions one at a time. Record decisions in roadmap and relevant discussion document per [`roadmap_policy.md`](roadmap_policy.md#rules). | All design questions resolved and recorded. Operator confirmed. |
| **3 — Conceptual docs** | Design confirmed | Update `docs/concepts/` per [`documentation_policy.md`](documentation_policy.md). Produce as proposals. | Operator confirmed. No concepts doc contradicts the agreed design. |
| **4 — Spec** | Conceptual docs confirmed | Specify files, interfaces, naming. Scope is fixed here — adjacent issues are deferred, not resolved. | Operator confirmed spec in full. No open interface or naming questions. |
| **5 — Architecture docs** | Spec confirmed | Update `docs/architecture/` per [`documentation_policy.md`](documentation_policy.md). Produce as proposals. | Operator confirmed. No architecture doc contradicts the confirmed spec. |
| **6 — Acceptance criteria** | Architecture docs confirmed | Define criteria per [`handover_policy.md`](handover_policy.md#at-step-6--define-acceptance-criteria). Every session touching architecture must include: *"Architecture documents in scope describe the system as built."* | Operator confirmed criteria. `Not yet defined.` replaced. |
| **7 — Implementation** | AC confirmed | Produce code against confirmed spec. Tests alongside implementation. If implementation reveals a spec divergence, correct the architecture doc before continuing. Defer all other adjacent issues. | All targeted tasks complete. Tests pass. Architecture docs reflect the system as built. |
| **7b — Pre-close verification** | Implementation complete | Present pre-close summary per [`handover_policy.md`](handover_policy.md#at-pre-close-verification-step-7b). Wait for operator to confirm before advancing to Step 8. | Operator confirmed and sent explicit release. |
| **8 — Close session** | Step range complete | Mark completed tasks and update `project_index.md` per [`roadmap_policy.md`](roadmap_policy.md#session-close-step-8). Verify all in-scope architecture and concepts docs describe the system as built. Run Trigger B if applicable. Update handover per [`handover_policy.md`](handover_policy.md#at-session-close-step-8). | Roadmap updated. Trigger B run if applicable. Handover complete. |
| **9 — Seed next session** | Session closed | Populate handover Next session per [`handover_policy.md`](handover_policy.md#at-session-seed-step-9). Flag major loop required if sub-milestone was last in the major milestone. | Next session section actionable. |

---

## Index Maintenance

`project_index.md` update rules — triggers, temperature definitions, and update cadence — are governed by [`roadmap_policy.md`](roadmap_policy.md#index-maintenance).

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