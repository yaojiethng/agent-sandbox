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

### Steps

**1. Close the prior major milestone**
Follow [`roadmap_policy.md`](roadmap_policy.md) — Trigger A: write the changelog entry, extract the milestone, promote the next milestone from `roadmap_future.md`. Confirm all sub-milestone entries are complete in the changelog before proceeding.

**2. Orient to the next major milestone**
Read the promoted milestone section in `roadmap.md`. Identify: which sub-milestones are fully scoped, which have open design questions, and which depend on earlier sub-milestone implementation decisions and cannot yet be scoped.

**3. Open stories for unresolved design areas**
For each area where the design is not settled, open a `story_` document in `docs/discussions/`. See [`story_policy.md`](story_policy.md). Stories surface pain points and frame the investigation space — they do not propose solutions.

**4. Commission investigations**
For each story where candidate approaches need evaluation, open one `investigation_` document per candidate in `docs/discussions/`. See [`investigation_policy.md`](investigation_policy.md). Investigations run until a recommendation can be made.

**5. Resolve stories to roadmap entries**
When a story's open questions are resolved, graduate it: close the story with a Resolution section per [`story_policy.md`](story_policy.md) — Closure, and write the corresponding sub-milestone entry into `roadmap_future.md` (or directly into `roadmap.md` if the sub-milestone is next) per [`roadmap_policy.md`](roadmap_policy.md). Unresolvable stories — those that depend on earlier implementation decisions — are explicitly deferred, noted in the story, and flagged for the relevant minor loop session.

**6. Confirm the milestone is ready to session**
The major loop closes when M2.1 (the first sub-milestone) has a complete roadmap entry with an objective, resolved design decisions, and a task list. Subsequent sub-milestones may still have open items — that is expected. The loop does not require all sub-milestones to be fully scoped before sessioning begins.

---

## Minor Loop — Session Workflow

A session targets one sub-milestone but need not span the full step sequence. Steps 1, 1b, and 8–9 always run; the middle steps are scoped to the session type:

```
Minor loop
├── Step 1  — Open handover         (always)
├── Step 1b — Confirm scope         (always)
├── Step 2  — Design                (design session)
├── Step 3  — Conceptual docs       (design session)
├── Step 4  — Spec                  (spec session)
├── Step 5  — Architecture docs     (spec session)
├── Step 6  — Acceptance criteria   (session before implementation)
├── Step 7  — Implementation        (implementation session)
├── Step 7b — Pre-close verification (implementation session)
├── Step 8  — Close session         (always)
└── Step 9  — Seed next session     (always)
```

A step does not advance until its exit condition is met and the operator has confirmed.

| Step | Entry condition | Action | Exit condition |
|---|---|---|---|
| **1 — Open handover** | Session begins | Check whether [Trigger B](roadmap_policy.md#sub-milestone-close-trigger-b) has run: if the prior handover names a new sub-milestone but the roadmap still shows the previous sub-milestone as active, Trigger B has not run — run it right after creating the next handover. Then compact completed task groups per [`roadmap_policy.md`](roadmap_policy.md#session-open-step-1). Create and populate handover per [`handover_policy.md`](handover_policy.md#at-session-open-step-1). Read roadmap for pending work. | Handover draft complete. |
| **1b. Confirm scope** | Handover draft complete | Present a scope proposal in chat per [`handover_policy.md`](handover_policy.md#at-scope-confirmation-step-1b): what is in scope this session, what is explicitly deferred and why, and any blocking questions. If context is insufficient to propose, interview the operator one question at a time until a proposal can be made. Do not produce any file, code, or structural output until the operator explicitly releases this gate. Update the handover Scope section to reflect confirmed scope. The release applies to the immediately following step only — after producing that step's output, pause and confirm before advancing further. | Operator has confirmed scope **and** sent an explicit release to proceed (e.g. "proceed", "go ahead", "start"). A message that confirms or acknowledges scope without a clear forward signal (e.g. "that looks right, hold changes", "yes but wait") does not satisfy this exit condition — the agent remains at this gate. If in doubt, ask: "Shall I proceed?" |
| **2 — Design** | Scope confirmed. *Skip if:* roadmap entry already has resolved decisions and recorded rationale — task list alone does not satisfy skip. | Gather requirements, surface tensions, ask clarifying questions one at a time. Record all decisions in the roadmap and relevant discussion document per [`roadmap_policy.md`](roadmap_policy.md#rules). Note in handover Decisions table. Resolve any deferred story that depends on this sub-milestone before proceeding. | All design questions resolved and recorded. Operator confirmed. |
| **3 — Conceptual docs** | Design confirmed | Update `docs/concepts/` documents per [`documentation_policy.md`](documentation_policy.md). Produce as proposals. | Operator confirmed. No concepts document contradicts the agreed design. |
| **4 — Spec** | Conceptual docs confirmed | Specify files, interfaces, naming, mount shape. Scope is fixed here — adjacent issues are flagged in the handover and deferred, not resolved. | Operator confirmed spec in full. No open interface or naming questions. |
| **5 — Architecture docs** | Spec confirmed | Update `docs/architecture/` documents per [`documentation_policy.md`](documentation_policy.md). Produce as proposals. | Operator confirmed. No architecture document contradicts the confirmed spec. |
| **6 — Acceptance criteria** | Architecture docs confirmed (or design confirmed if session spans design through implementation) | Define criteria per [`handover_policy.md`](handover_policy.md#at-step-6--define-acceptance-criteria). Every session that touches architecture must include a criterion: *"Architecture documents in scope describe the system as built."* | Operator confirmed criteria. `Not yet defined.` replaced. Implementation will not begin without confirmed criteria. |
| **7 — Implementation** | Acceptance criteria confirmed | Produce code against confirmed spec. Tests alongside implementation. If implementation reveals a divergence from the spec — a naming difference, an interface change, a new file — stop and correct the architecture document before continuing. Flag and defer any other adjacent issue. All outputs are proposals. | All targeted tasks complete. Tests pass. Architecture documents reflect the system as built. |
| **7b — Pre-close verification** | Implementation complete | Present a pre-close summary per [`handover_policy.md`](handover_policy.md#at-pre-close-verification-step-7b): what was built, tests produced, AC status per criterion, and recommended manual checks. Wait for the operator to confirm each item or flag gaps. Do not begin Step 8 until the operator explicitly releases this gate. | Operator has confirmed implementation state against acceptance criteria and sent an explicit release to proceed to close (e.g. "close the session", "proceed to Step 8"). |
| **8 — Close session** | Session step range complete | Mark completed tasks per [`roadmap_policy.md`](roadmap_policy.md#session-close-step-8). Verify that every in-scope architecture and concepts document describes the system as built — if any divergence exists, resolve it now or record it as an explicit deferred item that blocks Trigger B. If all sub-milestone tasks are now complete, acceptance criteria are met, and no doc divergence is deferred, run [Trigger B](roadmap_policy.md#sub-milestone-close-trigger-b) before closing the handover. Update handover per [`handover_policy.md`](handover_policy.md#at-session-close-step-8). Update `project_index.md` per [Index Maintenance](#index-maintenance). | Roadmap updated. Trigger B run if applicable. Handover complete. No incomplete tasks or doc divergences without explicit deferral. |
| **9 — Seed next session** | Session closed | Identify next scope from roadmap. Populate handover Next session per [`handover_policy.md`](handover_policy.md#at-session-seed-step-9). If sub-milestone was last in major milestone, flag that major loop is required. | Next session section actionable. |

---

## Index Maintenance

Two documents serve as the project's file registry. Each has a defined owner and update cadence. Neither is updated outside these moments.

**`project_index.md`** is the complete registry. It records every document with its temperature, architecture layer assignment, and the last milestone to touch it (`Last touched in` column).

**The active handover** is the session-scoped hot file list. It replaces `doc_status.md`, which is retired. The Hot files section of the handover is the only place the current session's file scope is recorded.

### Update triggers

**At major loop close:**
- Add any new documents created during planning (stories, investigations, stubs) to `project_index.md` with temperature and last-touched milestone
- Update the Architecture Layers table if freeze status has changed
- Update temperature for any documents whose stability has changed
- `project_index.md` last-touched milestone does not need updating for documents that were not changed — only touched files get their row updated

**At minor loop Step 1 (session open):**
- Create the new handover document
- Populate the Hot files section from the roadmap task list
- No changes to `project_index.md` at this step

**At minor loop Step 8 (session close):**
- Update `project_index.md`: for every file in the Completed this session table, update its `Last touched in` column to the current sub-milestone
- If new files were created during the session, add them to `project_index.md`
- If files were deleted, remove them from `project_index.md`
- Update the Hot files section of the handover to reflect final session state

### Temperature rules

Temperature in `project_index.md` reflects the stability of what a document describes — not how carefully it was written. It is updated at major loop close when a document's role changes, not at every session.

| Temperature | Meaning |
|---|---|
| 🔴 Hot | Changes continuously — roadmap, active handovers |
| 🟡 Warm | Changes per milestone — architecture docs, active policy |
| 🟢 Cold | Frozen policy or settled invariants; changes signal design instability |

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