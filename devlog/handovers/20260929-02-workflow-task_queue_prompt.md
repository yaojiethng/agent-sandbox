# Agent Handover

**Date:** 2026-09-29
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Workflow
**Status:** Closed

## Objective

Build the `task-queue` general agent utility: a sequencing primitive (fork / synchronous operator join / re-queue) in `src/reasoning/agent/prompts/`, accepting a variety of task shapes.

## Scope

The M3.2.1 task-queue row. Build `src/reasoning/agent/prompts/task-queue.md` as a general sequencing primitive (fork / synchronous operator join / re-queue), reusing the machinery and measured results in `parallel-auto.md` and the `20260927-design-draft-parallel_auto_experiment.md` trial. The deliverable is the primitive only: `fanout` and a rewritten `parallel-auto` refactor onto it later. Update the roadmap rows: the task-queue row (general-utility shape) and a new `/auto` generalization consideration point.

## Carried forward

| Item | From handover |
|---|---|
| task-queue was recorded under a wrongly-created M4.7 future milestone; corrected to an active M3.2.1 task (`chore:` commit `bb826b4`) | 20260929-01-plan-multi_agent_coordination_umbrella |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | The Track B TS task-queue extension registers its 12 tools (`taskq_fork` through `taskq_worker_request`) and loads in a pi session | run `node --test tests/taskq/extension-load.test.ts` | Accepted |
| 2 | The I1-I13 queue invariants hold across the node conformance suite | run `node --test tests/taskq/*.test.ts` | Accepted (101/101) |
| 3 | The `task-queue.md` prompt is present and names the operations the extension enforces | read `src/reasoning/agent/prompts/task-queue.md` | Accepted |
| 4 | The task-queue prompt is a general sequencing primitive, not a task shape | read `src/reasoning/agent/prompts/task-queue.md` Purpose section | Accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`src/reasoning/agent/prompts/task-queue.md`](../src/reasoning/agent/prompts/task-queue.md) | the deliverable, built this iteration |
| [`workflow/coding-agent/prompts/parallel-auto.md`](../workflow/coding-agent/prompts/parallel-auto.md) | the machinery task-queue reuses |
| [`devlog/discussions/20260929-design-draft-task_queue_general_sequencing_primitive.md`](../devlog/discussions/20260929-design-draft-task_queue_general_sequencing_primitive.md) | the design record for this iteration |
| [`devlog/discussions/20260927-design-draft-parallel_auto_experiment.md`](../devlog/discussions/20260927-design-draft-parallel_auto_experiment.md) | the measured trial behind the machinery |
| [`devlog/roadmap.md`](../devlog/roadmap.md) | task row marked complete at close |
| [`devlog/handovers/20260929-02-workflow-task_queue_prompt.md`](../devlog/handovers/20260929-02-workflow-task_queue_prompt.md) | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| task-queue is a general agent utility in `src/reasoning/agent/prompts/`, not a loop workflow | it is a sequencing primitive that accepts many task shapes | design record |
| re-queue = same worker continues, via the same directory and the same pi session log | pi's active session branch supplies the conversation history, so same-worker and fresh-dispatch-on-same-log are the same agent state | design record |
| this iteration delivers the primitive only; `fanout` and a rewritten `parallel-auto` refactor onto it later | parallel-auto is badly shaped because it mixes fork with task shape and gating; task-queue is its prerequisite | design record |
| Keep worktree and branch in the primitive's contract | it is what makes the coding-agent fork safe, mergeable, and verifiable per-track | design record |
| a `/auto` primitive-generalization consideration is logged for a future session | raised by the operator (2026-09-29) | roadmap M3.2.1 |
| iterate both tracks to a reviewer PASS, then land Track B (TS); shelve Track A (bash) with /package-branch and a nushell-revisit task | land the pi-extension reachability; keep the bash variant reviewable behind a possible nushell rewrite | this handover + roadmap T4 |
| sequencing: task-queue initial write -> conventions doc -> per-prompt quality passes (task-queue first) | per-prompt quality passes read against the convention; task-queue is the first prompt the convention is applied to | this handover + roadmap M3.2.1 and T1 |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The fan-out experiment ran both tracks; both satisfied the shared invariant spec (bash: 1030/1030 suite, 28 units; TS: 79/79 node tests) | scope change | Triaged to: Completed table (both tracks recorded) |
| Two independent thermo-nuclear reviews (deepseek-v4-flash, xhigh) both returned **Needs major rework**, converging on the same blocker class: non-atomic state transitions / close-path durability with no recovery. Bash also flagged the 1142-line monolith; TS was flagged as a wiring default + ordering, with the pure core judged right | steering | Triaged to: Decisions (landing decision) + Agreement protocol |
| Landing decision amended by the operator: Track B is adopt-vs-roll-our-own, decided by a comparison against a battle-tested extension (learning points), not an immediate fold-back; shelve Track A (bash) via /package-branch with a nushell-revisit task; iterate both tracks to a reviewer PASS against the strengthened I1-I13 contract | steering | Triaged to: Decisions table + roadmap T4 |
| Track B (TS) task-queue reached **PASS** under the strengthened I1-I13 contract (independent thermo-nuclear review, "Consensus reached -- no remaining defects at or above minor severity"; 4 minors + 4 nits recorded as follow-ups). Track A (bash) reached PASS at its 8th repair round but at a wall-clock cost that disqualifies bash for this feature; both tracks converged under the same invariant set | steering | Triaged to: roadmap (row Landed) + Completed table |
| **Track A (bash) reached review PASS at `1260106`.** But the wall-clock cost to get there is itself the signal: 8 repair rounds (plus the initial review) to chase invariants I7/I11-I13 through bash's non-atomic state, temp-name glob collisions, and a fragile residue recognizer -- each round closing blockers that revived in the next. The operator's framing for the record: this supports shelving Track A (bash) as the wrong language for this feature, alongside the existing nushell-revisit and bash-architecture (T4/T8) rows. Track A's branch is packaged (`exp/taskq-bash`) for reuse | steering | Triaged to: roadmap T4 (nushell-revisit + bash-architecture) |
| All subsequent subagent runs use **opencode/space-bunny-free** at `--thinking xhigh` for lower token cost; prior rounds used opencode-go/deepseek-v4-flash at xhigh. (The model's `thinkingLevelMap` declares only off/minimal, but the opencode provider accepts the xhigh flag without error; dispatching at xhigh is directed by the operator.) Model switch is a cost measure, not a quality/consensus change | steering | Triaged to: roadmap (single-source recommendation convention) |
| Comparison decision evaluated (2026-09-29): **roll our own -- keep Track B TS task-queue; do not adopt pi-subagents as the primitive** -- pi-subagents implements a different mechanism (delegation to child Pi sessions, sequenced by a JavaScript script held in one tool call); it holds no queue invariant I1-I5, has no break-point queue, and never writes a worker patch into the main tree so it cannot serve I7. Its worktree engine is genuinely stronger (patch-capture-before-removal, fail-closed rollback), so it is adopted as an adjacent dependency for delegation, and its patch-capture ordering is a Track B follow-up; the structural atomicity of our single state write is the deciding factor. Full report at `/tmp/taskq-comparison-report.md` | steering | Triaged to: roadmap T4 + this handover Decisions |
| nushell cannot be a pi extension, so even a nushell Task A would not flip the landing; it makes the branch worth revisiting | steering | Triaged to: roadmap T4 (nushell-revisit task) |

## Completed

| File | What changed and why |
|---|---|
| `src/reasoning/providers/pi/config/agent/extensions/task-queue/*.ts` (12 files) | the Track B TS pi-extension that implements the queue state machine, fork, merge, and close |
| `src/reasoning/agent/prompts/task-queue.md` | the task-queue general-sequencing-primitive prompt that names the operations the extension enforces |
| `tests/taskq/*.test.ts` (11 files) + `tests/test_taskq.sh` | the node conformance suite (I1-I13) and its harness wiring |
| `devlog/discussions/20260929-spec-task_queue_fanout_contract.md` | the shared I1-I13 fan-out contract |
| `devlog/discussions/20260929-design-draft-task_queue_general_sequencing_primitive.md` | the design record |
| `devlog/roadmap_future.md` | removed the duplicated `M4.6 -- Background Auto` block (lint blocker) |

## Deferred items

| Item | Reason |
|---|---|
| Adopt pi-subagents' patch-capture-before-removal ordering into the Track B merge | a Track B follow-up; does not block the primitive |
| Track A (bash) shelved; nushell-revisit on a future T4 language review | bash disqualified by wall-clock durability cost; branch `exp/taskq-bash` packaged for reuse |

## What's Next

M3.2.1 - Loops as Workflows, mid-milestone; roadmap maintenance done. The task-queue primitive (Track B TS) landed and its conformance suite passes (101/101 node tests); the roadmap row `task-queue: general sequencing primitive` is marked complete.

The task-queue work reaches the release gate here. The prompt/skill authoring-guidelines convention (T1) comes next, then the per-prompt quality passes with `/task-queue` first (the new tracker this release's iteration). The tracked B follow-up (pi-subagents patch-capture ordering) and the nushell-revisit defer to their named roadmap rows.

**Conclusions from this iteration:** task-queue is a general sequencing primitive, not a task-shaped prompt. It defines fork (worktree/branch/fresh-subagent), operator-synchronous join (re-orient and wait after each worker), and re-queue (same worker continues via the same pi session log). The queue is the load-bearing form: it records only requested break points, does not mark their kind, and the primary's dequeue handle decides regular vs final. It accepts a variety of task shapes; `fanout` and a rewritten `parallel-auto` sit on it. It lives in `src/reasoning/agent/prompts/`.

**Grep or file reads to run at iteration start:** read `src/reasoning/agent/prompts/advisor.md` and `propagation-check.md` for the general-utility prompt form; read `workflow/coding-agent/prompts/parallel-auto.md` for the fork/merge machinery.
