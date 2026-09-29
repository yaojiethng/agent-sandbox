# Agent Handover

**Date:** 2026-09-29
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Workflow
**Status:** Active

## Objective

Build the `task-queue` general agent utility: a sequencing primitive (fork / synchronous operator join / re-queue) in `src/reasoning/agent/prompts/`, accepting a variety of task shapes.

## Scope

The M3.2.1 task-queue row. Build `src/reasoning/agent/prompts/task-queue.md` as a general sequencing primitive (fork / synchronous operator join / re-queue), reusing the machinery and measured results in `parallel-auto.md` and the `20260927-design-draft-parallel_auto_experiment.md` trial. The deliverable is the primitive only: `fanout` and a rewritten `parallel-auto` refactor onto it later. Update the roadmap rows: the task-queue row (general-utility shape) and a new `/auto` generalization consideration point.

## Carried forward

| Item | From handover |
|---|---|
| task-queue was recorded under a wrongly-created M4.7 future milestone; corrected to an active M3.2.1 task (`chore:` commit `bb826b4`) | 20260929-01-plan-multi_agent_coordination_umbrella |

## Acceptance criteria

Not yet defined.

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
| The fan-out experiment ran both tracks; both satisfied the shared invariant spec (bash: 1030/1030 suite, 28 units; TS: 79/79 node tests) | scope change | current iteration |
| Two independent thermo-nuclear reviews (deepseek-v4-flash, xhigh) both returned **Needs major rework**, converging on the same blocker class: non-atomic state transitions / close-path durability with no recovery. Bash also flagged the 1142-line monolith; TS was flagged as a wiring default + ordering, with the pure core judged right | steering | current iteration |
| Landing decision amended by the operator: Track B is adopt-vs-roll-our-own, decided by a comparison against a battle-tested extension (learning points), not an immediate fold-back; shelve Track A (bash) via /package-branch with a nushell-revisit task; iterate both tracks to a reviewer PASS against the strengthened I1-I13 contract | steering | current iteration + roadmap |
| Round-3 reviews (2026-09-29): **Track B (TS) reached PASS** ("Consensus reached -- no remaining defects at or above minor severity"; 4 minors + 4 nits recorded as follow-ups). Track A (bash) is iterating to PASS. Rounds to date (all via thermo-nuclear re-review of deepseek-v4-flash xhigh): R1 initial, R2 durability upkeep, R3 mid-loop brick/record-guards/merge-maze, R4 all-scope+fork-orphan window, R5 (HEAD `dd6e87b`) closed the all-scope tip-local recognition with an ancestry-based check + a verified-and-unrecorded abandon gate; R6 (HEAD `4fa7fbd`) closed the all-scope residue after burial and the partial abandon gate; R7 (HEAD `dde4b42`) is the structural restructure the round-6 review called for -- bring-back intent recorded atomically before applying, replacing the fragile residue-detection family (ancestry probe, tip-message probe, staged-subset recognition, verified=yes gate, merge-none hole) with a record-driven intent/ bring-back state; fork data-loss blocker closed via a clean-worktree `_task_queue_orphan_verdict`; git leaf split into `task_queue_git.sh` (408) + new `task_queue_merge.sh` (557). Suite 1080/1080, 78 conformance units. Round-7 review: still "Needs major rework" but confirmed the restructure is right and closed the two round-5 blockers with no test weakened. Round-8 repair (HEAD `1260106`, fix "close the round-7 task-queue defects", suite 1087/1087, 85 units) closed all three blockers (temp-file crash wedge via hidden `.tmp` sibling; committed-deletion resume via the shared `diff --cached --quiet $branch` probe; unchecked `reset --hard` via dropping the reset-failure short-circuit) plus defects 4-12 (unused-worktree gate deleted, per-op walk dedup to one, owner-marker + worktree-list cross-queue fork proof, honest header invariants, reachable kill windows) and the 6 minor findings. Its own independent re-review returned **PASS (adoptable)** -- the 8th-round re-review under the strengthened I1-I13 contract met convergence | steering | current iteration |
| **Track A (bash) reached review PASS at `1260106`.** But the wall-clock cost to get there is itself the signal: 8 repair rounds (plus the initial review) to chase invariants I7/I11-I13 through bash's non-atomic state, temp-name glob collisions, and a fragile residue recognizer -- each round closing blockers that revived in the next. The operator's framing for the record: this supports shelving Track A (bash) as the wrong language for this feature, alongside the existing nushell-revisit and bash-architecture (T4/T8) rows. Track A's branch is packaged (`exp/taskq-bash`) for reuse | steering | current iteration |
| All subsequent subagent runs use **opencode/space-bunny-free** at `--thinking xhigh` for lower token cost; prior rounds used opencode-go/deepseek-v4-flash at xhigh. (The model's `thinkingLevelMap` declares only off/minimal, but the opencode provider accepts the xhigh flag without error; dispatching at xhigh is directed by the operator.) Model switch is a cost measure, not a quality/consensus change | steering | current iteration |
| Comparison decision evaluated (2026-09-29): **roll our own -- keep Track B TS task-queue; do not adopt pi-subagents as the primitive** -- pi-subagents implements a different mechanism (delegation to child Pi sessions, sequenced by a JavaScript script held in one tool call); it holds no queue invariant I1-I5, has no break-point queue, and never writes a worker patch into the main tree so it cannot serve I7. Its worktree engine is genuinely stronger (patch-capture-before-removal, fail-closed rollback), so it is adopted as an adjacent dependency for delegation, and its patch-capture ordering is a Track B follow-up; the structural atomicity of our single state write is the deciding factor. Full report at `/tmp/taskq-comparison-report.md` | steering | roadmap T4 |
| Session reaches a natural stopping point: Track A (bash) packaged; Track B (TS) merged; no queued task-queue work remains. Track A's wall-clock signal (8 repair rounds to chase I7/I11-I13 through bash) supports shelving bash as the wrong language for this feature | steering | current iteration |
| nushell cannot be a pi extension, so even a nushell Task A would not flip the landing; it makes the branch worth revisiting | steering | roadmap (T4 nushell-revisit task) |

## Completed

No file changes this iteration.

## Deferred items

None.

## What's Next

M3.2.1 - Loops as Workflows, mid-milestone; roadmap maintenance not pending.

Next in the sequence after task-queue: the prompt/skill authoring-guidelines convention (T1), then the per-prompt quality passes with `/task-queue` first.

**Conclusions from this iteration:** task-queue is a general sequencing primitive, not a task-shaped prompt. It defines fork (worktree/branch/fresh-subagent), operator-synchronous join (re-orient and wait after each worker), and re-queue (same worker continues via the same pi session log). It accepts a variety of task shapes; `fanout` and a rewritten `parallel-auto` sit on it. It lives in `src/reasoning/agent/prompts/`.

**Grep or file reads to run at iteration start:** read `src/reasoning/agent/prompts/advisor.md` and `propagation-check.md` for the general-utility prompt form; read `workflow/coding-agent/prompts/parallel-auto.md` for the fork/merge machinery.
