# Handover Policy

**Role:** This document defines the content rules for session handover files — what constitutes a valid handover, field by field, across the handover lifecycle. For the operational workflow (when to populate each field, step sequencing, gates), see [`iteration_policy.md`](iteration_policy.md).

Governs the creation, population, and closure of session handover documents. A handover is a session log — it records what was done and what comes next, with enough fidelity that a new agent can continue without reconstructing state from the session history.

A handover is not a document. It is not subject to `documentation_policy.md`. It is a session log — committed alongside other session changes, retained for the life of the milestone, and read-only once closed. It does not describe the system; it describes the session. This is what "ephemeral" means here: it is not a reference document. It does not mean excluded from version control or from packaging.

---

## Purpose

The handover serves two agents: the one closing the current session, and the one opening the next. It is written for the second agent, not the first.

A well-written handover means the next session starts oriented. A missing or incomplete handover means the next session starts by reconstructing state — reading the roadmap, re-reading discussion documents, inferring what was decided. That reconstruction is waste. The handover eliminates it.

## Brevity

- Implementation steps (file-by-file changes, edit descriptions) belong in git commits, not handovers.
- `Completed this session` table: one line per file — what changed and why. Not every edit within the file.
- `Acceptance criteria`: one observable delta per criterion. If verification requires reading the handover, the criterion is too detailed.
- `Hot files`: one-line reason per file. If it duplicates the Objective or Scope, it is redundant.

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

Stored in the `devlog/handovers/` directory. One file per session. Do not overwrite previous handovers — they are the session log for the milestone. The most recent date and highest index is the active handover.

---

## Session Types

Each session has a type that reflects its dominant activity. The type appears in the handover header and in the filename shortform.
Each session type (Eg. workflow vs implementation) must declare its scope independently. Do not inherit objectives, acceptance criteria, or task completion status from prior sessions of different types. 

| Session type | Shortform | Scope |
|---|---|---|
| Design | `design` | Minor loop Steps 3 + 4 (design and information gathering) |
| Spec | `spec` | Minor loop Step 4 (information gathering pass — focused on spec and architecture docs) |
| Implementation | `impl` | Minor loop Step 6 |
| Story | `story` | Major loop — problem framing |
| Investigation | `study` | Major loop — candidate evaluation |
| Planning | `plan` | Major loop — milestone scoping |
| Workflow | `workflow` | Policy changes, governance, audit |
| Housekeeping | `chore` | Stale links, linting, index cleanup |

---

## Lifecycle

A handover has three states:

**Open** — created at session start (`iteration_policy.md` §Step 1). Populated from the roadmap entry for the target sub-milestone and from the prior handover if one exists. The prior handover's Status header must be verified; if it is not "Closed", the previous session may have ended prematurely and require recovery.

**Active** — updated throughout the session as tasks complete, decisions are made, and scope changes are noted. The Status header is set to "Active".

**Closed** — finalised at session end (`iteration_policy.md` §Steps 8–9). Records what was completed, marks deferrals explicitly, and seeds the next session. The Status header is set to "Closed".

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
item, with a reference to the handover it came from. Populated per `iteration_policy.md` §Step 1
from the prior handover's Deferred items. If nothing was carried forward, write the canonical marker.>

| Item | From handover |
|---|---|
| <deferred item description> | <YYYYMMDD-NN-TYPE-description> |

## Acceptance criteria
<Every AC describes a delta: something observable that was false or absent before the session and true or present after it. The operator verifies by running the system — never by reading source alone.

For bugfixes, the delta is implicit: "error X no longer appears in command Y's output." The original error log or test failure is the requirement anchor — write the AC as a pass/fail check that asserts the error is gone.

For features or reworks, the delta traces to a specific story pain point, requirement, or design decision. If the AC cannot be traced to something concrete (a story entry, a design record, a reported pain), it is likely not needed.

Verification preference order: unit test > integration test > manual script > operator-run command with documented expected output. Use the minimal level that reliably asserts the delta. Manual verification is acceptable when automation is impractical.

AC-level guidelines:
- **Rename or delete:** include a paired negative check ("old path does not exist") alongside the positive check ("new path exists"). Both required.
- **Rename companion files:** after defining the production ACs, grep for companion files (tests, knowledge tests, fixtures) matching the old path pattern and include or defer explicitly.
- **Regression guard (bugfix only):** when the bug represents a recurring class — a bash trap, a common mis-pattern, something review often misses — add a generic guard (one repo-wide grep for all .sh files, not a per-file test). One-off logic errors do not need one.

At session close, mark each criterion as accepted or pushed to next session. Both visible.>

Not yet defined.

## Hot files
<Files in scope for this session. Each entry is a markdown link with a one-line note on why it
is in scope. Populated per `iteration_policy.md` §Step 1 from the roadmap task list. Updated
per `iteration_policy.md` §Steps 8–9 as tasks complete or new files enter scope.>

| File | Why in scope |
|---|---|
| [`path/to/file.md`](path/to/file.md) | <one-line reason> |

## Decisions made this session
<Table: decision | rationale | where recorded. If none, write the canonical marker.>

None.

## Mid-session findings
<Append-only. Written immediately when something changes the plan: a bug or contradiction
discovered, steering received from the operator, a blocker encountered, or a new file
entering scope. Do not log routine reads or completed tasks here — only write when something
changes what you are doing or what the next session needs to know. Triaged into the proper
sections at session close.>

| Finding | Type | Impact |
|---|---|---|
| <description> | bug / contradiction / steering / blocker / scope change | current unit / next unit / next session / roadmap |

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
<Whether Trigger B has been run or is pending — omit if mid-milestone and no sub-milestone just completed.>
<Blocking design questions the next agent must resolve before advancing.>
<Known watch-out items (capped at three).>
<Grep or file reads to run at session start, if known.>

**Conclusions from this session:** decisions made, approaches confirmed, dead ends ruled out. Not a full log — only what would otherwise be re-derived from scratch. Omit if nothing was concluded beyond what is in the Decisions table.
```

---

## Canonical Null Markers

When a section has nothing to record, write the canonical marker and nothing else. Do not explain why the section is empty — if a decision was made that affects the section, record it in the Decisions table or the relevant document. The agent must not leave a nullable section blank and must not explain why it is empty.

| Section | Canonical marker |
|---|---|
| Acceptance criteria | `Not yet defined.` |
| Decisions made this session | `None.` |
| Mid-session findings | `None.` |
| Completed this session | `No file changes this session.` |
| Deferred items | `None.` |
| Carried forward | `None.` |

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
5. **Findings triage — if the correction surfaces a new finding** (a compatibility gap, a regression, a policy violation, a missing task, or any issue that changes what the next session or future sessions need to know), the finding must be routed to its correct destination before the correction is finalised. Use the same triage criteria as the session close mid-session findings gate (`iteration_policy.md` §Steps 8–9):

   - If the finding belongs in the active handover (the current session's handover), add it to Mid-session findings there.
   - If the finding represents a new task, write it as a named entry in `roadmap.md` under the current sub-milestone.
   - If the finding is a deferred item for the next session, add it to Deferred items in the active handover.
   - If the finding is purely documentary (e.g. a known-limitation note), update the relevant document directly.

   The correction block must document where the finding was routed (e.g. `Finding routed to roadmap.md item 13 — autosave reliability.`).

6. Propose the amended document to the operator for review. Do not self-commit.

### What this is not

A correction to a closed handover is not a substitute for a new handover. If the session requires new work, create a new handover first. The correction procedure applies only to errors in the record — not to work that was omitted or deferred.

---

## Related Skills

Skills and prompt templates that encode this policy. When this document is revised, these must be checked for drift.

| Skill / Prompt | Purpose |
|---|---|
| [`agent/prompts/new-session.md`](../agent/prompts/new-session.md) | Session open — handover creation, recovery checks, scope/AC gates |
| [`agent/drafts/roadmap-audit.skill.md`](../agent/drafts/roadmap-audit.skill.md) | Roadmap format compliance, compaction audits |
| [`agent/drafts/handover-audit.skill.md`](../agent/drafts/handover-audit.skill.md) | Handover format compliance — validates content rules defined here |

Policy documents that this document depends on:

| Policy | Relationship |
|---|---|
| [`roadmap_policy.md`](roadmap_policy.md) | Trigger B reference, compaction rules |
| [`iteration_policy.md`](iteration_policy.md) | Operational workflow — governs when handover fields are populated |
| [`documentation_policy.md`](documentation_policy.md) | Post-close document corrections |

---

## Child Documents

| Document | Governs |
|---|---|
| [`milestone_policy.md`](milestone_policy.md) | Major loop: milestone planning, story and investigation process |
| [`story_policy.md`](story_policy.md) | Story lifecycle: creation, investigation trigger, graduation, closure |
| [`study_policy.md`](study_policy.md) | Study lifecycle: structure, states, recommendation, closure |
| [`handover_policy.md`](handover_policy.md) | Handover content rules: valid field states, null markers, format conventions, correction procedure |

---

## References

| Document | Purpose |
|---|---|
| [`iteration_policy.md`](iteration_policy.md) | Operational workflow — when handover is created, updated, and closed |
| [`roadmap_policy.md`](roadmap_policy.md) | Roadmap update rules — task checkbox discipline and Trigger B |
