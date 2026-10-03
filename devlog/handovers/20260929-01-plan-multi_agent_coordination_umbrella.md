# Agent Handover

**Type:** plan -- renumber the future milestones under a Multi-Agent Coordination umbrella and land the task-queue and parallel-auto rows
**Date:** 2026-09-29
**Unit:** M3 T-track roadmap consolidation (operator direction 2026-09-28/29)
**Intent:** make M4 mean Multi-Agent Coordination, renumber the metadata, branch, dispatch, constraint, and CI/CD milestones under it, and record the task-queue and parallel-auto future tasks as roadmap rows.
**Status:** Closed

## Objective

Consolidate the future multi-agent milestones under one umbrella number and give the two autonomous-execution futures a roadmap home. `M4` becomes Multi-Agent Coordination, the parent of the renumbered metadata-seeding (M4.1), branch-management (M4.2), task-dispatch (M4.3), constraint-enforcement (M4.4), and review-and-CI-CD (M4.5) milestones. `M4.6 Background Auto` carries the parallel-auto future. [CORRECTION -- 2026-09-29] The task-queue row was recorded under `M4.7` in this iteration; it is not a future milestone. task-queue is an active M3.2.1 task (parallel fan-out with the operator as the synchronous bottleneck). `M4.7` does not exist; the `M4.7 task-queue` section added here was retired in the correction.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | The M4 umbrella and M4.1-M4.5 exist in `roadmap_future.md`, the duplicate `## Multi-Agent` headers merged | read the section | Agent [x] accepted |
| AC2 | `task-queue` and `parallel-auto`/background-auto have own rows under the umbrella | read the section | Agent [x] accepted |
| AC3 | The active `roadmap.md` summary table and every cross-reference to the old M4/M5/M6 names updated | grep `M5`/`M6` | Agent [x] accepted |
| AC4 | The T1 `parallel-auto` row retired; `fanout` row split so case (1) is extracted to task-queue | read T1 | Agent [x] accepted |
| AC5 | Lint clean; suite green | `scripts/lint.sh`, `scripts/run_tests.sh` | Agent [x] accepted: 0 findings; 1002/1002 |
| AC6 | Landed as one `plan:` commit, handover `Status: Closed` | `git log` | Agent [x] accepted |

## Hot files

| File | Why in scope |
|---|---|
| `devlog/roadmap_future.md` | M4 umbrella regrouping + the two new rows |
| `devlog/roadmap.md` | summary table, T1 `parallel-auto` retirement, `fanout` split, two M4 cross-refs |
| `devlog/changelog.md` | mutation-cadence "M4" pointer updated to M4.1 |
| `devlog/discussions/20260926-design-draft-mutation_corpus_runner.md` | "decided in M4" updated to M4.1 |
| `docs/development/contributors.md` | "M4-M6" pointer updated to the umbrella |
| `devlog/handovers/20260929-01-plan-multi_agent_coordination_umbrella.md` | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| M4 means Multi-Agent Coordination, the parent of the five renumbered sub-milestones | a single umbrella number over the multi-agent track; metadata seeding is not multi-agent, so it nests rather than sits alongside | roadmap_future.md + this handover |
| task-queue (dash) is the prompt token | matches pi slash-command convention, so the file maps to `/task-queue` | the M3.2.1 task-queue row (not M4.7, which this iteration wrongly created) |
| `task-queue` is the operator-synchronous fan-out; `parallel-auto` becomes M4.6 background auto | the two gating contracts differ: task-queue pauses on operator decisions, parallel-auto runs unattended | `parallel-auto` is under M4.6; task-queue is an M3.2.1 task |
| `parallel-auto` belongs in M4.6 Background Auto | the M4.6 number was correct; only the task-queue placement was wrong | roadmap_future.md M4.6 |
| The `parallel-auto.md` prompt is not stubbed this iteration | this is a record-only `plan:` commit; prompt text is follow-on implementation | this handover |

## Completed

| File | Change |
|---|---|
| `devlog/roadmap_future.md` | M4 umbrella + M4.1-M4.5 renumber, merged the two `## Multi-Agent` headers, added the M4.6 Background Auto row; [CORRECTION -- 2026-09-29] the M4.7 task-queue row was retired and task-queue moved to M3.2.1 |
| `devlog/roadmap.md` | summary table relabelled; T1 `parallel-auto` row marked done/relocated to M4.6; `fanout` row split (case 1 extracted to task-queue); two M4 metadata cross-refs to M4.1 |
| `devlog/changelog.md` | mutation-cadence "M4" to "M4.1" |
| `devlog/discussions/20260926-design-draft-mutation_corpus_runner.md` | "decided in M4" to "M4.1" |
| `docs/development/contributors.md` | "M4-M6" to "M4 (Multi-Agent Coordination, with M4.1-M4.7)"; [CORRECTION -- 2026-09-29] updated to state task-queue is an active M3.2.1 task and the umbrella is M4.1-M4.6 |
| `devlog/handovers/20260929-01-plan-multi_agent_coordination_umbrella.md` | this handover |

## Deferred items

- The `task-queue` prompt is implementation work recorded on the M3.2.1 task row; not built this iteration. [CORRECTION -- 2026-09-29] This iteration recorded task-queue under `M4.7`; the correction moves it to M3.2.1. The `parallel-auto` prompt stub is recorded on M4.6; not built this iteration.
- The old-M6 reference in `readme.md` ("Safe mode ... see M6") is a pre-existing staleness: Safe vs Unsafe Mode is M7 in the current table, a defect that predates and is independent of this renumber. Flagged, not fixed, to keep this commit scoped.

## What's Next

The autonomous-execution prompt track: build the `task-queue` prompt (an active M3.2.1 task) reusing the parallel-auto worktree-and-branch machinery, and stub `parallel-auto` as M4.6 background auto. [CORRECTION -- 2026-09-29] task-queue belongs to M3.2.1 and is ready to start; it is not a dormant M4 future. `parallel-auto` remains under M4.6 Background Auto.
