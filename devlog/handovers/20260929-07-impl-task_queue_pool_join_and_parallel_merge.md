# Agent Handover

**Date:** 2026-09-29
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Implementation
**Status:** Closed

## Objective

Build and land two independent task-queue follow-ups in parallel, then merge them in dependency order (review-hardening first, pool join second) and verify the merged tree as a new state. The two tracks were: the pool join (roadmap row 91) and the review-hardening machine gates (roadmap row 92). This handover closes the pool-join side and the parallel merge; the review-hardening gate side is recorded in handover `20260929-06`.

## Scope

The task-queue TS extension and its conformance suite, both follow-ups riding on the close of the round-2 join surface (`7536273`). Review-hardening: mutation tier + BDD-lite invariant report. Pool join: `taskIds` pool mode of `taskq_join`. Parallel mechanism: the task-queue primitive itself, two independent worker worktrees, sequenced merge.

Out of scope: the adversarial novel-bug review (stays one focused reviewer), any transition-table change (batch-neutral by contract on both tracks).

## Parallel method

Two worker worktrees forked from `7536273`: `feat/review-hardening` and `feat/join-all`. Each brief prescribed the batch-neutral seam: `transitions.ts` untouched, overlap test files (`join/wired/transitions.test.ts`) untouched, J4 phrased as one held join-unit, tool surface unchanged. Each converged independently; the RH implementer timed out and the primary committed its staged segment per its closed handover. Merge order honored the one-directional dependency: review-hardening first, then pool join, so the pool lands on hardened test ground. Both task-queue break points passed terminal verification before either merged.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | `taskq_join` gains pool mode `taskIds`, blocking until every named task is ready then delivering the batch as one atomic transition | node suite, live pool probe | Met |
| 2 | The batch is atomic by construction (joinAllOp, a fold over joinOp threading derived state, so a throw aborts before any save) | node suite, mid-fold abort test | Met |
| 3 | Pool timeout is inert and names ready/missing; after it the operator joins any or single tasks | node suite | Met |
| 4 | J4 is one held join-unit (single or pool batch); `taskq_status` reports the batch as `holdTasks` | node suite | Met |
| 5 | The tool surface is unchanged (pool mode is a mode of join, not a new tool) | extension-load test | Met |
| 6 | Mutation tier: 22 cataloged breaks replay in a temp mirror and fail unless the owning suite turns red | `node --test tests/taskq/mutation.test.ts` | Met |
| 7 | BDD-lite invariant report: 22 named cases across 19 invariants, derived from the transition table, J4 phrased as join-unit | `node --test tests/taskq/invariants.test.ts` | Met |
| 8 | Seam honored on both branches: `transitions.ts` and the overlap test files unchanged | git diff vs baseline | Met |
| 9 | Merged tree is a coherent new state: full suite green after the sequence | node 264/264, harness 1004/1004, lint clean | Met |
| 10 | Integration finding resolved: the hold mutation re-anchored to `heldUnits`, 22 proven again | mutation gate output | Met |

## Hot files

| File | Why in scope |
|---|---|
| `src/reasoning/providers/pi/config/agent/extensions/task-queue/ops.ts` | `joinAllOp`, the fold over `joinOp` |
| `src/reasoning/providers/pi/config/agent/extensions/task-queue/join.ts` | pool face, `heldUnit`/`heldUnits`, shared head re-read |
| `src/reasoning/providers/pi/config/agent/extensions/task-queue/index.ts` | `taskIds` schema, three-mode tool description, `holdTasks` |
| `tests/taskq/mutation/catalog.ts` | the hold mutation re-anchored to `heldUnits` |
| `tests/taskq/pool-join.test.ts`, `pool-wired.test.ts` | new: the pool contract over the real tool surface |
| `tests/taskq/invariants.ts` | the invariant case catalog, J4 as one held join-unit |
| `tests/taskq/mutation/` | the mutation catalog and replay runner |
| `docs/adr/task_queue_primitive.md` | dated amendment section for the pool join and the gates |
| `devlog/roadmap.md` | rows 91 and 92 marked landed |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Run the two tracks in parallel, merge in dependency order | review-hardening must gate pool join; isolated construction honors "parallelize enumerable, serialize coupled judgment" | this handover |
| Batch-neutral seam on both branches | `transitions.ts` stays the single source; the report walks it structurally | this handover + both briefs |
| Re-anchor the hold mutation rather than weaken it | a survivor is a finding about the suite; the invariant still holds and must still be proven | this handover + ADR |
| Primary commits a timed-out worker's staged segment | the deliverable is the segment; the worker closed its handover before its timeout | this handover |
| Run the merged tree through the full gate suite as a final check | two converged branches are not one converged merge; Condition A | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The `join:hold-never-reported` mutation was unproven on the merged tree: pool join refactored the hold into `heldUnits`, so the single-join anchor text no longer matched | integration | Fixed: re-anchored to `heldUnits`, added the pool suite to its owners; 22/22 proven again |
| The RH implementer timed out before committing and issuing its terminal break point | process | Primary committed the staged segment per the closed handover and issued the break point |

## Completed

Both roadmap rows (91, 92) landed. Round-2 close chain (round 1 + round 2 + both repairs + these two follow-ups) is complete on `feat/M3_2_1-iteration-loops-workflow`. The task-queue primitive now has pool join and two machine gates, all seam-coherent.

## What's Next

- Seed the next iteration: the `/task-queue` per-prompt quality pass against the authoring conventions.
- The adversarial novel-bug review pass and the class-scoped collateral hunters stay open as review-policy follow-ups.
- Decide the regular mutation-run frequency (roadmap_future row 47) and process the 2026-09-26 mutation survivors (row 48).
