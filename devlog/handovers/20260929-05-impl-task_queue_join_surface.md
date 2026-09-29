# Agent Handover

**Date:** 2026-09-29
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Implementation
**Status:** Closed

## Objective

Restructure the task-queue extension's operator-driving surface. Round 1 (landed in the working tree): the **fork + join** model - `taskq_join` as the single blocking call that subsumes `poll -> record -> schedule -> trigger` as one atomic transition; `taskq_fork` owns a canonical run-scoped worktree location. Round 2 (this iteration's scope): collapse the lifecycle to four value-free phases (`forked -> active -> terminated -> retired`), fuse merge with retire into one bring-back that writes a file set (possibly empty), add both re-queue routes, add the file-level ownership lock, the R12 transition table, and F3-F7. This is pre-reuse ergonomics hardening (roadmap row 90).

## Scope

The Task B TypeScript task-queue extension at `src/reasoning/providers/pi/config/agent/extensions/task-queue/`, its prompt `src/reasoning/agent/prompts/task-queue.md`, and the conformance suite `tests/taskq/*.test.ts`.

The end-user surface becomes: `taskq_fork`, `taskq_join`, `taskq_verify`, `taskq_proposal`, `taskq_merge` (fused bring-back, writes a file set, possibly empty), `taskq_close` (+ `taskq_worker_request` worker-side, `taskq_status` observability). Removed: the intermediate `poll/record/schedule/trigger` tools (subsumed by the join) and `taskq_retire` (fused into the bring-back). The lifecycle is `forked -> active -> terminated -> retired`; there is no `verified`/`failed`/`merged`/`discarded`. Both re-queue routes (in-place rollback-retry, fresh re-fork) exist and the main chooses. A file-level ownership lock at the state directory serializes cross-process writers and carries crash-debug metadata.

Out of scope: changing the queue mechanics I1-I13' ordering/durability core, or `pi-subagents` adoption (deferred to M4).

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | `taskq_join` subsumes poll/record/schedule/trigger as one atomic transition and returns the join payload exactly once | node conformance suite, new join tests | Met |
| 2 | `taskq_join` blocks (with a required `timeoutMs`) until a break point is ready, never sleep-polls, and a timeout return is inert (consumes nothing) | new join tests, drive with a live worker request | Met |
| 3 | At most one join is held at a time; a second `taskq_join` does not deliver a concurrent payload | new join test | Met |
| 4 | Join selection preserves per-task request order; cross-task is the primary's choice | new join test | Met |
| 5 | `taskq_fork` cuts worktree + branch to a canonical run-scoped path, requires no pre-creation, and reports branch-exists with the documented error | existing + new fork tests | Met |
| 6 | `taskq_join` contract (blocking, timeout, one-held, what one call does) is documented in the tool description and the prompt, drawing on the fork/join idea | read tool description + prompt | Met |
| 7 | No stale `poll`/`record`/`schedule`/`trigger` name survives in the normal-loop surface, prompt, or tests | grep the extension + prompt + tests | Met |
| 8 | The pre-existing I1-I13 conformance suite stays green under the restructure | run `node --test tests/taskq/*.test.ts` (baseline 101/101) | Met |
| 9 | Round 2: the lifecycle is four value-free phases with no `verified`/`failed`/`merged`/`discarded`; the bring-back fuses merge+retire and writes a file set (possibly empty); both re-queue routes exist; the ownership lock serializes cross-process writers | node suite + harness + confirm-review probe | Met |
| 10 | The bring-back's resumed path infers a write only from an outbox intent record, refuses `bring-back-unprovable` without evidence, and holds the exactly-once / idempotent-sink edge | confirm-review AWS-catalog edge walk | Met |
| 11 | The ownership lock holds across a synchronous section only (D3 guard); a re-queued task's hold names the worker's next request, not the completed break point (D4) | confirm-review probes | Met |
| 12 | Round 2 converges: the independent confirmation review returns CONVERGED with all invariants holding | thermo-nuclear confirmation review | Met |

## Hot files

| File | Why in scope |
|---|---|
| `src/reasoning/providers/pi/config/agent/extensions/task-queue/index.ts` | tool registration; the join and the fork workdir changes land here |
| `src/reasoning/providers/pi/config/agent/extensions/task-queue/run.ts` | the run-ops that the join's atomic subsumption executes |
| `src/reasoning/providers/pi/config/agent/extensions/task-queue/worktree.ts` | canonical run-scoped fork location and the single-writer doc |
| `src/reasoning/agent/prompts/task-queue.md` | the primary's loop instructions rewrite for the join-driven loop |
| `tests/taskq/*.test.ts` | new join/fork-suite tests; the I1-I13 baseline stays green |
| `docs/adr/task_queue_primitive.md` | update after convergence with the locked fork+join surface contract |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The operator-driving surface is fork + join; the driver chain is subsumed | the intervening state management (poll/record/schedule/trigger) is no decision, only mechanism; exposing it creates a call-out-of-order error surface that subsumption eliminates by construction | this handover |
| `taskq_join` is the blocking join; a timeout is required and preferred over any sleep | a timeout is the correct wait primitive; a sleep-poll is a bad one. Fit to the familiar fork/join ideas | this handover |
| The join does consume -> record -> schedule -> trigger as one atomic transition (I11) | structural atomicity keeps exactly-once (I1, I5) and no-partial (I12) by construction | this handover |
| `taskq_fork` owns a canonical run-scoped worktree location; no pre-creation | removes the branch-exists collision and the caller-worktree surprise (observed ergonomic failure) | this handover |
| No spec document; the task contract lives in this handover + a `/tmp` brief passed to the subagent | the durable record stays; the brief is ephemeral, subsumed into the review loop | this handover |
| The intermediate tools are removed, not deprecated | every one of them is a way to create a break point the join then has to heal; the heal path is a state a real caller should never reach | this handover |
| The worktree root is a sibling of the repository, not `<repo>/.worktrees` | a worktree inside the main tree dirties the tree the merge gate reads, which breaks the single-writer rule | this handover |
| A hold is derived from state, not a separate flag | a flag the primary had to clear would be a step the loop could forget; the entry state and the task phase already say what is undecided | this handover |
| The state machine is one explicit transition table | a formally verified pipeline spec hands the edge-case catalog, not implementable code; at this scale the lightweight form is one machine-checked from-state x action table that the suite walks | this handover + ADR R12 |
| No formal-verification toolchain; reference formal catalogs only | the primitive holds exactly-once and atomicity by construction (R9); a formal tool adds an unmonitored surface at wrong scale, while public formal catalogs (AWS SQS TLA+, exactly-once streams) serve as an edge-case checklist against I1-I13 | this handover + ADR rejected alternatives |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The 7-phase / 12-tool surface reads as more complex than the conceptual fork/wait/join/done loop | scope change | Triaged to: the S1/S2 consolidation, written into this handover's surface contract |
| `taskq_join`'s blocking-with-timeout replaces the sleep-poll knowledge gap | steering | Triaged to: the join contract documentation below |
| The scan keyed the request by file name and the archive by content id, so a hand-written document could enter the queue under two ids | defect (review round 1) | Fixed: the scan skips a document whose name and content disagree, with a notice |
| A `..` in a task id walked out of the run-scoped worktree root, so two runs could share the path | defect (review round 1) | Fixed: the fork schema and `canonicalWorkdir` both refuse a task id that is not one path segment |
| A terminal hold never cleared on a re-request, which wedged a worker that kept working past its own terminal request | defect (review round 1) | Fixed: a re-request disarms the hold, terminal or regular |
| The join exposed the intermediate break-point states as a surface a caller could drive out of order | scope | Triaged to: the tools are removed, the ops stay as internal units |

## Completed

| File | What changed and why |
|---|---|
| `extensions/task-queue/join.ts` (new) | The join driver: the scan that validates request documents, the hold predicate, the blocking wait with a required timeout, and the join payload. Pi-free, so the contract is testable without the tool surface. |
| `extensions/task-queue/ops.ts` | Round 1 `joinOp` (record/schedule/trigger as one derivation); round 2 `verifyOp` usable/not-usable, `requeueOp` (in-place/fresh, records `requeuedFromEntryId`), `bringBackOp` fused write-file-set + prune + retire over the outbox intent. |
| `extensions/task-queue/index.ts` | Surface is fork, join, verify, proposal, bring-back, close, status, worker request. Round 1 subsumed poll/record/schedule/trigger into the join; round 2 fuses bring-back (merge+retire), wires the R12 transition-table consult, the ownership lock, the re-queue routes, the `stateDir/bringback/<taskId>.json` intent record, and the synchronous-section guard. |
| `extensions/task-queue/lock.ts` (new) | The file-level ownership lock: `O_EXCL`, owner metadata (pid/session/task/worktree/start/heartbeat), stale takeover, `beat` at git steps, and the sync-guard (`SyncResult`). |
| `extensions/task-queue/transitions.ts` (new) | The R12 transition table and its lookup helpers, one typed constant walked by the suite. |
| `extensions/task-queue/tasks.ts` | TaskPhase narrowed to forked/active/terminated/retired; gates consult the table. |
| `src/reasoning/agent/prompts/task-queue.md` | Round 2: the four-phase map, usable/not-usable audit, both re-queue routes, packaged-branch durability, fused bring-back and the empty file set, one-primary-per-directory and the lock, `bring-back-unprovable` failure mode. |
| `tests/taskq/lock.test.ts`, `transitions.test.ts`, `fixtures/*` (new) | The lock (two-process, stale takeover, sync guard) and the R12 table walk + reachability/terminability. |
| `docs/adr/task_queue_primitive.md` | Round 2 entry + confirmation-review entry with label clarification, the finding-6 recorded trade, and the R12/R13/R14 requirements. |
| `extensions/task-queue/worktree.ts` | Round 1: the run-scoped canonical worktree path plus the pre-flight collision check; round 2: `rollbackWorktree` (in-place re-queue) and the `assertPrunable`/`strayPaths` refusal factored out of `pruneWorktree`. |
| `extensions/task-queue/errors.ts` | The `join-contended`, `worktree-occupied`, `bring-back-unprovable` codes. |
| `extensions/task-queue/run.ts` | The synchronous-section guard (`requireSync`) in the transact path. |
| `tests/taskq/join.test.ts` (new) | The join's contract against real repositories: atomic subsume and the heal path, exactly-once under racing joins, blocking and inert timeout, one held break point, order-safe selection, the worktree contract, and the whole written loop from fork to close. |
| `tests/taskq/wired.test.ts` | The loop driven through the registered tools, plus the canonical fork path, the pre-created-worktree refusal, and a join timeout that consumes nothing. |
| `tests/taskq/extension-load.test.ts` | The registered surface, and the guard that no intermediate tool exists. |
| `docs/adr/task_queue_primitive.md` | The fork and join surface, its requirements, and the rejected alternatives. |

## Deferred items

- The cross-process serialization is closed by the ownership lock; one primary per state directory is the scoped contract.
- The per-prompt quality pass over `task-queue` is a separate roadmap row; this change only restructures the loop it describes.
- Round-2 scheduled repairs (ADR + roadmap follow-on): the retired-with-surviving-worktree different-file-set refusal (finding 1), the post-re-queue hold `requestStatus` correction (finding 2), and the D2 stale-break TOCTOU, D5 gate-row coupling, D7 lock-serialization positive test, D8 `writeWorkerRequest` O_EXCL, D9 `saveState` fsync.
- `taskq_status` and `taskq_retire` are registered but not named in `task-queue.md` at HEAD (pre-existing round-1 gap).

## What's Next

- Seed the next iterations: the `task-queue` pool join (`join_all`) row and the review-hardening machine-gates row, both follows laid on this primitive; the `/task-queue` per-prompt quality pass against the authoring conventions; the scheduled round-2 repairs above.

The round-2 convergence: three thermo-nuclear reviews (NOT CONVERGED x2 on bring-back non-atomicity and unsound resumed-path inference, then CONVERGED after the outbox-intent, sync-guard, and re-queue-hold repairs). The migrated-invariant verification: 202/202 node tests, 1004/1004 harness, lint clean.
