# Handover Policy

Governs the creation, population, and closure of session handover documents. A handover is a session log — it records what was done and what comes next, with enough fidelity that a new agent can continue without reconstructing state from the session history.

A handover is not a document. It is not subject to `documentation_policy.md`. It is ephemeral by design.

---

## Purpose

The handover serves two agents: the one closing the current session, and the one opening the next. It is written for the second agent, not the first.

A well-written handover means the next session starts oriented. A missing or incomplete handover means the next session starts by reconstructing state — reading the roadmap, re-reading discussion documents, inferring what was decided. That reconstruction is waste. The handover eliminates it.

---

## File Naming

```
YYYYMMDD_agent_handover.md
```

Stored at the repo root alongside `agent_context_brief.md`. One file per session. Do not overwrite previous handovers — they are the session log for the milestone. The most recent date is the active handover.

If two sessions occur on the same date, append a suffix: `YYYYMMDD_b_agent_handover.md`.

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
**Session type:** <Design | Spec | Implementation | Documentation | Housekeeping | Investigation>

## Objective
<One sentence: what this session is trying to achieve. Copied from the roadmap entry.>

## Open design questions
<Any questions that must be resolved before the session can advance to spec.
If none, write "None — design confirmed." Do not leave this section blank.>

## Task list
<Copied from the roadmap entry at session open. Updated as tasks complete.
Format: checkbox list. Each item identifies a file and a nature of change, or a discussion that must occur.>

- [ ] <file or discussion — nature of change>
- [x] <completed item>

## Hot files
<Files in scope for this session. Each entry is a markdown link to the file, with a one-line note
on why it is in scope. Populated at Step 1 from the task list. Updated at Step 9a as tasks complete
or new files enter scope. This section replaces doc_status.md — it is the active file list
for the current session.>

| File | Why in scope |
|---|---|
| [`path/to/file.md`](path/to/file.md) | <one-line reason> |

## Decisions made this session
<Table: decision | rationale | where recorded>
If no decisions were made, write "No decisions this session."

| Decision | Rationale | Recorded in |
|---|---|---|

## Acceptance criteria
<Added at Step 7. What the operator will run or observe to confirm the implementation is correct.
If not yet defined, write "Not yet defined.">

## Completed this session
<Table: file | one-line change summary.
If no files changed, write "No file changes this session.">

| File | Change |
|---|---|

## Deferred items
<Anything that was in scope but is not complete. Each item must have an explicit reason for deferral
and a note on where it goes next (next session, next sub-milestone, flagged in roadmap).
If nothing is deferred, write "Nothing deferred.">

## Next session
<Sub-milestone ID and name for the next session.>
<Known open questions or watch-out items the next agent should read first.>
<Grep or file reads to run at session start, if known.>
```

---

## Population Rules

### At session open (Step 1)

- Copy the milestone ID and objective from the roadmap entry verbatim.
- Copy the task list from the roadmap entry. If the task list is incomplete (the sub-milestone was not fully scoped), note this explicitly and treat the design step as mandatory.
- Read the prior handover if one exists. Transfer any deferred items into the current task list or open questions section. Do not re-litigate deferred decisions — they are recorded where they were made.
- Populate the Hot files section: for each task list item that identifies a file, add a markdown link and a one-line reason. Files that are warm (referenced but not expected to change) may be listed with a note.
- Set Session type to the dominant activity expected this session.

### During the session

- Mark tasks complete as they are confirmed by the operator — not when they are produced.
- Record decisions in the Decisions table as they are made, with the document where the decision was recorded. If a decision is only in chat, it does not exist for the next session.
- Update Deferred items immediately when something is flagged out of scope — do not accumulate them at session end.

### At session close (Step 9a)

- Every task in the task list must be either checked or deferred with a reason. No task is silently dropped.
- The Completed this session table must be accurate. One row per file changed.
- Update the Hot files section: mark completed files or remove them; add any files that entered scope during the session.
- The Deferred items section must be complete before the handover is considered closed.

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
- **Watch-out items are capped at three.** More than three is a signal the session was not scoped tightly enough. Excess items belong in the relevant document, not the handover.

---

## References

| Document | Purpose |
|---|---|
| [`iteration_policy.md`](iteration_policy.md) | Session workflow — when handover is created, updated, and closed |
| [`roadmap_policy.md`](roadmap_policy.md) | Roadmap update rules — task checkbox discipline |
