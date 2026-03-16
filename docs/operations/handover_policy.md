# Handover Policy

Governs the creation, population, and closure of session handover documents. A handover is a session log — it records what was done and what comes next, with enough fidelity that a new agent can continue without reconstructing state from the session history.

A handover is not a document. It is not subject to `documentation_policy.md`. It is ephemeral by design.

---

## Purpose

The handover serves two agents: the one closing the current session, and the one opening the next. It is written for the second agent, not the first.

A well-written handover means the next session starts oriented. A missing or incomplete handover means the next session starts by reconstructing state — reading the roadmap, re-reading discussion documents, inferring what was decided. That reconstruction is waste. The handover eliminates it.

---

## File Naming Standard

```
YYYYMMDD-NN-TYPE-description_handover.md
```

| Component | Rule |
|---|---|
| `YYYYMMDD` | Session date |
| `NN` | Two-digit session index, reset daily. Derived at session start: list existing handovers for today's date, take `max + 1`. First session of the day is `01`. |
| `TYPE` | Session type shortform (see table below) |
| `description` | Brief task description. Use underscores for spaces and periods. No other special characters. |

Example: `20260316-02-workflow-policy_audit_handover.md`

Stored at the repo root alongside `agent_context_brief.md`. One file per session. Do not overwrite previous handovers — they are the session log for the milestone. The most recent date and highest index is the active handover.

---

## Session Types

Each session has a type that reflects its dominant activity. The type appears in the handover header and in the filename shortform.

| Session type | Shortform | Scope |
|---|---|---|
| Design | `design` | Minor loop Step 2 + Step 3 (design and conceptual docs) |
| Spec | `spec` | Minor loop Step 4 + Step 5 (spec and architecture docs) |
| Implementation | `impl` | Minor loop Step 8 |
| Story | `story` | Major loop — problem framing |
| Investigation | `study` | Major loop — candidate evaluation |
| Planning | `plan` | Major loop — milestone scoping |
| Workflow | `workflow` | Policy changes, governance, audit |
| Housekeeping | `chore` | Stale links, linting, index cleanup |

---

## Lifecycle

A handover has three moments:

**Open** — created at the start of a session (Step 1 of the minor loop). Populated from the roadmap entry for the target sub-milestone and from the prior handover if one exists.

**Active** — updated throughout the session as tasks complete, decisions are made, and scope changes are noted.

**Closed** — finalised at session end (Steps 9a and 9b of the minor loop). Records what was completed, marks deferrals explicitly, and seeds the next session.

---

## Format

```markdown
# Agent Handover

**Session date:** YYYY-MM-DD
**Milestone:** <sub-milestone ID and name — e.g. M2.1 — General Capability Layer Prototype>
**Session type:** <Design | Spec | Implementation | Story | Investigation | Planning | Workflow | Housekeeping>

## Objective
<One sentence: what this session is trying to achieve. Copied from the roadmap entry.>

## Open design questions
<Questions that must be resolved before the session can advance to spec.
If none, write the canonical marker.>

None.

## Task list
<Copied from the roadmap entry at session open. Updated as tasks complete.

Group tasks by functional change area — a short heading that names the capability or mechanism
being built, followed by the file-level items that deliver it. Each item identifies a file and
a nature of change, or a discussion that must occur.

Order groups by dependency: implementation groups first (in dependency order among themselves),
documentation and index updates after all implementation groups, validation last. This mirrors
the iteration policy sequence: implementation → documentation → acceptance.>

### <Capability or mechanism name>
- [ ] <file — nature of change>
- [x] <completed item>

### Documentation updates
- [ ] <file — nature of change>

### Validation
- [ ] <acceptance test step>

## Hot files
<Files in scope for this session. Each entry is a markdown link with a one-line note on why it
is in scope. Populated at Step 1 from the task list. Updated at Step 9a as tasks complete or
new files enter scope.>

| File | Why in scope |
|---|---|
| [`path/to/file.md`](path/to/file.md) | <one-line reason> |

## Decisions made this session
<Table: decision | rationale | where recorded. If none, write the canonical marker.>

None.

## Acceptance criteria
<What the operator will run or observe to confirm the implementation is correct.
Added at Step 7. If not yet defined, write the canonical marker.>

Not yet defined.

## Completed this session
<Table: file | one-line change summary. If no files changed, write the canonical marker.>

No file changes this session.

## Deferred items
<Items that were in scope but are not complete. Each item must have an explicit reason for
deferral and a note on where it goes next. If nothing is deferred, write the canonical marker.>

None.

## Next session
<Sub-milestone ID and name for the next session.>
<Known open questions or watch-out items the next agent should read first.>
<Grep or file reads to run at session start, if known.>
```

---

## Canonical Null Markers

When a section has nothing to record, write the canonical marker and nothing else. Do not explain why the section is empty — if a decision was made that affects the section, record it in the Decisions table or the relevant document.

| Section | Canonical marker |
|---|---|
| Open design questions | `None.` |
| Decisions made this session | `None.` |
| Acceptance criteria | `Not yet defined.` |
| Completed this session | `No file changes this session.` |
| Deferred items | `None.` |

Explanation of *why* a section is empty is noise. "None — design confirmed. Implementation-time decisions are task list items, not open design questions." says nothing a reader needs. `None.` says everything.

---

## Population Rules

### At session open (Step 1)

- Copy the milestone ID and objective from the roadmap entry verbatim.
- Copy the task list from the roadmap entry. Group by functional change area with a short heading per group. Order groups: implementation first (in dependency order), documentation and index updates after, validation last. If the task list in the roadmap is ungrouped, apply grouping when copying into the handover.
- If the task list is incomplete (the sub-milestone was not fully scoped), note this explicitly in Open design questions and treat the design step as mandatory.
- Read the prior handover if one exists. Transfer any deferred items into the current task list or open questions section. Do not re-litigate deferred decisions — they are recorded where they were made.
- Populate the Hot files section: for each task list item that identifies a file, add a markdown link and a one-line reason. Files that are warm (referenced but not expected to change) may be listed with a note.
- Set Session type to the dominant activity expected this session.
- For all nullable sections with nothing yet to record, write the canonical marker — not a blank section, not an explanation.

### During the session

- Mark tasks complete as they are confirmed by the operator — not when they are produced.
- Record decisions in the Decisions table as they are made, with the document where the decision was recorded. If a decision is only in chat, it does not exist for the next session.
- Update Deferred items immediately when something is flagged out of scope — do not accumulate them at session end.

### At session close (Step 9a)

- Every task in the task list must be either checked or deferred with a reason. No task is silently dropped.
- The Completed this session table must be accurate. One row per file changed. If no files changed, write the canonical marker.
- Update the Hot files section: mark completed files or remove them; add any files that entered scope during the session.
- The Deferred items section must be complete before the handover is considered closed. If nothing is deferred, write the canonical marker.

### At session seed (Step 9b)

- Identify the next sub-milestone from the roadmap.
- Populate Next session with enough orientation that the next agent does not need to read this session's history.
- If the completed sub-milestone was the last in the major milestone, write "Major loop required before next session" in Next session and leave the sub-milestone ID blank.

---

## Rules

- **Decisions in chat do not exist.** If a decision was made in conversation but not recorded in a document and noted in the Decisions table, it will not survive the session boundary.
- **Completed means confirmed.** A task is checked only after the operator has reviewed and confirmed the output — not when the agent has produced it.
- **Deferrals are explicit.** "We ran out of time" is not a deferral reason. The reason must name the blocker: dependency, open question, scope change, operator decision.
- **The handover is not a summary of decisions.** Decisions live in the documents where they were made. The handover points to those documents — it does not reproduce their content.
- **Next session watch-out items are capped at three.** More than three is a signal the session was not scoped tightly enough. Excess items belong in the relevant document, not the handover.
- **Empty sections use canonical markers.** A blank section is ambiguous — it could mean nothing to record, or a forgotten section. Write the canonical marker. Never leave a nullable section blank and never explain why it is empty.

---

## References

| Document | Purpose |
|---|---|
| [`iteration_policy.md`](iteration_policy.md) | Session workflow — when handover is created, updated, and closed |
| [`roadmap_policy.md`](roadmap_policy.md) | Roadmap update rules — task checkbox discipline |
