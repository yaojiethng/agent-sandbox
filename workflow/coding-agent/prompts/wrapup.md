---
description: "Close an active-operator session: consolidate the close into one shared runbook that /iter and /plan invoke, writing back the roadmap task, settling the ADR entries and retiring the discussion records whose work landed, closing the handover, and seeding the next iteration. The commit itself is /commit's. Also owns the decision of which close steps apply to a planning session."
argument-hint: "[optional: a session to close]"
---

> $ARGUMENTS

# /wrapup - The Consolidated Close

**Scope:** the shared close runbook for the active-operator-participation prompts. It owns the steps common to every such session's end: write back the roadmap task, close the ADRs and discussion docs whose work landed, close the handover, and seed the next iteration. It neither lands the commit nor runs the compaction pass or the milestone-record close; those belong to [`/commit`](commit.md) and [`/milestone-close`](milestone-close.md).

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, skip the arm that reads it and report the skipped arm. Raise only a convention the procedure cannot run without.

- `task-list`, `work-log`, `decision-records`, `testing`

## Mandate

You run the consolidated close for an active-operator session that ends at its release point. The iteration ends as one delivery commit, and every `wip:` checkpoint and typed intermediate commit folds into it; the status flip and the write-back never form their own. [`/commit`](commit.md) states the commit rules and runs them.

## Called from

Each active-operator prompt invokes the part of this runbook that applies:

- `/iter` runs it after its release gate, and `/plan` after the operator confirms the plan.
- `/plan` runs the close at the end of a planning session, whose write-back produces roadmap rows, decisions, and ADRs rather than a delivery commit.
- `/milestone-start` does not invoke it -- `/milestone-close` owns the milestone-record close, distinct from the iteration close.

## Input contract

| Input | Meaning |
|---|---|
| session scope | The handover and roadmap rows the session changed, as the release gate released them. |
| current branch | The branch holding the iteration's work, normally `feat/*` or `milestone/*`. |
| record-check report | What the release gate's two record checks found, as the gate presented it. B6 reads it to tell a finding the gate raised from one it missed. |

## The close (after the release)

Run this once, after the operator's forward signal on the release gate: that signal is this runbook's release, and it adds no second approval, per [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md) gate invariants. The caller wrote the evidence the gate read; this runbook executes what the release decided and closes the record.

### B1. The status flip

Set the handover's `status` to `Closed`. The record closes here, as the close's first act, and [`/commit`](commit.md) stages what this step wrote.

### B2. Findings review/publish

The destinations were decided at the gate, and each finding reached the handover's `## Findings` table when it was raised. Confirm every destination is on disk, and land those the gate decided after the write: the Decisions table, a named `roadmap.md` row, or `devlog/AGENT_FEEDBACK.md`. Record the `[A]` or `[O]` class the operator confirmed. A finding discovered here is `late`, per B6, and stays in the handover. A recurring late entry becomes a roadmap row against the gate that missed it.

### B3. Pending-decision resolution

A record that still carries the older format's pending-decision part closes it before the handover closes, per the project's `work-log` convention. Each row takes one of three exits: the operator answered it, so the answer moves to the decisions part with its rationale; the agent found the answer in a record, so the row cites that record; or the block is real and unresolved, so the work is written back as an open roadmap row and the question leaves the handover with it. A record under the current format carries no such part; skip this step.

### B4. Roadmap write-back

Read the rows the caller wrote and confirm they are on disk: [`/iter`](iter.md) writes them before its gate, so its rows are read as a diff rather than applied from a description. A caller that hands over a work table instead, [`/plan`](plan.md) from a [`/scope`](scope.md) brief, files its rows here, one row per iteration, each naming a file and a nature of change. When every sub-row of a task is resolved, close that task in the form the `/milestone-close` compaction procedure, step 1, states. An iteration that changed no roadmap task writes back nothing and records that outcome.

### B5. Settle the ADR entries and retire the records whose work landed

Settle each `docs/adr/` entry whose work landed this session: a content correction is rewritten in place, and a non-content change takes the `[AMENDMENT]` block the release gate's record check names. A discussion record is not settled, it is retired: the one whose roadmap row closes here is deleted, and the one an open row takes over is re-pointed rather than deleted, per `.agents/skills/decision-records/SKILL.md`. A document whose recorded work shipped but that stays open after the session is a stale record, so settle it here. A finding the gate missed is `late`, per B6.

### B6. Check what the close wrote

Run the `roadmap-maintenance` skill over `devlog/roadmap.md` and the `handover-maintenance` skill over this session's handover, and fix what they report before the commit. The records B2 and B5 write, and the rows B4 writes for a caller that deferred them, did not exist when the gate ran, so this is the only run that reads them. A finding either skill raises here is a defect in what the close wrote: it is fixed here, and the commit does not land past it. The invariant is the close's own writes are checked, in [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md).

## Hand the commit to /commit

The close stops here; the commit begins at [`/commit`](commit.md).

- **What `/commit` owns.** Landing the work, the closed handover and the roadmap row as one delivery commit, and the post-commit self-check. It also owns the in-session checkpoint that runs after each committed task group.
- **What stays here.** Every close step above, and the evidence they produced is the evidence `/commit` stages.
- **Where this runbook stops.** At this handoff. `/commit` runs, reports the landed commit, and returns here for the close report below.

### B7. Report the close

State that the close succeeded: the write-back, the records settled, and any deviation the post-commit self-check recorded. Then recommend what to pick up next, agent-led: name the candidate from the roadmap's open rows, with one line on why it is next. A fresh session starts from [`gm.md`](gm.md).
