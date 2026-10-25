---
description: "Close an active-operator session: consolidate the close into one shared runbook that /iter, /plan and /document invoke, writing back the roadmap task, closing ADRs and discussion docs whose work landed, closing the handover, and seeding the next iteration. The commit itself is /commit's. Also owns the decision of which close steps apply to a planning session."
argument-hint: "[optional: a session to close]"
---

> $ARGUMENTS

# /wrapup - The Consolidated Close

**Scope:** the shared close runbook for the active-operator-participation prompts. It owns the steps common to every such session's end: write back the roadmap task, close the ADRs and discussion docs whose work landed, close the handover, and seed the next iteration. It neither lands the commit nor runs the compaction pass or the milestone-record close; those belong to [`/commit`](commit.md) and [`/milestone-close`](milestone-close.md).

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `task-list`, `work-log`, `decision-records`, `git-discipline`, `testing`

## Mandate

You run the consolidated close for an active-operator session that ends at its release point. One commit per unit governs it: the unit ends as one delivery commit carrying the work, the handover marked `Closed`, and the roadmap write-back, and every `wip:` checkpoint and typed intermediate commit folds into it. The status flip and the write-back never form their own commit. The `git-discipline` convention names the delivery commit the sole reviewable surface, and [`/commit`](commit.md) states the commit rules and runs them.

## Called from

Each active-operator prompt invokes the part of this runbook that applies:

- `/iter` and `/document` run the close at the end of the session.
- `/plan` runs the close at the end of a planning session, whose write-back produces roadmap rows, decisions, and ADRs rather than a delivery commit.
- `/milestone-start` does not invoke it -- `/milestone-close` owns the milestone-record close, distinct from the unit close.

## Input contract

| Input | Meaning |
|---|---|
| session scope | The handover and roadmap rows the session changed, as the release gate released them. |
| current branch | The branch holding the unit's work, normally `feat/*` or `milestone/*`. |
| record-check report | What the release gate's two record checks found, as the gate presented it. B4 reads it to tell a finding the gate raised from one it missed. |

## Part B - The close (end of session, shared)

Run this once, after the operator's forward signal on the release gate: that signal is this part's release, and Part B adds no second approval, per [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md) gate invariants. The steps below run the close invariants in [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md).

### B1. AC verification

Read the acceptance criteria from the session's handover. For each criterion, state what was checked, what the result was, and whether it passes. If any criterion fails, stop -- do not close until the gap is resolved or explicitly deferred with a reason.

### B2. Propagation replay

Run the propagation-replay invariant in [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md) (Close invariants): when the session applied a naming, structural, or interface change across more than two files, or used "all", "every", "throughout", or "wherever X appears", produce a `file | change planned | status` table with every row accounted for (`completed`, or `deferred`/`not started` with the row written back to the roadmap) before the release gate releases.

### B3. Scope reconciliation

Run the scope-reconciliation invariant in [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md) (Close invariants): compare the confirmed scope against the Completed table; every in-scope item not completed is resolved by the deferred-resolution rule; no unaccounted items.

### B4. Roadmap write-back

Apply the row changes the release gate released, and mark each task this session resolved. The record-check report from the gate is this step's evidence; a finding the gate missed is recorded as `late`, naming the gate that should have asked. Note the exact row change per task touched, and the completed rows the change supersedes or invalidates: the task list requires a completed task to be marked, and the mark to ride this commit. When every sub-row of a task is resolved, close that task in the form the `/milestone-close` compaction procedure, step 1, states. A session that drew a brief from `/scope` files its work-unit table here, one row per unit, each naming a file and a nature of change. An iteration that changed no roadmap task writes back nothing and records that outcome.

### B5. Carry-forward resolution

Run the deferred-resolution invariant in [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md) (Close invariants): every item in scope but not completed is written back to the roadmap as an open row with its reason, or ruled out of scope with one Scope sentence. The handover carries no carried-forward or deferred-items section.

### B6. Findings review/publish

The gate decided the destinations; this step publishes them. Write each destination to its record: the Decisions table, a named `roadmap.md` row, or `devlog/AGENT_FEEDBACK.md`. Record the `[A]` or `[O]` class the operator confirmed. A finding discovered here is `late`, per B4, and stays in the handover. A recurring late entry becomes a roadmap row against the gate that missed it.

### B7. Pending-decision resolution

Every row of the handover's `Decisions pending` table closes before the handover closes, per the project's `work-log` convention. Each row takes one of three exits: the operator answered it, so the answer moves to the Decisions table with its rationale; the agent found the answer in a record, so the row cites that record; or the block is real and unresolved, so the work is written back as an open roadmap row and the question leaves the handover with it.

A row left open here is a question the operator meets twice, which is the cost this section exists to remove. A table holding only the canonical marker is closed with no work.

### B8. Close ADRs and discussion docs whose work landed

Close the `docs/adr/` and `devlog/discussions/` documents whose work landed this session. The record-check report from the release gate names the `[CORRECTION]` or `[AMENDMENT]` form each finding needs; this step writes the block. A document whose recorded work shipped but that stays open after the session is a stale record, so close it here. A finding the gate missed is `late`, per B4.

### B9. Check what the close wrote

Run the `roadmap-maintenance` skill over `devlog/roadmap.md` and the `handover-maintenance` skill over this session's handover, and fix what they report before the commit. The gate ran both before this part began, so it read the tree as the iteration left it; the rows B4, B6 and B8 write did not exist then, and this is the only run that reads them. A finding either skill raises here is a defect in what the close wrote, so it is fixed here and the commit does not land past it. The invariant is the close's own writes are checked, in [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md).

## Hand the commit to /commit

The close stops here; the commit begins at [`/commit`](commit.md) Part C.

- **What `/commit` owns.** Preparing the handover, marking each AC accepted or pushed, setting `Status: Closed`, landing the work, the status flip and the roadmap write-back as one delivery commit, and the post-commit compliance self-check. It also owns the in-session checkpoint that runs after each committed task group.
- **What stays here.** Every close step above: AC verification, propagation replay, scope reconciliation, the roadmap write-back, carry-forward resolution, findings publication, pending-decision resolution, closing ADRs and discussion docs, and the check on what the close wrote. The evidence `/commit` stages is the evidence these steps produced.
- **Where this runbook stops.** At this handoff. `/commit` runs, reports the landed commit, and returns here for the close report below.

### B10. Report the close

State that the close succeeded: the write-back, the records closed, and any deviation the post-commit self-check recorded. Then recommend what to pick up next, agent-led: name the candidate from the roadmap's open rows, with one line on why it is next. A fresh session starts from [`gm.md`](gm.md).

## Failure modes

- **The close restates the commit.** `/commit` owns the commit rules. A caller that re-states them is the duplication this split removes.
- **The commit is skipped because the close ran.** A close that reports success without a landed commit leaves the record closed in the tree and open in history. Hand off to `/commit` and report its result.
- **An ADR or discussion doc stays open after its work shipped.** A stale open record misleads the next session. Close it in B8, or name the reason it stays open in the handover's Scope.
- **The write-back lands as its own commit.** The roadmap write-back and the `Status: Closed` edit belong in the delivery commit, never a separate one.
- **The commit lands past a finding B9 raised.** The close wrote that record, so no earlier check read it, and the commit carries a defect no run reported. Fix it before the commit.

## When to stop and ask

- If any AC fails or an in-scope item is unaccounted, stop and resolve it before the close.
- If the handover's `Decisions pending` table holds a question only the operator can answer, stop and ask it before B9.
