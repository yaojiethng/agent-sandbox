# Iteration Policy

The authoritative workflow for all development in agent-sandbox. Defines the two loops that govern work: the major loop for milestone planning, and the minor loop for session execution. Principles here are stable; the child documents that govern each subprocess will evolve as the project matures.

Read this document at the start of any session. Read the relevant child document before performing that subprocess.

---

## Principles

**Plan before executing.** No file, code, or structural change is produced without a confirmed plan. Proposals wait for operator confirmation before becoming outputs.

**Resolve open questions before advancing.** If a design or scope question cannot be answered, the session does not advance to the next step. Surface the question explicitly — do not assume an answer and proceed.

**Record decisions where the work lives.** Decisions belong in the relevant document, not only in chat. If the reasoning is not recorded, it does not exist for the next session.

**Confirm the spec before writing code.** The implementation spec — files, interfaces, naming — is confirmed by the operator before any code is produced. It is the agreement, not a starting point.

**Scope is fixed at spec time.** Adjacent issues discovered during implementation are flagged and deferred. They do not enter the current session silently.

**Documentation is part of the task.** A session is not complete until the relevant documents reflect the new system reality. Marking tasks complete before documentation is done is a violation.

**All outputs are proposals.** The operator reviews, approves, and commits. The agent does not decide what is final.

**Tests for non-trivial logic.** Any function with meaningful branching, error handling, or external dependencies gets tests. Tests are produced alongside implementation, not deferred.

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
Follow `roadmap_policy.md` Trigger A: write the changelog entry, extract the milestone, promote the next milestone from `roadmap_future.md`. Confirm all sub-milestone entries are complete in the changelog before proceeding.

**2. Orient to the next major milestone**
Read the promoted milestone section in `roadmap.md`. Identify: which sub-milestones are fully scoped, which have open design questions, and which depend on earlier sub-milestone implementation decisions and cannot yet be scoped.

**3. Open stories for unresolved design areas**
For each area where the design is not settled, open a `story_` document in `docs/discussions/`. See [`story_policy.md`](story_policy.md). Stories surface pain points and frame the investigation space — they do not propose solutions.

**4. Commission investigations**
For each story where candidate approaches need evaluation, open one `investigation_` document per candidate in `docs/discussions/`. See [`investigation_policy.md`](investigation_policy.md). Investigations run until a recommendation can be made.

**5. Resolve stories to roadmap entries**
When a story's open questions are resolved, graduate it: close the story with a Resolution section, and write the corresponding sub-milestone entry into `roadmap_future.md` (or directly into `roadmap.md` if the sub-milestone is next). Unresolvable stories — those that depend on earlier implementation decisions — are explicitly deferred, noted in the story, and flagged for the relevant minor loop session.

**6. Confirm the milestone is ready to session**
The major loop closes when M2.1 (the first sub-milestone) has a complete roadmap entry with an objective, resolved design decisions, and a task list. Subsequent sub-milestones may still have open items — that is expected. The loop does not require all sub-milestones to be fully scoped before sessioning begins.

---

## Minor Loop — Session Workflow

A session targets one sub-milestone. Each step has an entry condition and an exit condition. A step does not advance until its exit condition is met and the operator has confirmed.

### Step 1 — Open the handover

**Entry:** Session begins.
**Action:** Create or update the handover document for this session. Populate it from the current milestone entry in `roadmap.md`: milestone ID, objective, open decisions, task list. If a prior handover exists for this sub-milestone, read it first — it is the authoritative record of where the last session ended.
**Exit:** Handover is populated and active. The agent knows exactly where it is and what remains.

See [`handover_policy.md`](handover_policy.md) for format and population rules.

### Step 2 — Design

**Entry:** Handover is open.
**Skip condition:** The milestone entry in `roadmap.md` already contains resolved open decisions and an agreed conceptual approach with recorded rationale. A task list alone does not satisfy the skip condition — rationale must be present.
**Action:** Gather conceptual requirements. Surface tensions. Ask the operator any clarifying questions (one at a time). Agree on the design. Record all decisions in the handover and in the relevant discussion document. If a deferred story surfaces here — a design question flagged during the major loop as depending on this sub-milestone's implementation decisions — resolve it now before proceeding.
**Exit:** All open design questions are resolved and recorded. Operator has confirmed the conceptual approach. No unresolved questions remain.

### Step 3 — Update conceptual documentation

**Entry:** Design is confirmed.
**Action:** Identify which documents in `docs/concepts/` need updating to reflect the agreed design. Produce updates as proposals. Update the handover task list to record which documents were changed.
**Exit:** Operator has reviewed and confirmed all conceptual document changes. No conceptual document describes a state that contradicts the agreed design.

### Step 4 — Spec

**Entry:** Conceptual documentation is confirmed.
**Action:** Specify the implementation: which files change, what interfaces are added or modified, what naming conventions apply, what the mount shape or integration points are. This is the agreement — not a starting point. Scope is fixed here. Adjacent issues discovered during spec are flagged in the handover and deferred.
**Exit:** Operator has confirmed the implementation spec in full. No open interface or naming questions remain.

### Step 5 — Update architecture documentation

**Entry:** Spec is confirmed.
**Action:** Identify which documents in `docs/architecture/` need updating to reflect the confirmed spec. Produce updates as proposals. Update the handover task list to record which documents were changed.
**Exit:** Operator has reviewed and confirmed all architecture document changes. No architecture document describes a state that contradicts the confirmed spec.

### Step 6 — Define acceptance criteria

**Entry:** Architecture documentation is confirmed.
**Action:** Define what a correct implementation looks like. For library functions: unit tests covering meaningful branching, error handling, and external dependencies. For scripts and entrypoints: explicit acceptance test steps — what the operator will run, what output they will observe, what constitutes pass and fail. Record criteria in the handover.
**Exit:** Operator has confirmed the acceptance criteria. Implementation will not begin without them.

### Step 7 — Update handover with acceptance criteria

**Entry:** Acceptance criteria are confirmed.
**Action:** Add the acceptance criteria as a named section in the handover document. Confirm the handover now reflects: milestone, open task list, agreed design, confirmed spec, documentation changes made, and acceptance criteria.
**Exit:** Handover is complete as a pre-implementation record.

### Step 8 — Implementation

**Entry:** Handover is complete as a pre-implementation record.
**Action:** Produce code against the confirmed spec. Tests are produced alongside implementation. If a gap or adjacent issue is found, flag it in the handover and defer — do not resolve it silently. All outputs are proposals for operator review.
**Exit:** All implementation tasks in the handover are complete. Tests pass. Operator has reviewed and confirmed the implementation against the acceptance criteria.

### Step 9a — Close the session

**Entry:** Implementation is confirmed.
**Action:** Mark all completed tasks in the roadmap per `roadmap_policy.md`. Confirm no tasks remain in scope that are incomplete without an explicit deferral note. Update the handover to record what was completed this session. If any tasks are deferred, record them with a reason — they are not silently dropped.
**Exit:** Roadmap is updated. Handover reflects a true and complete record of the session. No incomplete tasks remain in scope without an explicit note.

### Step 9b — Seed the next session

**Entry:** Current session is closed.
**Action:** Identify the next sub-milestone. Read its roadmap entry. Note any open design questions that will need resolution at session start. Populate the next handover stub: milestone ID, known open questions, any watch-out items from this session. If the completed sub-milestone was the last in the major milestone, flag that a major loop is required before the next session.
**Exit:** Next handover stub exists and is actionable. The next agent session can begin without reconstructing state from scratch.

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

**At minor loop Step 9a (session close):**
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
| [`autonomous_task.md`](../concepts/autonomous_task.md) | Relationship between this interactive workflow and the future autonomous workflow (M3) |
