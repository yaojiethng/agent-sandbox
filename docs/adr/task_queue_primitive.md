# Task-Queue Primitive

**Current:** 2026-09-29
**Status:** active

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | Durable exactly-once queue | A break point enters the queue exactly once and is dequeued exactly once (I1, I5) |
| R2 | Order preserved per task | Break points trigger in request order per task (I2) |
| R3 | Legal transitions only | A break point moves requested -> scheduled -> triggered, only in that order (I4) |
| R4 | Single-writer on the main tree | No worker's write lands in the main tree except through the primary's merge (I6) |
| R5 | Verdict-scoped bring-back | The merge applies exactly the operator's all/partial/none verdict over the write-back proposal (I7) |
| R6 | Verification at termination only | Final verification runs only at the worker's terminal break point, before any merge (I8, I9) |
| R7 | Worktree hygiene at clean close | Every worktree and branch is retired or pruned at a clean, resumable close (I10, I13) |
| R8 | Single atomic transition | Each transition is one atomic write; a crash leaves the queue resumable at the prior state (I11, I12) |
| R9 | Structurally atomic | I1/I4/I5 hold by construction, not by enforced checks |

## 2026-09-29 -- The general sequencing primitive

**Decision:** task-queue is a general sequencing primitive (fork / operator-synchronous join / re-queue) in `src/reasoning/agent/prompts/`, implemented by the Track B TypeScript pi-extension (`src/reasoning/providers/pi/config/agent/extensions/task-queue/`). It owns the fork procedure, the join, the re-queue rule, the write-back proposal construction, the single-writer rule, the final per-track verification, the verdict-scoped merge, and the records. It does not own a task shape; a caller supplies segmentation and well-formedness. The unit of fork-and-join is the segment ending at a worker-requested break point. The queue records only requested break points and does not mark their kind; final-versus-regular is the primary's dequeue-handler decision. Durability is per-run-state: one `state.json` outside the main tree holds the queue, task records, and the exactly-once request map; operations are pure functions, so I1/I4/I5/I11 hold by construction.

**Rationale:** The primitive must separate the sequencing mechanism from the task shape, which the coupled `parallel-auto` prompt blurs. A segment-based fork/join/re-queue model lets the operator's decision rate pace the wall clock and breaks the mechanism at arbitrary points in a task's lifecycle. A durable, exactly-once, single-atomic-write queue is the load-bearing form: the two independent thermo-nuclear reviews converged on non-atomic transitions and non-resumable close as the blocker, so I11-I13 are first-class rather than an afterthought. Single-writer discipline and verdict-scoped bring-back make the acceptance judgement clean and structural. TypeScript holds the invariants by construction and makes them unit-testable as pure functions, which shipped the invariant set far earlier in a reviewer PASS than bash.

**Rejected alternatives:**

- Track A (bash): rejected for the durability and maintainability wall-clock -- 8 repair rounds (plus the initial review) chased I7/I11-I13 through bash's non-atomic state, a temp-file crash wedge every reader read as a queue entry, a committed-deletion resume gap, an unchecked `reset --hard`, and a rebuilt residue recognizer. Bash offers no enforced module boundary, so safety came from reviewer-discovered fixes, not the language (execution). Retained behind a nushell-revisit row.
- Adopt `pi-subagents` as the primitive: rejected because it implements a different mechanism (delegation to child Pi sessions sequenced by a JavaScript script in one tool call), holds no queue-class invariant I1-I5, and never writes a worker patch into the main tree, so R5 (I7), the invariant the primitive exists to serve, is unreachable by adoption (intent). Its worktree engine's patch-capture-before-removal and fail-closed rollback are adopted as adjacent follow-ups, and the package stays usable for delegation.
- A coupled `parallel-auto`-style task-shaped prompt without a separate primitive: rejected as the defect itself -- it mixes fork, task shape, and gating contract in one prompt (intent).

**Edge cases / drivers:** The acceptance judgement at the final break point reuses the same join as a regular break point, with a terminal verdict added. The bring-back scope (all/partial/none) is validated as a subset of the write-back proposal; a partial verdict must name a non-empty subset held by the proposal. Same-worker re-queue maps to pi's `--continue`/`--fork` on the same session log and directory, so "same worker" and "fresh dispatch on the same log" are the same agent state by construction. A task with no defined break points is a single-segment task that runs to completion. The open interface ergonomics -- the missing first-class wait, the under-documented fork `workdir` contract, and the state surface exceeding the conceptual five-state loop -- do not block the primitive and are the next Track B fixes.
