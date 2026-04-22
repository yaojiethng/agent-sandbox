# Handover Policy

Governs the creation, population, and closure of session handover documents. A handover is a session log — it records what was done and what comes next, with enough fidelity that a new agent can continue without reconstructing state from the session history.

A handover is not a document. It is not subject to `documentation_policy.md`. It is ephemeral by design.

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

A handover moves through three states — `Active` (open, in progress) and `Closed` (finalised at session end) — governed by the Population Rules below. **If the prior handover's Status is not `Closed`, the previous session ended prematurely and requires recovery before this session begins.**

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
- **Compaction check:** compact any fully-completed task groups in `roadmap.md` per [`roadmap_policy.md`](roadmap_policy.md#session-open-step-1). A task group is fully complete when every item is checked. Note explicitly if no groups qualify. **Populate Hot files only after this step is confirmed done or declared not applicable.**
- Write the session objective and Scope section: reference roadmap task groups by name; list any blocking design questions. Do not copy task items from the prior handover — the roadmap is the task list.
- Read the prior handover if one exists. Populate Carried forward: one row per deferred item destined for this session, with the source handover filename. Transfer AC explicitly pushed to this session. Reset Completed this session to the null marker — it records only this session's file changes.
- Populate Hot files: one markdown link and one-line reason per task in the targeted roadmap groups.
- For all nullable sections with nothing yet to record, write the canonical marker — not a blank, not an explanation.

### At scope confirmation (Step 1b)

After the handover draft is complete, present a scope proposal in chat and wait for operator confirmation before producing any file, code, or structural output. This gate applies to every session type without exception.

**If context is sufficient** (handover and roadmap readable, task list clear), present the proposal directly. Cover: what is in scope and why, what is explicitly deferred and why, and any blocking questions.

**If context is insufficient** (key files missing, task list unclear, prior handover not uploaded), do not guess at scope. Ask the operator one question at a time until a proposal can be made.

**Exit condition:** Operator has confirmed the scope proposal and sent an explicit release. The Scope section of the handover is updated to reflect confirmed scope before any output is produced.

### During the session

- Record decisions in the Decisions table as they are made, with the document where the decision was recorded. If a decision is only in chat, it does not exist for the next session.
- Record new acceptance criteria as they are defined. Pushed (unresolved) criteria from prior sessions are already present in the handover from session open — do not re-copy them.
- Update Deferred items immediately when something is flagged out of scope — do not accumulate them at session end.

### At Step 6 — Define acceptance criteria

- Replace `Not yet defined.` with the confirmed criteria before the step exits. The null marker must not be present when implementation begins — a session that enters Step 7 with `Not yet defined.` in place has skipped the gate.

### At pre-close verification (Step 7b)

Step 7b is a mandatory gate before session close. The agent presents a pre-close summary and waits for an explicit operator release before advancing to Step 8.

**For any session that touched multiple files under a shared rule or naming convention**, the pre-close summary must include a propagation replay table — a row-by-row comparison of every file that was planned to receive the change against the Completed this session table:

| File | Change planned | Status |
|---|---|---|
| `path/to/file.md` | `<what was supposed to change>` | `completed` / `deferred` / `not started` |

Every row must have a status. A row with status `deferred` or `not started` must appear in the Deferred items section before the gate closes. The operator cannot release Step 7b while any row is unresolved.

**A propagation replay is required when any of the following apply:**
- The session applied a naming rule, structural rule, or interface change across more than two files
- The spec produced an explicit file table at Step 4
- The task description used language like "all", "every", "throughout", or "wherever X appears"

**When a propagation replay is not required**, the pre-close summary covers: what was built, tests produced, AC status per criterion, and recommended manual checks.

The operator releases this gate with an explicit forward signal (e.g. "proceed", "close the session"). A message that reviews output without a clear forward signal does not satisfy the exit condition. Packaging changes (e.g. `/package-diff`) does not release this gate — session-close actions do not begin until the operator explicitly confirms after testing.

### At session close (Step 8)

- Mark completed tasks in `roadmap.md` and update `project_index.md` per [`roadmap_policy.md`](roadmap_policy.md#session-close-step-8).
- If all sub-milestone tasks are now complete and acceptance criteria are met, run [Trigger B](roadmap_policy.md#sub-milestone-close-trigger-b) before closing the handover.
- The Completed this session table must be accurate. One row per file changed. If no files changed, write the canonical marker.
- Mark each acceptance criterion as accepted or pushed to next session. Both must be visible under the Acceptance criteria header.
- Update the Hot files section: mark completed files or remove them; add any files that entered scope during the session.
- **Scope reconciliation — do this first.** Compare confirmed scope from Step 1b against the Completed this session table. Every in-scope item not in Completed must appear in Deferred items with a reason and a destination (next session, a specific future sub-milestone, or `roadmap_future.md`). No unaccounted items. If nothing is deferred, write the canonical marker.

  **Deferral eligibility:** only items that were in scope but deliberately not attempted this session may be deferred. Problems introduced by this session's own changes — broken links, inconsistencies, regressions — are not deferrals. They must be resolved before the session closes.

### At session seed (Step 9)

- Identify next session scope from the roadmap task list and the Deferred items just written. Deferred items take priority.
- If this was the final session of a sub-milestone, note whether [Trigger B](roadmap_policy.md#sub-milestone-close-trigger-b) has run or is pending.
- List blocking design questions explicitly — concrete blockers the next agent must resolve before advancing, not general notes.
- Populate Next session for the next agent, not the current one. It is source material for that agent's Step 1; the next agent will create its own handover before acting on it.
- If the completed sub-milestone was the last in the major milestone, write "Major loop required before next session."
- **If this session supersedes a prior implementation handover** (e.g. a workflow or chore session interrupting an implementation sequence), include a Context handover line in Next session:
  ```markdown
  Context handover: [`20260416-01-impl-snapshot-baseline.md`](handovers/20260416-01-impl-snapshot-baseline.md)
  ```

---

## Corrections to Closed Handovers

Closed handovers are read-only records. For the correction procedure, see [`documentation_policy.md` — Post-Close Document Corrections](documentation_policy.md#post-close-document-corrections).

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
