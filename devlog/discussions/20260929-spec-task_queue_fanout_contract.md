# Spec: task-queue Fan-Out Comparison Contract

**Status:** active
**Date:** 2026-09-29
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** spec (shared comparison contract, single source of truth)

## Purpose

This document is the single source of truth both implementations must satisfy. Track A (bash, first-class harness lib) and Track B (Node/TypeScript pi-extension) implement task-queue against this contract unchanged. The primary scores both on the invariant set below and the scoring rubric below. Neither track may change this file; it is read-only and single-source; the primary owns it.

The task-queue mechanism this contract specifies is the general sequencing primitive in [`20260929-design-draft-task_queue_general_sequencing_primitive.md`](20260929-design-draft-task_queue_general_sequencing_primitive.md). A track satisfies the contract when it implements a queue of requested break points with the fork/join/re-queue model, the single-writer rule, the final-verification, the write-back proposal, and the bring-back merge, and holds the machine-checkable invariants below.

## Part 1 -- The invariants

### Queue integrity

- **I1 - No loss, no duplication.** Every enqueued break point is dequeued exactly once for triggering; a re-enqueued break point re-enters exactly once.
- **I2 - Order preservation.** Break points trigger in request order per task. Cross-task order is the primary's choice, not constrained by the queue.
- **I3 - Referential integrity.** Every queue entry references exactly one task, one worker, and one working directory, and the referenced task/worker/directory exist and are the same on dequeue as on enqueue.

### State machine

- **I4 - Legal transitions only.** A break point transitions request -> scheduled -> triggered only in that order. Triggering a break point that was not requested is an error. A scheduled break point not yet triggered cannot be re-scheduled.
- **I5 - Single trigger.** A break point triggers at most once.

### Single writer

- **I6 - No worker write to the main tree.** No worker's worktree write lands in the primary tree except through the primary's merge. The main tree is mutated only by the primary.
- **I7 - Write-back scope discipline.** The merge applies exactly the bring-back verdict (all, partial, or none) the operator's final verdict named, neither more nor less.

### Verification

- **I8 - Verification only at termination request.** Final verification runs only after the worker requests it (the terminal break point), never mid-segment.
- **I9 - Verification-before-merge ordering.** No track merges before its final verification confirms the output and report landed as directed.

### Lifecycle

- **I10 - Worktree hygiene.** Every worktree and branch is retired or pruned at a clean close; no registered worktree or leftover branch survives a clean close. A close that encounters an already-absent target (a worktree or branch already removed) treats it as success, not failure, so a close interrupted and re-run completes.

### Durability and atomicity

This class is the load-bearing addition. The queue is durable state; its file-backed persistence exists to survive interrupted writes and process crashes. The invariants above govern the steady state; this class governs the transitions that change it. Both reviewing agents independently converged on this as the blocker: a durable queue whose transitions are non-atomic or whose close is not resumable cannot hold I1-I10 under any real failure, and a parse or write failure must never leave the queue in an unrecoverable state.

- **I11 - Single atomic transition.** Every state transition is one atomic write (a single rename, or an equivalent atomic rewrite), not a sequence of writes whose partial completion leaves a corrupt or half-applied state. A transition either commits whole or leaves the prior state intact and the queue resumable at that prior state.
- **I12 - No loss, no orphan on failure.** No operation that fails mid-way may spend, consume, or erase a resource (a re-queue arm, a queue entry, a verification mark, a verdict) unless the whole operation committed. A failed operation leaves every resource it touched in its pre-operation state, and a retry of the operation is safe.
- **I13 - Resumable close.** A close is idempotent and resumable: if it is interrupted, a re-run completes it. It never permanently fails on a target that is already absent, and it never leaves the queue in a state from which no API can recover.

Structural preference: a transition should be *structurally* atomic (state encoded so each change is a single atomic rename) rather than made atomic by bolted-on rollback of a multi-write sequence. Cheap rollback is acceptable only where the failure window cannot cross a resource-ownership boundary; the reviewers' guidance is to prefer the structural form so that I1/I4/I5 hold by construction, not by enforced checks.

## Part 2 -- The scoring rubric

The primary scores each completed track on the five criteria below under the given weights. **Correctness and performance are primary priorities; maintainability is secondary (readability and modularity are sub-components of maintainability); testability is tertiary.** The track with the higher weighted score is the chosen implementation; the other is recorded as the rejected alternative with the scoring evidence.

Weights (primary > secondary > tertiary):

| Criterion | Priority | Sub-components |
|---|---|---|
| Correctness | primary | holds I1-I13; verifiable by a machine-checkable conformance suite |
| Performance | primary | measured per-operation cost (enqueue, dequeue, trigger, verify, merge) on the same uncontended host |
| Maintainability | secondary | composed of readability + modularity |
| -- Readability | (sub) | named concepts, self-documenting structure |
| -- Modularity | (sub) | clean separation of queue / state / worktree / merge / record |
| Testability | tertiary | ease of unit testing under the harness; the conformance suite runs in the implementation's own test runner |

### Verdict format

The verdict is a per-criterion comparison plus a single recommendation. Per `fanout-run`'s pre-assigned-format rule, this is fixed in the preamble and not renegotiated during collection:

For each criterion, state which track scores higher and why, one line each. Then the overall recommendation (which track wins) with a two-line rationale. Record the verdict in the primary's own record; neither track writes a record.

## Part 3 -- The dispatch contract (fixed in the preamble)

- Each track runs in its own worktree and branch, cut from the same baseline commit, one fresh subagent per track, dispatched concurrently.
- Either track may read this spec and the design record; neither may modify them (single source, primary-owned).
- A track implements task-queue per this contract and satisfies every invariant it can hold.
- **Suite runs are serialized.** Only one subagent runs the suite at a time, because a per-file deadline counts wall time and a verdict measured under load is not a verdict.
- A rejected return becomes a repair brief to the same track.
- Neither track writes a record.
- The primary verifies each return in that track's own worktree, holds the records, and writes the verdict after merge.
