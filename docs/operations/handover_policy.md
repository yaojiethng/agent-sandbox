# Handover Policy

**Role:** Defines handover content rules: valid field states, null markers, format, and the correction procedure. For the operational workflow (when to populate each field, step sequencing, gates), see [`iteration_policy.md`](iteration_policy.md).

A handover is a log describing the work done in the iteration: what was done and what comes next, with enough fidelity that a new agent can continue without reconstructing state from the iteration history.

A handover is not a document and is not subject to `documentation_policy.md` drafting rules. It is committed with the iteration's changes and retained for the life of the milestone. A closed handover is edited only at the operator's direction and carries the corresponding correction tag (see [Corrections to Closed Handovers](handover_policy.md#corrections-to-closed-handovers)). It describes the iteration, not the system. This is what "ephemeral" means here: it is not a reference document. It does not mean excluded from version control or from packaging.

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

Each iteration has a type that reflects the category of what it produces. The type appears in the handover header and in the filename shortform. It is set at scope confirmation (Steps 1-2), before the work is known in detail; the commit type at close disambiguates the subclass.
Each iteration type must declare its scope independently. Do not inherit objectives, acceptance criteria, or task completion status from prior iterations of different types.

| Type | Shortform | Deliverable -- what the iteration produces | Commit mapping |
|---|---|---|---|
| Implementation | `impl` | Behaviour work: a new capability, a fix, or a restructure. The commit type (`feat`/`fix`/`refactor`/`test`/`build`) disambiguates the subclass at close. | `feat`, `fix`, `refactor`, `test`, `build` |
| Discussion | `discussion` | An in-flight discussion document that has not yet resolved to a decision. | `docs` |
| Design | `design` | Decision and evaluation work: ADRs, running investigations, option evaluation, maintaining ADRs while evaluating multiple candidates. Jump-right-in, often interleaved with `impl` commits. | `docs` |
| Plan | `plan` | Major-loop milestone scoping: a large task list and assigning work to iterations. | `docs` |
| Documentation | `docs` | Project documentation under `docs/` -- descriptive prose that is not a decision record. | `docs` |
| Workflow | `workflow` | Policy, governance, AGENTS.md, prompts, and `workflow/` agent-behaviour contract files. | `workflow` |
| Housekeeping | `chore` | Small administrative or cosmetic maintenance: stale links, linting, index cleanup, roadmap bookkeeping. | `chore` |
| Audit | `audit` | Compliance or review sweep, usually producing a report or a non-content reordering sweep. | `refactor`, `docs`, or `chore` |
| Story | `story` | Deprecated -- folded into `discussion`; retained for historical handovers only. | -- |
| Study | `study` | Deprecated -- folded into `design`; retained for historical handovers only. | -- |
| Spec | `spec` | Deprecated -- folded into `design`; retained for historical handovers only. | -- |

---

## Lifecycle

A handover has three states:

**Open** -- created at iteration start (`iteration_policy.md` [Step 1 Details](iteration_policy.md#step-1-open-handover)). Populated from the roadmap entry for the target sub-milestone and from the prior handover if one exists. The prior handover's Status header must be verified; if it is not "Closed", continue the existing session rather than starting a new one. If there is reason to suspect progress was lost, propose recovery.

**Active** -- updated throughout the iteration as tasks complete, decisions are made, and scope changes are noted. The Status header is set to "Active".

**Closed** -- finalised at iteration end (`iteration_policy.md` [Steps 8-9 Details](iteration_policy.md#steps-89-close-and-seed)). Records what was completed, marks deferrals explicitly, and seeds the next iteration. The Status header is set to "Closed".

---

## Format

```markdown
# Agent Handover

**Date:** YYYY-MM-DD
**Milestone:** <sub-milestone ID and name -- e.g. M2.1 -- General Capability Layer Prototype>
**Type:** <Implementation | Discussion | Design | Plan | Documentation | Workflow | Housekeeping | Audit>
<Story | Study | Spec> (deprecated -- historical handovers only)
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
<Whether roadmap maintenance has been run or is pending -- omit if mid-milestone and no sub-milestone just completed.>
<Blocking design questions the next agent must resolve before advancing.>
<Known watch-out items (capped at three).>
<Grep or file reads to run at iteration start, if known.>

**Conclusions from this iteration:** decisions made, approaches confirmed, dead ends ruled out. Not a full log -- only what would otherwise be re-derived from scratch. Omit if nothing was concluded beyond what is in the Decisions table.
```

What's Next is context-only. It does not carry a task list. The roadmap is the sole task list; its update procedure lives in [`roadmap_policy.md`](roadmap_policy.md#when-the-roadmap-is-touched).

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

A closed handover is edited only at the operator's direction, and every edit carries the corresponding correction tag. The operator signals direction any way it is said: "amend the handover", "re-open the handover", "edit it", "fix the typo", or by naming the change. None of these signals changes the Status field; the correction procedure runs without re-opening the record.

A handover is a decision log, not a factual reference. It is never corrected autonomously. Only the operator directs an edit.

### When to apply

Apply a correction only when the operator directs it. Reasons include a factual error in the record (an incorrect status, a wrong filename, a misrecorded decision) and folding a later fix into a close commit (a squash, a fixup, or an amend). Do not use a correction to add new information, change scope, or extend the record. New work belongs in a new handover.

### Procedure

1. Confirm the operator's direction and identify the paragraph or section.
2. Rewrite the entire affected paragraph (or section) in place. Do not leave inline markers such as a reference count or a `[see correction below]` label. The rewritten text reads as the record.
3. Insert the correction tag as a block at the end of the corrected section, immediately before the start of the next section:

```
---
[CORRECTION -- YYYY-MM-DD: <one to three lines describing the change and the reason>]
---
```

4. Order multiple correction tags newest first, oldest last, the way an ADR orders its dated entries.
5. Do not alter the Status, timestamps, or any other metadata field.
6. **Findings triage -- if the correction surfaces a new finding** (a compatibility gap, a regression, a policy violation, a missing task, or any issue that changes what the next iteration or future iterations need to know), the finding must be routed to its correct destination before the correction is finalised. Use the same triage criteria as the iteration end findings gate (`iteration_policy.md` [Steps 8-9 Details](iteration_policy.md#steps-89-close-and-seed)):

  - If the finding belongs in the active handover (the current iteration's handover), add it to Findings there.
  - If the finding represents a new task, write it as a named entry in `roadmap.md` under the current sub-milestone.
  - If the finding is a deferred item for the next iteration, add it to Deferred items in the active handover.
  - If the finding is purely documentary (e.g. a known-limitation note), update the relevant document directly.

   The correction tag must document where the finding was routed (e.g. `Finding routed to roadmap.md -- autosave reliability.`).

7. Propose the amended handover to the operator. Do not self-commit.

### What this is not

A correction is not a substitute for a new handover. If the iteration requires new work, create a new handover first. The correction procedure applies only to the operator-directed edit, not to work that was omitted or deferred.

---

## Related Skills

Skills and prompt templates that encode this policy. When this document is revised, these must be checked for drift.

| Skill / Prompt | Purpose |
|---|---|
| [`agent/prompts/new-iteration.md`](../../src/reasoning/agent/prompts/new-iteration.md) | Iteration start -- handover creation, roadmap maintenance check, scope/AC gates |
| [`audits/roadmap-audit.skill.md`](../../workflow/coding-agent/audits/roadmap-audit.skill.md) | Roadmap format compliance, compaction audits |
| [`audits/handover-audit.skill.md`](../../workflow/coding-agent/audits/handover-audit.skill.md) | Handover format compliance -- validates content rules defined here |

Policy documents that this document depends on:

| Policy | Relationship |
|---|---|
| [`roadmap_policy.md`](roadmap_policy.md) | Roadmap maintenance, compaction rules |
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
| [`roadmap_policy.md`](roadmap_policy.md) | Roadmap update rules -- task checkbox discipline and roadmap maintenance |
