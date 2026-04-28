# Iteration Policy

The authoritative workflow for all development in agent-sandbox. Defines the two loops that govern work: the major loop for milestone planning, and the minor loop for session execution. Principles here are stable; the child documents that govern each subprocess will evolve as the project matures.

Read this document at the start of any session. Read the relevant child document before performing that subprocess.

| Loop | Step | Governing document |
|---|---|---|
| **Major** | 1. Close prior milestone | [`roadmap_policy.md`](roadmap_policy.md#major-loop-close-trigger-a) — Trigger A |
| | **Gate 1** | select next milestone |
| | 2. Orient to next milestone | `roadmap.md` |
| | **Gate 2** | select sub-milestone (also entry point for Trigger B) |
| | 3. Open or revise stories | [`story_policy.md`](story_policy.md#when-to-open-a-story) |
| | 4. Investigate or design | [`investigation_policy.md`](investigation_policy.md#when-to-open-an-investigation) |
| | 5. Resolve stories | [`story_policy.md`](story_policy.md#closure) — Closure |
| | **Gate 3** | confirm ready to session |
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

| Step | Entry condition | Action | Exit condition | Governing document |
|---|---|---|---|---|
| **1 — Close prior milestone** | Prior milestone complete and no current milestone open. Skip to Gate 2 if a milestone is already open. | Write changelog entry and extract the completed milestone from `roadmap.md`. | Prior milestone removed from roadmap. Changelog entry written. | [`roadmap_policy.md`](roadmap_policy.md#major-loop-close-trigger-a) — Trigger A |
| **Gate 1 — Select next milestone** | Prior milestone closed. Skip to Gate 2 if a milestone is already open. | Present available next milestones from `roadmap_future.md`. Wait for operator to select which to promote. | Operator selects next milestone. Explicit release required. | — |
| **2 — Orient to next milestone** | Operator has selected next milestone. | Promote selected milestone from `roadmap_future.md` into `roadmap.md`. Read it. Present sub-milestones ready to progress (no unresolved dependencies) and which have open planning work. | Orientation presented. | `roadmap.md` |
| **Gate 2 — Select sub-milestone** | Orientation presented. | Wait for operator to select which sub-milestone to plan first. This gate also fires when a sub-milestone closes mid-milestone (Trigger B) — enter here directly, skipping Gate 1 and Step 2. | Operator selects sub-milestone. Explicit release required. | — |
| **3 — Open or revise stories** | Operator has directed specific areas, OR open stories or unresolved questions exist under the chosen sub-milestone. Skip if neither applies. | For each directed or open area, produce a new story or revise an existing one in `docs/discussions/`. | All directed and existing open areas have a current story document. | [`story_policy.md`](story_policy.md#when-to-open-a-story) |
| **4 — Investigate or design** | Unresolved stories exist under the chosen sub-milestone. | For each unresolved story: if direction is clear, produce a design or spec document in `docs/discussions/` directly. If unclear, open investigation documents — one per story, or one per candidate option if the option surface area warrants it. | Every unresolved story has a design document, spec document, or one or more investigation documents. | [`investigation_policy.md`](investigation_policy.md#when-to-open-an-investigation), [`story_policy.md`](story_policy.md) |
| **5 — Resolve stories** | A story has a completed investigation or agreed approach. | Operator reviews each story and provides explicit sign-off with direction. Each story is either graduated to the roadmap or given an explicit status (deferred, abandoned, superseded) with a recorded reason. | All stories under the sub-milestone are resolved or carry an explicit status with recorded reason. Graduated stories are written as roadmap entries. | [`story_policy.md`](story_policy.md#closure) — Closure |
| **Gate 3 — Confirm ready to session** | All stories resolved or explicitly statused. | Wait for operator to confirm the sub-milestone is ready to session. | Operator confirms sub-milestone has a complete roadmap entry. Explicit release required. | [`milestone_policy.md`](milestone_policy.md#closing-the-major-loop) |

---

## Minor Loop — Session Workflow

The information gathering pass (step 4) reads in order: design decisions, conceptual docs, spec, architecture docs. Lapses are accumulated across all four documents and surfaced together before Gate 2 — related lapses grouped for easy review. Tags: `(always)` runs without exception; `(confirmed)` requires explicit operator release; `(assessed)` check runs, skip allowed when not applicable to session type.

| Step | Tag | Entry condition | Action | Exit condition |
|---|---|---|---|---|
| **1 — Open handover** | always | Session begins | Run recovery checks, then create and populate handover per [`handover_policy.md`](handover_policy.md#at-session-open-step-1). | Handover draft complete. |
| **2 — Confirm scope** | always | Handover draft complete | Present scope proposal per [`handover_policy.md`](handover_policy.md#at-scope-confirmation-step-2); wait for explicit release before any output. | Operator confirmed scope and sent explicit release. A confirmation without a clear forward signal does not satisfy this condition. |
| **Gate 1** | always | Scope confirmed | No output until operator releases. | Explicit release received. |
| **3 — Design** | confirmed | Gate 1 released. Skip if roadmap entry already has resolved decisions with recorded rationale — task list alone does not satisfy skip. | Gather requirements; resolve any deferred story that depends on this sub-milestone; record decisions in roadmap and handover per [`roadmap_policy.md`](roadmap_policy.md#rules). | All design questions resolved, recorded, and operator confirmed. |
| **4 — Information gathering pass** | assessed | Design confirmed | Read in order: design decisions, conceptual docs, spec, architecture docs; accumulate lapses across all four, group by document boundary, surface together before Gate 2. Per [`documentation_policy.md`](documentation_policy.md). | All lapses surfaced and resolved. No open questions. |
| **5 — Acceptance criteria** | confirmed | Information gathering pass complete | Define criteria per [`handover_policy.md`](handover_policy.md#at-step-5--acceptance-criteria). Every session touching architecture must include: *"Architecture documents in scope describe the system as built."* | Operator confirmed. `Not yet defined.` replaced. |
| **Gate 2** | always | Acceptance criteria confirmed | Before releasing: re-read each criterion and verify it is satisfiable given the confirmed spec. A criterion that would fail on a correct implementation is a spec bug — resolve it now, not at pre-close. No implementation until operator releases. | All criteria verified as satisfiable. Explicit release received. |
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