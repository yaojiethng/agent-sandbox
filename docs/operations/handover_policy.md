# Handover Policy

**Description.** Owns handover content rules: valid field states, null markers, the section format, and the correction procedure.

**Scope.** Governs the handover files under `devlog/handovers/`, and the runbooks that write them: `/iter`, `/plan`, `/document`, `/wrapup` and `/milestone-close`. For the operational workflow -- when to populate each field, step sequencing, and the gates -- see [`iteration_policy.md`](iteration_policy.md).

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

```text
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

Each iteration has a type that reflects the category of what it produces. The type appears in the handover header and in the filename shortform. It is set at the scope gate, before the work is known in detail; the commit type at close disambiguates the subclass.
Each iteration type must declare its scope independently. Do not inherit objectives, acceptance criteria, or task completion status from prior iterations of different types.

| Type | Shortform | Deliverable -- what the iteration produces | Commit mapping |
|---|---|---|---|
| Implementation | `impl` | Behaviour work: a new capability, a fix, or a restructure. The commit type (`feat`/`fix`/`refactor`/`test`/`build`) disambiguates the subclass at close. | `feat`, `fix`, `refactor`, `test`, `build` |
| Discussion | `discussion` | An in-flight discussion document that has not yet resolved to a decision. | `docs` |
| Design | `design` | Decision and evaluation work: ADRs, running investigations, option evaluation, maintaining ADRs while evaluating multiple candidates. Jump-right-in, often interleaved with `impl` commits. | `docs` |
| Plan | `plan` | Planning at any grain: a milestone's scope and its task list, or one task scoped to its unit. | `plan` |
| Documentation | `docs` | Project documentation under `docs/` -- descriptive prose that is not a decision record. | `docs` |
| Workflow | `workflow` | Policy, governance, AGENTS.md, prompts, and `workflow/` agent-behaviour contract files. | `workflow` |
| Housekeeping | `chore` | Small administrative or cosmetic maintenance: stale links, linting, index cleanup, roadmap bookkeeping. | `chore` |
| Audit | `audit` | Compliance or review sweep, usually producing a report or a non-content reordering sweep. A review-driven sweep lands corrections, so its commits take any type the findings call for. | any |
| Story | `story` | Deprecated -- folded into `discussion`; retained for historical handovers only. | -- |
| Study | `study` | Deprecated -- folded into `design`; retained for historical handovers only. | -- |
| Spec | `spec` | Deprecated -- folded into `design`; retained for historical handovers only. | -- |

---

## Lifecycle

A handover has three states:

**Open** -- created at iteration start (`iteration_policy.md` [Iteration Invariants](iteration_policy.md#iteration-invariants)). Populated from the roadmap entry for the target sub-milestone and from the prior handover if one exists. The prior handover's Status header must be verified; if it is not "Closed", continue the existing session rather than starting a new one. If there is reason to suspect progress was lost, propose recovery.

**Active** -- updated throughout the iteration as tasks complete, decisions are made, and scope changes are noted. The Status header is set to "Active".

**Closed** -- finalised at iteration end (`iteration_policy.md` [close invariants](iteration_policy.md#iteration-invariants)). Records what was completed, marks deferrals explicitly, and seeds the next iteration. The Status header is set to "Closed".

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
<Which task groups or tasks from the roadmap this iteration targets. Reference by group name; do not copy the task list. If design questions are blocking, list them explicitly as obstacles. When this iteration works a subtask of a parent row, open with one continuation line naming the parent row and the handover it continues from. An item raised in-session and ruled out of scope is recorded here as one sentence with its reason; an item deferred with a destination is written back to the roadmap instead. The handover carries no cross-iteration state beyond this, the milestone marker, and the iteration's own roadmap write-back.>

## Acceptance criteria
<Table: criterion | verification | result. One row per criterion.

What makes a criterion well-formed -- the delta rule, traceability, the verification preference order, the paired negative check on a rename, the companion-file grep, the regression guard, and the `Operator` / `Agent` marking -- is [`iteration_policy.md`](iteration_policy.md#acceptance-criteria-invariants)'s. This section owns the table and the marker below.

At iteration end, mark each criterion as accepted or pushed to the next iteration. Both visible.>

Not yet defined.

## Hot files
<Files in scope for this iteration. Each entry is a markdown link with a one-line note on why it is in scope. Populated from the roadmap task list. Updated as tasks complete or new files enter scope.>

| File | Why in scope |
|---|---|
| [`path/to/file.md`](path/to/file.md) | <one-line reason> |

## Decisions
<Table: decision | rationale | where recorded. If none, write the canonical marker.>

None.

## Decisions pending
<Table: question | what it blocks | options. Questions the operator still owns, raised at any point in the iteration. If none, write the canonical marker.>

A pending decision is one the agent cannot settle from the records. It is not a task, and it never appears in the roadmap: the roadmap holds work, and a question is not work until it has an answer. The section exists so the operator is never surprised by a question the agent has been holding.

The agent writes an entry the moment it becomes blocked, not at the gate where the block is felt. A decision raised during design is recorded while the design is open, so the operator sees it while there is still time to redirect the iteration.

Every entry names what it blocks, so the operator can judge urgency, and gives the options with their consequences, so a reply can be a pick rather than a question. An entry that only states that a decision is needed is not an entry.

A pending decision closes in one of three ways, and the close is recorded in this section until the section is empty: the operator answers it and the answer moves to the Decisions table with its rationale; the agent finds the answer in a record and cites it; or the block is real and the work moves out of scope, in which case the work is written back as an open roadmap row and the question leaves the handover with it.

| Question | Blocks | Options |
|---|---|---|
| <the decision, in one question> | <the work that cannot proceed without it> | <option and consequence, per option> |

None.

## Findings
<Append-only. Written immediately when something changes the plan: a bug or contradiction encountered, steering received from the operator, a obstacle encountered, or a new file entering scope. Do not log routine reads or completed tasks here -- only write when something changes what you are doing or what the next iteration needs to know. This is the shared agent-managed recording surface for the agent-feedback and gotchas records. Classify each entry at the review/publish step at iteration end and : route it to its destination (`AGENT_FEEDBACK.md`, Decisions table, or `roadmap.md`). The `[A]`/`[O]` tag names who raised the entry. Attribution is operator-owned; the agent proposes a class and the operator confirms it.>

| Finding | Type | Impact |
|---|---|---|
| <description> | bug / contradiction / steering / obstacle / scope change | current iteration / next iteration / roadmap |

None.

## Completed
<Table: file | one-line change summary. If no files changed, write the canonical marker.>

No file changes this iteration.

The handover has no Deferred items, Carried forward, or What's Next section. Each was a transient task record; the roadmap write-back handles the durable form. An item deferred with a destination becomes an open roadmap row at the close. An item ruled out of scope is one sentence in Scope with its reason. What to pick up next is the agent's advisory recommendation in the wrapup report -- the roadmap stays the sole task list, and the when and invariants of its update live in [`roadmap_policy.md`](roadmap_policy.md#when-the-roadmap-is-touched).

```

---

## Canonical Null Markers

When a section has nothing to record, write the canonical marker and nothing else. Do not explain why the section is empty -- if a decision was made that affects the section, record it in the Decisions table or the relevant document. The agent must not leave a nullable section blank and must not explain why it is empty.

| Section | Canonical marker |
|---|---|
| Acceptance criteria | `Not yet defined.` |
| Decisions | `None.` |
| Decisions pending | `None.` |
| Findings | `None.` |
| Completed | `No file changes this iteration.` |

---

## Corrections to Closed Handovers

A closed handover is edited only at the operator's direction, and every edit carries the corresponding correction tag. A correction ends where the record started. The Status field, the original date and the metadata are unchanged in the corrected record; a reopen and re-close cycle is a mechanism, not a change. The operator signals direction any way it is said: "amend the handover", "re-open the handover", "edit it", "fix the typo", or by naming the change.

A handover is a decision log, not a factual reference. It is never corrected autonomously. Only the operator directs an edit.

### When to apply

Apply a correction at the operator's direction. The shared principle, the propagation rule and the agent's two stops and one smell are in [`documentation_policy.md`](documentation_policy.md#post-close-document-corrections); this section states what qualifies here. Three forms qualify:

- A **misrecording**: an incorrect status, a wrong filename, a misrecorded decision, or a count or state that disagrees with the tree.
- A **folded fix**: a later squash, fixup or amend folded into the close, and the record amendments that ride with it.
- An **omission**, and only where the handover's own account of what the iteration turned in is wrong for want of it: the iteration delivered something and left the record silent about a defect in it.

An omission is not a place to record work the iteration never did, and it is not a place to state a limit the iteration drew only afterwards. Both are new work, and a new handover carries them.

### Procedure

1. Confirm the operator's direction and identify the paragraph or section.
2. Rewrite the entire affected paragraph (or section) in place. Do not leave inline markers such as a reference count or a `[see correction below]` label. The rewritten text reads as the record.
3. Insert the correction tag as a block at the end of the corrected section, immediately before the start of the next section:

```text
---
[CORRECTION -- YYYY-MM-DD: <one to three lines describing the change and the reason>]

---
```

Keep the blank line before the closing fence. Without it, the tag paragraph parses as a setext heading and the Markdown lint gate reports `MD022` (see [`documentation_policy.md`](documentation_policy.md#markdown-lint-gate)).

1. Order multiple correction tags newest first, oldest last, the way an ADR orders its dated entries.
2. Do not alter the Status, timestamps, or any other metadata field in the corrected record.
3. **Findings triage -- if the correction surfaces a new finding** (a compatibility gap, a regression, a policy violation, a missing task, or any issue that changes what the next iteration or future iterations need to know), the finding must be routed to its correct destination before the correction is finalised. Use the same triage criteria as the iteration end findings gate (`iteration_policy.md` [close invariants](iteration_policy.md#iteration-invariants)):

- If the finding belongs in the active handover (the current iteration's handover), add it to Findings there.
- If the finding represents a new task, write it as a named entry in `roadmap.md` under the current sub-milestone.
- If the finding is a deferred item for the next iteration, write it back as an open roadmap row under the current sub-milestone.
- If the finding is purely documentary (e.g. a known-limitation note), update the relevant document directly.

   The correction tag must document where the finding was routed (e.g. `Finding routed to roadmap.md -- autosave reliability.`).

1. When the agent spotted the correction, propose the amended text and apply it on the operator's release. When the operator named the change directly, apply it. A correction is never applied unasked.

### What this is not

A correction is not a substitute for a new handover. Work the iteration did not do is new work, and a new handover carries it.

A correction may reopen the record. Reopening to adjust the work and closing again is a correction path. The record ends Closed, with the same date and metadata it carried before, and with a `[CORRECTION]` tag naming the change, its date, and where any finding it surfaced was routed. A correction that cannot be finished returns the record to Closed as it was.
