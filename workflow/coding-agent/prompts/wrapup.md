---
description: "Close an active-operator session: consolidate the close into one shared runbook that /iter, /plan and /document invoke, writing back the roadmap task, closing ADRs and discussion docs whose work landed, closing the handover, and seeding the next iteration. The commit itself is /commit's. Also owns the decision of which close steps apply to a planning session."
argument-hint: "[optional: a session to close]"
---

> $@

# /wrapup - The Consolidated Close

**Scope:** one shared close runbook for the active-operator-participation prompts -- `/iter`, `/plan` and `/document`. It owns the steps common to every such session's end: write back the roadmap task, close the ADRs and discussion docs whose work landed, close the handover, and seed the next iteration. It does not land the commit; [`/commit`](commit.md) owns the checkpoint, the preparation, the landing and the post-commit verification. It does not run the compaction pass or the milestone-record close; those are milestone-grain and belong to `/milestone-close`. `milestone-start`, `sequential-work` and `parallel-work` do not invoke it.

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `task-list`, `work-log`, `decision-records`, `git-discipline`, `testing`

## Mandate

You run the consolidated close for an active-operator session that ends at its release point. The close delivers a HEAD that reads as one coherent delivery commit per unit, with a closed handover naming it, and no pile of typed checkpoints left for the operator to untangle.

One commit per unit governs the close: the unit ends as one delivery commit carrying the work, the handover marked `Closed`, and the roadmap write-back; every `wip:` checkpoint and typed intermediate commit folds into it -- the `git-discipline` convention names the delivery commit the sole reviewable surface. The status flip and the write-back never form their own commit. [`/commit`](commit.md) states the commit rules and runs them; this runbook does not restate them.

## Called from

Each active-operator prompt invokes the part of this runbook that applies:

- `/iter` and `/document` run the close at the end of the session.
- `/plan` runs the close at the end of a planning session, whose write-back produces roadmap rows, decisions, and ADRs rather than a delivery commit.
- `milestone-start` does not invoke it -- `/milestone-close` owns the milestone-record close, distinct from the unit close.
- `sequential-work` and `parallel-work` do not invoke it -- their run review substitutes for the operator gate (roadmap row `/auto` bypasses the two operator-acceptance points).

## Input contract

| Input | Meaning |
|---|---|
| session scope | The handover and roadmap rows the session changed, as the release gate released them. |
| current branch | The branch holding the unit's work, normally `feat/*` or `milestone/*`. |

## Part B - The close (end of session, shared)

Run this once when the session reaches its end. It follows the unit's release point. There is one release: the operator's forward signal on the release gate (per [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md) gate invariants) is the release for this part; Part B does not add a second operator approval. The close steps below run the close invariants in [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md); a step states the invariant it satisfies and links it, rather than redefining it.

### B1. AC verification

Read the acceptance criteria from the session's handover. For each criterion, state what was checked, what the result was, and whether it passes. If any criterion fails, stop -- do not close until the gap is resolved or explicitly deferred with a reason.

### B2. Propagation replay

Run the propagation-replay invariant in [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md) (Close invariants): when the session applied a naming, structural, or interface change across more than two files, or used "all", "every", "throughout", or "wherever X appears", produce a `file | change planned | status` table with every row accounted for (`completed`, or `deferred`/`not started` with the row written back to the roadmap) before the release gate releases.

### B3. Scope reconciliation

Run the scope-reconciliation invariant in [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md) (Close invariants): compare the confirmed scope against the Completed table; every in-scope item not completed is resolved by the deferred-resolution rule; no unaccounted items.

### B4. Roadmap write-back

Apply the row changes the release gate released. The record-check report from the gate is this step's evidence. A finding the gate missed is recorded as `late`, naming the gate that should have asked.

Run the write-back step and state its outcome. This step is the moment the iteration marks its tasks done, and it is what satisfies the task list's invariant that a completed task is marked and the mark is committed. A task is marked `[x]` at the close that resolves it, not by a later cleanup pass. When every sub-row of a task is resolved, this step closes that task, in the form the `/milestone-close` compaction procedure, step 1, states. Note the exact row change per task touched, and the completed rows the change supersedes or invalidates. A session that drew a brief from `/scope` files its work-unit table here, one row per unit, each naming a file and a nature of change. An iteration that changed no roadmap task writes back nothing, and records that outcome. The step is mandatory; its value may be None. The write-back rides the delivery commit; it never forms its own commit. Compacting a sub-milestone to a paragraph, the upward cascade, the summary table update and any top-level milestone close are milestone-grain and belong to [`/milestone-close`](milestone-close.md), not to this runbook.

### B5. Carry-forward resolution

Run the deferred-resolution invariant in [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md) (Close invariants): every item in scope but not completed is written back to the roadmap as an open row with its reason, or ruled out of scope with one Scope sentence. The handover carries no carried-forward or deferred-items section.

### B6. Findings review/publish

The gate decided the destinations; this step publishes them. Write each destination to its record: the Decisions table, a named `roadmap.md` row, or `devlog/AGENT_FEEDBACK.md`. Record the `[A]` or `[O]` class the operator confirmed. A finding discovered here is recorded as `late`, names the gate that should have asked, and stays in the handover. A recurring late entry becomes a roadmap row against the gate that missed it.

### B7. Pending-decision resolution

Every row of the handover's `Decisions pending` table closes before the handover closes, per the project's `work-log` convention. Each row takes one of three exits: the operator answered it, so the answer moves to the Decisions table with its rationale; the agent found the answer in a record, so the row cites that record; or the block is real and unresolved, so the work is written back as an open roadmap row and the question leaves the handover with it.

A row left open here is a question the operator meets twice, which is the cost this section exists to remove. A table holding only the canonical marker is closed with no work.

### B8. Close ADRs and discussion docs whose work landed

Close the `docs/adr/` and `devlog/discussions/` documents whose work landed this session. The record-check report from the release gate names the `[CORRECTION]` or `[AMENDMENT]` form each finding needs; this step writes the block. A document whose recorded work shipped but that stays open after the session is a stale record, so close it here. A finding the gate missed is recorded as `late`, naming the gate that should have asked.

## Hand the commit to /commit

The close stops here; the commit begins at [`/commit`](commit.md) Part C.

- **What `/commit` owns.** Preparing the handover, marking each AC accepted or pushed, setting `Status: Closed`, landing the work, the status flip and the roadmap write-back as one delivery commit, and the post-commit compliance self-check. It also owns the in-session checkpoint that runs after each committed task group.
- **What stays here.** Every close step above: AC verification, propagation replay, scope reconciliation, the roadmap write-back, carry-forward resolution, findings publication, pending-decision resolution, and closing ADRs and discussion docs. The evidence `/commit` stages is the evidence these steps produced.
- **Why the split.** The commit is one operation with one set of rules, and five prompts perform it; the close is another, and it edits records rather than history. Keeping them in one runbook made the commit rules reachable only through a runbook a caller did not always need.
- **Where this runbook stops.** At this handoff. `/commit` runs, reports the landed commit, and returns here for the close report below.

### B9. Report the close

State that the close succeeded: the write-back, the records closed, and any deviation the post-commit self-check recorded. Then recommend what to pick up next, agent-led: name the candidate from the roadmap's open rows, with one line on why it is next. The recommendation is advisory context for the operator, not a task list; the roadmap stays the sole task list, and a fresh session starts from [`gm.md`](gm.md).

## Failure modes

- **The close restates the commit.** `/commit` owns the commit rules, the squash, the status flip and the self-check. A caller that re-states them is the duplication this split removes.
- **The commit is skipped because the close ran.** A close that reports success without a landed commit leaves the record closed in the tree and open in history. Hand off to `/commit` and report its result.
- **An ADR or discussion doc stays open after its work shipped.** A stale open record misleads the next session. Close it in B8, or name the reason it stays open in the handover's Scope.
- **The write-back lands as its own commit.** The roadmap write-back and the `Status: Closed` edit belong in the delivery commit, never a separate one.

## When to stop and ask

- If any AC fails or an in-scope item is unaccounted, stop and resolve it before the close.
- If the handover's `Decisions pending` table holds a question only the operator can answer, stop and ask it before B9.
