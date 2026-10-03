# Agent Handover

**Date:** 2026-09-29
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Housekeeping
**Status:** Closed

## Objective

Record the landed Track B task-queue deliverable and its features: the TypeScript pi-extension that implements the general sequencing primitive, the prompt that names its operations, and the conformance suite that holds its invariants. This is a bookkeeping iteration that closes the task-queue row; the code itself landed on the branch in the prior session.

## Scope

The M3.2.1 roadmap row `task-queue: general sequencing primitive`. This iteration records what landed, not builds it: the TS extension and its 12-tool surface, the `task-queue.md` prompt, the I1-I13 conformance suite and its harness wiring, the decisions that led to it, and the roadmap write-back that closes the row. It also fixes the lint blocker in `devlog/roadmap_future.md` (a duplicated `M4.6` block).

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | The Track B TS task-queue extension registers its 12 tools (`taskq_fork` through `taskq_worker_request`) and loads in a pi session | run `node --test tests/extensions/pi/task-queue/extension-load.test.ts` | Accepted |
| 2 | The I1-I13 queue invariants hold across the node conformance suite | run `node --test tests/extensions/pi/task-queue/*.test.ts` | Accepted (101/101) |
| 3 | The `task-queue.md` prompt is present and names the operations the extension enforces | read `src/reasoning/agent/prompts/task-queue.md` | Accepted |
| 4 | The task-queue prompt is a general sequencing primitive, not a task shape | read `src/reasoning/agent/prompts/task-queue.md` Purpose section | Accepted |

## Hot files

| File | Why in scope |
|---|---|
| `src/reasoning/providers/pi/config/agent/extensions/task-queue/*.ts` (12 files) | the landed Track B deliverable this handover records |
| `src/reasoning/agent/prompts/task-queue.md` | the prompt that names the operations the extension enforces |
| `tests/extensions/pi/task-queue/*.test.ts` + `tests/test_taskq.sh` | the I1-I13 conformance suite and its harness wiring |
| `devlog/handovers/archive/20260929-02-workflow-task_queue_prompt.md` | the prior task-queue iteration handover, admin-maintained to the landed state |
| `devlog/roadmap_future.md` | removed a duplicated `M4.6 -- Background Auto` block |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Track B (TS) is the delivered task-queue; roll our own, do not adopt pi-subagents | the comparison showed pi-subagents implements delegation, not a break-point queue; it holds no queue invariant I1-I5 and cannot serve the I7 bring-back scope | this handover + roadmap T4 |
| The extension enforces the queue as a durable state machine with a single atomic state write | structural atomicity makes I1, I4, I5, I11 hold by construction | spec record I11 |
| The queue records only requested break points and does not mark their kind | final vs regular is the primary's dequeue-handler decision | design record |
| Worker protocol is plain files in the worker's own worktree | any provider (a pi subagent, a bash harness) can participate without loading the extension | design record |
| Track A (bash) is shelved; nushell-revisit deferred to a future T4 language review | bash disqualified by the wall-clock cost of chasing I7/I11-I13 across 8 repair rounds; branch `exp/taskq-bash` packaged for reuse | this handover + roadmap T4 |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Track B reached a reviewer PASS under the strengthened I1-I13 contract; Track A reached PASS too but at a wall-clock cost that disqualifies bash for this feature | steering | Triaged to: Deprecated -- folded into prior handover `20260929-02` |
| The TS extension's 12-tool surface, prompt, and 101/101 conformance suite are landed and verified | scope change | Triaged to: Completed table |

## Completed

| File | What changed and why |
|---|---|
| `devlog/handovers/archive/20260929-03-chore-task_queue_ts_extension_features.md` | new handover recording the Track B task-queue deliverable and features |
| `devlog/handovers/archive/20260929-02-workflow-task_queue_prompt.md` | admin-maintained: acceptance criteria filled and marked, findings settled, Completed reflects the landed state, What's Next seeds the release gate |
| `devlog/roadmap.md` | task-queue general-sequencing-primitive row marked complete (write-back) |
| `devlog/roadmap_future.md` | removed the duplicated `M4.6 -- Background Auto` block |

## Deferred items

| Item | Reason |
|---|---|
| Adopt pi-subagents' patch-capture-before-removal ordering into the Track B merge | a Track B follow-up on roadmap T4; does not block the primitive |
| `/task-queue` per-prompt quality pass | sequenced after the prompt/skill authoring-guidelines convention (T1) lands |

## What's Next

M3.2.1 - Loops as Workflows, mid-milestone; roadmap maintenance done. The task-queue primitive reached its release gate.

Next in the sequence: the prompt/skill authoring-guidelines convention (T1), then the per-prompt quality passes with `/task-queue` first.

**Conclusions from this iteration:** task-queue is a general sequencing primitive, not a task-shaped prompt. The TS pi-extension implements the queue, the state machine, the fork, the merge, and the close; the prompt names the operations; the conformance suite holds I1-I13. `fanout` and a rewritten `parallel-auto` sit on the primitive.

**Grep or file reads to run at iteration start:** read `src/reasoning/providers/pi/config/agent/extensions/task-queue/index.ts` for the 12-tool surface; read `src/reasoning/agent/prompts/task-queue.md` for the prompt; read `tests/extensions/pi/task-queue/` for the conformance suite.
