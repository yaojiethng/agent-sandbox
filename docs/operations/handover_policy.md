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
YYYYMMDD-NN-TYPE-description.md
```

| Component | Rule |
|---|---|
| `YYYYMMDD` | Session date |
| `NN` | Two-digit session index, reset daily. Derived at session start: list existing handovers for today's date, take `max + 1`. First session of the day is `01`. |
| `TYPE` | Session type shortform (see table below) |
| `description` | Brief task description. Use underscores for spaces and periods. No other special characters. |

Example: `20260316-02-workflow-policy_audit.md`

Stored in the `handovers/` directory at repo root. One file per session. Do not overwrite previous handovers — they are the session log for the milestone. The most recent date and highest index is the active handover.

---

## Session Types

Each session has a type that reflects its dominant activity. The type appears in the handover header and in the filename shortform.

| Session type | Shortform | Scope |
|---|---|---|
| Design | `design` | Minor loop Step 2 + Step 3 (design and conceptual docs) |
| Spec | `spec` | Minor loop Step 4 + Step 5 (spec and architecture docs) |
| Implementation | `impl` | Minor loop Step 7 |
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
<One sentence: what this session is trying to achieve. Scoped to the session, not the sub-milestone.>

## Scope
<Which task groups or tasks from the roadmap this session targets. Reference by group name;
do not copy the task list. If design questions are blocking, list them explicitly as blockers.>

## Acceptance criteria
<Criteria carried from prior session + any defined this session. At session close, mark each
as accepted or pushed to next session. Both must be visible under this header.>

Not yet defined.

## Hot files
<Files in scope for this session. Each entry is a markdown link with a one-line note on why it
is in scope. Populated at Step 1 from the roadmap task list. Updated at Step 8 as tasks
complete or new files enter scope.>

| File | Why in scope |
|---|---|
| [`path/to/file.md`](path/to/file.md) | <one-line reason> |

## Decisions made this session
<Table: decision | rationale | where recorded. If none, write the canonical marker.>

None.

## Completed this session
<Table: file | one-line change summary. If no files changed, write the canonical marker.>

No file changes this session.

## Deferred items
<Items that were in scope but are not complete. Each item must have an explicit reason for
deferral and a note on where it goes next (next session, different sub-milestone, or
roadmap_future.md). If nothing is deferred, write the canonical marker.>

None.

## Next session
<Sub-milestone ID and name for the next session.>
<Blocking design questions the next agent must resolve before advancing.>
<Known watch-out items (capped at three).>
<Grep or file reads to run at session start, if known.>
```

---

## Canonical Null Markers

When a section has nothing to record, write the canonical marker and nothing else. Do not explain why the section is empty — if a decision was made that affects the section, record it in the Decisions table or the relevant document.

| Section | Canonical marker |
|---|---|
| Acceptance criteria | `Not yet defined.` |
| Decisions made this session | `None.` |
| Completed this session | `No file changes this session.` |
| Deferred items | `None.` |

Explanation of *why* a section is empty is noise. "None — design confirmed. Implementation-time decisions are task list items, not open design questions." says nothing a reader needs. `None.` says everything.

---

## Population Rules

### At session open (Step 1)

- Write the session objective — what this session will achieve, scoped to the session type and step range.
- Write the Scope section: reference the roadmap task groups this session targets by name. If design questions are blocking, list them explicitly as blockers. Do not copy the roadmap task list.
- Read the prior handover if one exists. Transfer any acceptance criteria pushed to this session. Transfer any deferred items into the Scope or Deferred sections as appropriate. Do not re-litigate deferred decisions — they are recorded where they were made.
- Populate the Hot files section: for each task in the roadmap groups targeted this session, add a markdown link and a one-line reason.
- Set Session type to the dominant activity expected this session.
- For all nullable sections with nothing yet to record, write the canonical marker — not a blank section, not an explanation.

### During the session

- Record decisions in the Decisions table as they are made, with the document where the decision was recorded. If a decision is only in chat, it does not exist for the next session.
- Record new acceptance criteria as they are defined. Carry forward any criteria from prior sessions that remain in scope.
- Update Deferred items immediately when something is flagged out of scope — do not accumulate them at session end.

### At session close (Step 8)

- The Completed this session table must be accurate. One row per file changed. If no files changed, write the canonical marker.
- Mark each acceptance criterion as accepted or pushed to next session. Both must be visible under the Acceptance criteria header.
- Update the Hot files section: mark completed files or remove them; add any files that entered scope during the session.
- The Deferred items section must be complete before the handover is considered closed. For each deferred item, note where it goes: next session, a different sub-milestone, or `roadmap_future.md`. If nothing is deferred, write the canonical marker.

### At session seed (Step 9)

- Identify the next session's scope from the roadmap.
- List any blocking design questions explicitly — these are not general notes, they are concrete blockers the next agent must resolve before advancing.
- Populate Next session with enough orientation that the next agent does not need to read this session's history.
- If the completed sub-milestone was the last in the major milestone, write "Major loop required before next session" in Next session and leave the sub-milestone ID blank.

---

## Rules

- **Decisions in chat do not exist.** If a decision was made in conversation but not recorded in a document and noted in the Decisions table, it will not survive the session boundary.
- **Completed means confirmed.** A task is checked only after the operator has reviewed and confirmed the output — not when the agent has produced it.
- **Deferrals are explicit.** "We ran out of time" is not a deferral reason. The reason must name the blocker: dependency, open question, scope change, operator decision.
- **The handover is not a summary of decisions.** Decisions live in the documents where they were made (roadmap, architecture docs). The handover points to those documents — it does not reproduce their content.
- **The handover does not duplicate the task list.** The roadmap is the canonical task list. The handover's Scope section references roadmap task groups by name; its Completed section records what was done this session.
- **Acceptance criteria carry forward and are visibly resolved.** At session close, every criterion under the Acceptance criteria header is either marked accepted or explicitly pushed to next session. The operator must be able to see both outcomes without reading the prior handover.
- **Next session blockers are concrete.** Blocking design questions in the Next session section are specific questions the next agent must resolve, not general notes. Cap at three items total (blockers + watch-out items combined).
- **Empty sections use canonical markers.** A blank section is ambiguous — it could mean nothing to record, or a forgotten section. Write the canonical marker. Never leave a nullable section blank and never explain why it is empty.

---

## References

| Document | Purpose |
|---|---|
| [`iteration_policy.md`](iteration_policy.md) | Session workflow — when handover is created, updated, and closed |
| [`roadmap_policy.md`](roadmap_policy.md) | Roadmap update rules — task checkbox discipline |
