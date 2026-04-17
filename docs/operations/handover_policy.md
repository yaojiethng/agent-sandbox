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
| `description` | The specific subject of this session — what is being built, changed, or investigated. Name the concrete thing, not a restatement of the type. Use underscores for spaces and periods. No other special characters. A reader scanning a list of handover filenames should be able to distinguish this session from others of the same type without opening the file. Bad: `policy_audit`, `m2_3_impl`, `scope_confirm`. Good: `scope_gate_and_preclose_verification`, `snapshot_baseline_git_init`, `provider_config_copyout`. |

Example: `20260316-02-workflow-scope_gate_and_preclose_verification.md`

Stored in the `docs/devlog/handovers/` directory. One file per session. Do not overwrite previous handovers — they are the session log for the milestone. The most recent date and highest index is the active handover.

---

## Session Types

Each session has a type that reflects its dominant activity. The type appears in the handover header and in the filename shortform.
Each session type (Eg. workflow vs implementation) must declare its scope independently. Do not inherit objectives, acceptance criteria, or task completion status from prior sessions of different types. 

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

**Open** — created at the start of a session (Step 1 of the minor loop). Populated from the roadmap entry for the target sub-milestone and from the prior handover if one exists. **The agent must check the Status header of the previous handover; if it is not "Closed", the previous session may have ended prematurely and require recovery.**

**Active** — updated throughout the session as tasks complete, decisions are made, and scope changes are noted. The Status header is set to "Active".

**Closed** — finalised at session end (Steps 8 and 9 of the minor loop). Records what was completed, marks deferrals explicitly, and seeds the next session. The Status header is set to "Closed".

---

## Format

```markdown
# Agent Handover

**Session date:** YYYY-MM-DD
**Milestone:** <sub-milestone ID and name — e.g. M2.1 — General Capability Layer Prototype>
**Session type:** <Design | Spec | Implementation | Story | Investigation | Planning | Workflow | Housekeeping>
**Status:** <Active | Closed>

## Objective
<One sentence: what this session is trying to achieve. Scoped to the session, not the sub-milestone.>

## Scope
<Which task groups or tasks from the roadmap this session targets. Reference by group name;
do not copy the task list. If design questions are blocking, list them explicitly as blockers.>

## Carried forward
<Items explicitly deferred from the prior session that this session is picking up. One row per
item, with a reference to the handover it came from. Populated at Step 1 from the prior
handover's Deferred items. If nothing was carried forward, write the canonical marker.>

| Item | From handover |
|---|---|
| <deferred item description> | <YYYYMMDD-NN-TYPE-description> |

## Acceptance criteria
<Criteria carried from prior session + any defined this session. Each criterion is an operator-runnable check — an action or command, expected output or behaviour, and pass/fail condition. Not file state. At session close, mark each as accepted or pushed to next session. Both must be visible under this header.>

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
<Whether Trigger B has been run or is pending — omit if mid-milestone.>
<Blocking design questions the next agent must resolve before advancing.>
<Known watch-out items (capped at three).>
<Grep or file reads to run at session start, if known.>
```

---

## Canonical Null Markers

When a section has nothing to record, write the canonical marker and nothing else. Do not explain why the section is empty — if a decision was made that affects the section, record it in the Decisions table or the relevant document. The agent must not leave a nullable section blank and must not explain why it is empty.

| Section | Canonical marker |
|---|---|
| Acceptance criteria | `Not yet defined.` |
| Decisions made this session | `None.` |
| Completed this session | `No file changes this session.` |
| Deferred items | `None.` |
| Carried forward | `None.` |

Explanation of *why* a section is empty is noise. "None — design confirmed. Implementation-time decisions are task list items, not open design questions." says nothing a reader needs. `None.` says everything.

---

## Population Rules

### At session open (Step 1)

- **Create a new handover — never modify a closed one.** The most recent handover in `docs/devlog/handovers/` belongs to the previous session. If its Status is `Closed`, it is a read-only record. Do not edit it, do not reopen it, do not update its fields. Create a new file with today's date and the next sequential index. The prior handover is source material only — read it for context, then leave it untouched.
- **Trigger B recovery check:** if the prior handover's Next session names a different sub-milestone than the one currently active in `roadmap.md`, [Trigger B](roadmap_policy.md#sub-milestone-close-trigger-b) has not run. Run it now before compacting or creating this handover.
- **Compaction check:** compact any fully-completed task groups from the previous session in `roadmap.md` per [`roadmap_policy.md`](roadmap_policy.md#session-open-step-1). A task group is fully complete when every item in it is checked. If no groups are fully complete, note this explicitly. **The Hot files section must not be populated until this step is confirmed done or declared not applicable.**
- Write the session objective — what this session will achieve, scoped to the session type and step range.
- Write the Scope section: reference the roadmap task groups this session targets by name. If design questions are blocking, list them explicitly as blockers. Do not copy task items or carry checkbox state from the prior handover — the roadmap is the task list.
- Read the prior handover if one exists. Populate the Carried forward section: for each item in the prior handover's Deferred items that is destined for this session, add a row with the item description and the prior handover filename. Transfer acceptance criteria that were explicitly pushed to this session. Do not re-litigate deferred decisions — they are recorded where they were made.
- Reset the Completed this session table to the null marker. It records only files changed in the current session — never carried from a prior handover.
- Populate the Hot files section: for each task in the roadmap groups targeted this session, add a markdown link and a one-line reason.
- Set Session type to the dominant activity expected this session.
- For all nullable sections with nothing yet to record, write the canonical marker — not a blank section, not an explanation.

### At scope confirmation (Step 1b)

After the handover draft is complete, present a scope proposal in chat and wait for operator confirmation before producing any file, code, or structural output. This gate applies to every session type without exception.

**If sufficient context is available** (handover and roadmap uploaded, task list readable), present the proposal directly. Cover:

- What the agent proposes to attempt this session, and why each item is in scope now (dependency order, available context, estimated size)
- What the agent is explicitly deferring from the roadmap task list, and why (too large for one session, blocked on missing context, depends on a prior group not yet complete)
- Any questions that must be resolved before the first task can begin

For housekeeping sessions, the scope proposal may simply be the target file list and the nature of the change — that is sufficient. The gate still applies; the operator must confirm before work begins.

**If context is insufficient** (key files missing, roadmap task list unclear, prior handover not uploaded), do not guess at scope. Instead, ask the operator one question at a time to establish what is needed:
- Which sub-milestone or task group is the target?
- Which files are available or need to be uploaded?
- Are there any constraints or priorities the operator wants applied this session?

Continue the interview until a scope proposal can be made, then present it and wait for confirmation.

**Exit condition:** Operator has confirmed the scope proposal in chat. The Scope section of the handover is updated to reflect the confirmed scope before proceeding.

**Rule:** No output before scope is confirmed.

### During the session

- Record decisions in the Decisions table as they are made, with the document where the decision was recorded. If a decision is only in chat, it does not exist for the next session.
- Record new acceptance criteria as they are defined. Pushed (unresolved) criteria from prior sessions are already present in the handover from session open — do not re-copy them.
- Update Deferred items immediately when something is flagged out of scope — do not accumulate them at session end.

### At Step 6 — Define acceptance criteria

- Replace `Not yet defined.` with the confirmed criteria before the step exits. The null marker must not be present when implementation begins — a session that enters Step 7 with `Not yet defined.` in place has skipped the gate.

### At session close (Step 8)

- Mark completed tasks in `roadmap.md` per [`roadmap_policy.md`](roadmap_policy.md#session-close-step-8). This is done alongside the handover update, not after it.
- If all sub-milestone tasks are now complete and acceptance criteria are met, run [Trigger B](roadmap_policy.md#sub-milestone-close-trigger-b) before closing the handover.
- The Completed this session table must be accurate. One row per file changed. If no files changed, write the canonical marker.
- Mark each acceptance criterion as accepted or pushed to next session. Both must be visible under the Acceptance criteria header.
- Update the Hot files section: mark completed files or remove them; add any files that entered scope during the session.
- **Scope reconciliation — do this before writing anything else in Step 8.** Compare the confirmed scope from Step 1b against the Completed this session table. Every item that was in scope but is not in Completed must appear in Deferred items. There must be no unaccounted items — if something was attempted but not finished, it is deferred; if it was never started, it is deferred; if it was descoped mid-session, it is deferred with the reason. The Deferred items section is not complete until this check passes.
- For each deferred item, record: what it is, why it did not complete this session, and where it goes next (next session, a specific future sub-milestone, or `roadmap_future.md`). If nothing is deferred, write the canonical marker.

### At session seed (Step 9)

- Identify the next session's scope from two sources: the roadmap task list, and the Deferred items just written in Step 8. Deferred items take priority — they represent work already started or committed to that must not be silently dropped.
- If this was the final session of a sub-milestone, note in Next session whether [Trigger B](roadmap_policy.md#sub-milestone-close-trigger-b) has been run or is pending. This is the signal the next session uses in its Step 1 recovery check.
- List any blocking design questions explicitly — these are not general notes, they are concrete blockers the next agent must resolve before advancing.
- Populate Next session with enough orientation that the next agent does not need to read this session's history. **This section is written for the next agent, not the current one — it is source material for that agent's Step 1, not a continuation directive. The next agent will create its own handover before acting on anything written here.**
- If the completed sub-milestone was the last in the major milestone, write "Major loop required before next session" in Next session and leave the sub-milestone ID blank.
- **If this session supersedes a prior implementation handover** (e.g., a workflow or chore session interrupting an implementation sequence), include a **Context handover** line in Next session with a markdown link to the last relevant implementation handover. This gives the next agent a direct path to load full context without reconstructing from the handover chain. Example:
  ```markdown
  Context handover: [`20260416-01-impl-snapshot-baseline.md`](handovers/20260416-01-impl-snapshot-baseline.md)
  ```

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

## Corrections to Closed Handovers

Closed handovers are read-only records with one exception: documented corrections applied under the post-close correction policy (`docs/operations/documentation_policy.md` — Post-Close Document Corrections).

### When to apply

Apply a correction when a factual error is found in the document — an incorrect status, a wrong filename, a misrecorded decision. Do not apply a correction to add new information, change scope, or extend the session record. New session work belongs in a new handover.

### Procedure

1. Identify the error and its location in the document.
2. Edit the affected text in the body directly. If the error requires context, add a brief inline note: `[see correction below]`.
3. Append a dated amendment block at the bottom of the document:

```
---
[CORRECTION — YYYY-MM-DD]: <description of what was wrong and what was changed>
```

4. Do not alter the document's Status, timestamps, or any other metadata field.
5. Propose the amended document to the operator for review. Do not self-commit.

### What this is not

A correction to a closed handover is not a substitute for a new handover. If the session requires new work, create a new handover first. The correction procedure applies only to errors in the record — not to work that was omitted or deferred.

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
| [`iteration_policy.md`](iteration_policy.md) | Session workflow — when handover is created, updated, and closed |
| [`roadmap_policy.md`](roadmap_policy.md) | Roadmap update rules — task checkbox discipline and Trigger B |
