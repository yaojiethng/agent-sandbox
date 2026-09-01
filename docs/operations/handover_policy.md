# Handover Policy

**Role:** Defines handover content rules: valid field states, null markers, format, and the correction procedure. For the operational workflow (when to populate each field, step sequencing, gates), see [`iteration_policy.md`](iteration_policy.md).

A handover is a log describing the work done in the iteration: what was done and what comes next, with enough fidelity that a new agent can continue without reconstructing state from the iteration history.

A handover is not a document and is not subject to `documentation_policy.md`. It is committed with the iteration's changes, retained for the life of the milestone, and read-only once closed. It describes the iteration, not the system. This is what "ephemeral" means here: it is not a reference document. It does not mean excluded from version control or from packaging.

---

## Purpose

The handover serves two agents: the one closing the current iteration, and the one opening the next. It is written for the second agent, not the first.

A well-written handover orients the next iteration. A missing or incomplete handover forces the next iteration to reconstruct state -- reading the roadmap, re-reading discussion documents, inferring what was decided. That reconstruction is waste. The handover eliminates it.

## Brevity

- Implementation steps (file-by-file changes, edit descriptions) belong in git commits, not handovers.
- `Completed` table: one line per file -- what changed and why. Not every edit within the file.
- `Acceptance criteria`: one observable delta per criterion. If verification requires reading the handover, the criterion is too detailed.
- `Hot files`: one-line reason per file. If it duplicates the Objective or Scope, it is redundant.

---

## File Naming Standard

```
YYYYMMDD-NN-TYPE-description.md
```

| Component | Rule |
|---|---|
| `YYYYMMDD` | Date |
| `NN` | Two-digit per-day index, reset daily. Derived at iteration start: `max + 1` of today's handovers. First iteration of the day is `01`. |
| `TYPE` | Type shortform (see table below) |
| `description` | The specific subject of this iteration -- what is being built, changed, or investigated. Name the concrete thing, not a restatement of the type. Use underscores for spaces and periods. No other special characters. A reader scanning a list of handover filenames should be able to distinguish this iteration from others of the same type without opening the file. Bad: `policy_audit`, `m2_3_impl`, `scope_confirm`. Good: `scope_gate_and_preclose_verification`, `snapshot_baseline_git_init`, `provider_config_copyout`. |

Example: `20260316-02-workflow-scope_gate_and_preclose_verification.md`

Stored in the `devlog/handovers/` directory. One file per iteration. Do not overwrite previous handovers -- they are the iteration log for the milestone. The most recent date and highest index is the active handover.

---

## Types

Each iteration has a type that reflects its dominant activity. The type appears in the handover header and in the filename shortform.
Each iteration type (Eg. workflow vs implementation) must declare its scope independently. Do not inherit objectives, acceptance criteria, or task completion status from prior iterations of different types. 

| Type | Shortform | Scope |
|---|---|---|
| Design | `design` | Minor loop Steps 3 + 4 (design and information gathering) |
| Spec | `spec` | Prepare to land: check consistency between roadmap, handover, and docs; surface prefactors; map surface area. Output goes to the handover and roadmap -- no single-use document. |
| Implementation | `impl` | Minor loop Step 6 |
| Story | `story` | Major loop -- problem framing |
| Study | `study` | Major loop -- candidate evaluation |
| Planning | `plan` | Major loop -- milestone scoping |
| Workflow | `workflow` | Policy changes, governance, audit |
| Housekeeping | `chore` | Stale links, linting, index cleanup |

---

## Lifecycle

A handover has three states:

**Open** -- created at iteration start (`iteration_policy.md` [Step 1 Details](iteration_policy.md#step-1-open-handover)). Populated from the roadmap entry for the target sub-milestone and from the prior handover if one exists. The prior handover's Status header must be verified; if it is not "Closed", the previous iteration may have ended prematurely and require recovery.

**Active** -- updated throughout the iteration as tasks complete, decisions are made, and scope changes are noted. The Status header is set to "Active".

**Closed** -- finalised at iteration end (`iteration_policy.md` [Steps 8-9 Details](iteration_policy.md#steps-89-close-and-seed)). Records what was completed, marks deferrals explicitly, and seeds the next iteration. The Status header is set to "Closed".

---

## Format

```markdown
# Agent Handover

**Date:** YYYY-MM-DD
**Milestone:** <sub-milestone ID and name -- e.g. M2.1 -- General Capability Layer Prototype>
**Type:** <Design | Spec | Implementation | Story | Study | Planning | Workflow | Housekeeping>
**Status:** <Active | Closed>

## Objective
<One sentence: what this iteration achieves. Scoped to the iteration, not the sub-milestone.>

## Scope
<Which task groups or tasks from the roadmap this iteration targets. Reference by group name; do not copy the task list. If design questions are blocking, list them explicitly as blockers.>

## Carried forward
<Items explicitly deferred from the prior iteration that this iteration is picking up. One row per item, with a reference to the handover it came from. Populated per `iteration_policy.md` Step 1 from the prior handover's Deferred items. If nothing was carried forward, write the canonical marker.>

| Item | From handover |
|---|---|
| <deferred item description> | <YYYYMMDD-NN-TYPE-description> |

## Acceptance criteria
<Every AC describes a delta: something observable that was false or absent before the iteration and true or present after it. The operator verifies by running the system -- never by reading source alone.

For bugfixes, the delta is implicit: "error X no longer appears in command Y's output." The original error log or test failure is the requirement anchor -- write the AC as a pass/fail check that asserts the error is gone.

For features or reworks, the delta traces to a specific story pain point, requirement, or design decision. If the AC cannot be traced to something concrete (a story entry, a design record, a reported pain), it is likely not needed.

Verification preference order: unit test > integration test > manual script > operator-run command with documented expected output. Use the minimal level that reliably asserts the delta. Manual verification is acceptable when automation is impractical.

AC-level guidelines:
- **Rename or delete:** include a paired negative check ("old path does not exist") alongside the positive check ("new path exists"). Both required.
- **Rename companion files:** after defining the production ACs, grep for companion files (tests, knowledge tests, fixtures) matching the old path pattern and include or defer explicitly.
- **Regression guard (bugfix only):** when the bug represents a recurring class -- a bash trap, a common mis-pattern, something review often misses -- add a generic guard (one repo-wide grep for all .sh files, not a per-file test). One-off logic errors do not need one.

At iteration end, mark each criterion as accepted or pushed to next iteration. Both visible.>

Not yet defined.

## Hot files
<Files in scope for this iteration. Each entry is a markdown link with a one-line note on why it is in scope. Populated per `iteration_policy.md` Step 1 from the roadmap task list. Updated per `iteration_policy.md` Steps 8-9 Details as tasks complete or new files enter scope.>

| File | Why in scope |
|---|---|
| [`path/to/file.md`](path/to/file.md) | <one-line reason> |

## Decisions
<Table: decision | rationale | where recorded. If none, write the canonical marker.>

None.

## Findings
<Append-only. Written immediately when something changes the plan: a bug or contradiction encountered, steering received from the operator, a blocker encountered, or a new file entering scope. Do not log routine reads or completed tasks here -- only write when something changes what you are doing or what the next iteration needs to know. This is the shared agent-managed recording surface for the agent-feedback and gotchas records. Classify each entry at the review/publish step at iteration end and route it to its destination (`AGENT_FEEDBACK.md`, `GOTCHAS.md`, Decisions table, Deferred items, or `roadmap.md`). Attribution is operator-owned; the agent proposes a class and the operator confirms it.>

| Finding | Type | Impact |
|---|---|---|
| <description> | bug / contradiction / steering / blocker / scope change | current iteration / next iteration / roadmap |

None.

## Completed
<Table: file | one-line change summary. If no files changed, write the canonical marker.>

No file changes this iteration.

## Deferred items
<Items that were in scope but are not complete. Each item must have an explicit reason for deferral and a note on where it goes next (next iteration, different sub-milestone, or roadmap_future.md). If nothing is deferred, write the canonical marker.>

Omit any item that is already a named task in `roadmap.md` or `roadmap_future.md`; do not re-list an item that has a roadmap home. The roadmap is the sole task list.

None.

## What's Next
<Sub-milestone ID and name for the next iteration.>
<Whether post-close bookkeeping has been run or is pending -- omit if mid-milestone and no sub-milestone just completed.>
<Blocking design questions the next agent must resolve before advancing.>
<Known watch-out items (capped at three).>
<Grep or file reads to run at iteration start, if known.>

**Conclusions from this iteration:** decisions made, approaches confirmed, dead ends ruled out. Not a full log -- only what would otherwise be re-derived from scratch. Omit if nothing was concluded beyond what is in the Decisions table.
```

What's Next is context-only. It does not carry a task list. The roadmap is the sole task list. Deferred items escalate into named roadmap entries at iteration end. When an iteration generates tasks, update the roadmap at iteration end.

---

## Canonical Null Markers

When a section has nothing to record, write the canonical marker and nothing else. Do not explain why the section is empty -- if a decision was made that affects the section, record it in the Decisions table or the relevant document. The agent must not leave a nullable section blank and must not explain why it is empty.

| Section | Canonical marker |
|---|---|
| Acceptance criteria | `Not yet defined.` |
| Decisions | `None.` |
| Findings | `None.` |
| Completed | `No file changes this iteration.` |
| Deferred items | `None.` |
| Carried forward | `None.` |

---

## Corrections to Closed Handovers

Closed handovers are read-only records with one exception: documented corrections applied under the post-close correction policy (`docs/operations/documentation_policy.md` -- Post-Close Document Corrections).

### When to apply

Apply a correction when a factual error is found in the document -- an incorrect status, a wrong filename, a misrecorded decision. Do not apply a correction to add new information, change scope, or extend the iteration record. New work belongs in a new handover.

### Procedure

1. Identify the error and its location in the document.
2. Edit the affected text in the body directly. If the error requires context, add a brief inline note: `[see correction below]`.
3. Append a dated amendment block at the bottom of the document:

```
---
[CORRECTION -- YYYY-MM-DD]: <description of what was wrong and what was changed>
```

4. Do not alter the document's Status, timestamps, or any other metadata field.
5. **Findings triage -- if the correction surfaces a new finding** (a compatibility gap, a regression, a policy violation, a missing task, or any issue that changes what the next iteration or future iterations need to know), the finding must be routed to its correct destination before the correction is finalised. Use the same triage criteria as the iteration end findings gate (`iteration_policy.md` [Steps 8-9 Details](iteration_policy.md#steps-89-close-and-seed)):

  - If the finding belongs in the active handover (the current iteration's handover), add it to Findings there.
  - If the finding represents a new task, write it as a named entry in `roadmap.md` under the current sub-milestone.
  - If the finding is a deferred item for the next iteration, add it to Deferred items in the active handover.
  - If the finding is purely documentary (e.g. a known-limitation note), update the relevant document directly.

   The correction block must document where the finding was routed (e.g. `Finding routed to roadmap.md -- autosave reliability.`).

6. Propose the amended document to the operator for review. Do not self-commit.

### What this is not

A correction to a closed handover is not a substitute for a new handover. If the iteration requires new work, create a new handover first. The correction procedure applies only to errors in the record -- not to work that was omitted or deferred.

---

## Related Skills

Skills and prompt templates that encode this policy. When this document is revised, these must be checked for drift.

| Skill / Prompt | Purpose |
|---|---|
| [`agent/prompts/new-iteration.md`](../../src/reasoning/agent/prompts/new-iteration.md) | Iteration start -- handover creation, recovery checks, scope/AC gates |
| [`agent/drafts/roadmap-audit.skill.md`](../../src/reasoning/agent/drafts/roadmap-audit.skill.md) | Roadmap format compliance, compaction audits |
| [`agent/drafts/handover-audit.skill.md`](../../src/reasoning/agent/drafts/handover-audit.skill.md) | Handover format compliance -- validates content rules defined here |

Policy documents that this document depends on:

| Policy | Relationship |
|---|---|
| [`roadmap_policy.md`](roadmap_policy.md) | Post-close bookkeeping, compaction rules |
| [`iteration_policy.md`](iteration_policy.md) | Operational workflow -- governs when handover fields are populated |
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
| [`iteration_policy.md`](iteration_policy.md) | Operational workflow -- when handover is created, updated, and closed |
| [`roadmap_policy.md`](roadmap_policy.md) | Roadmap update rules -- task checkbox discipline and post-close bookkeeping |
