# Agent Handover

**Type:** plan -- renumber the future milestones under a Multi-Agent Coordination umbrella and land the task-queue and parallel-auto rows
**Date:** 2026-09-29
**Unit:** M3 T-track roadmap consolidation (operator direction 2026-09-28/29)
**Intent:** make M4 mean Multi-Agent Coordination, renumber the metadata, branch, dispatch, constraint, and CI/CD milestones under it, and record the task-queue and parallel-auto future tasks as roadmap rows.
**Status:** Closed

## Objective

Consolidate the future multi-agent milestones under one umbrella number and give the two autonomous-execution futures a roadmap home. `M4` becomes Multi-Agent Coordination, the parent of the renumbered metadata-seeding (M4.1), branch-management (M4.2), task-dispatch (M4.3), constraint-enforcement (M4.4), and review-and-CI-CD (M4.5) milestones. Two new sibling milestones carry the autonomous-execution futures: `M4.6 Background Auto` (parallel-auto) and `M4.7 task-queue`.

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
| task-queue (dash) is the prompt token | matches pi slash-command convention, so the file maps to `/task-queue` | roadmap_future.md M4.7 |
| `task-queue` is the operator-synchronous fan-out; `parallel-auto` becomes M4.6 background auto | the two gating contracts differ: task-queue pauses on operator decisions, parallel-auto runs unattended | roadmap_future.md M4.6/M4.7 |
| The `parallel-auto.md` prompt is not stubbed this iteration | this is a record-only `plan:` commit; prompt text is follow-on implementation | this handover |

## Completed

| File | Change |
|---|---|
| `devlog/roadmap_future.md` | M4 umbrella + M4.1-M4.5 renumber, merged the two `## Multi-Agent` headers, added M4.6 Background Auto and M4.7 task-queue rows |
| `devlog/roadmap.md` | summary table relabelled; T1 `parallel-auto` row marked done/relocated to M4.6; `fanout` row split (case 1 extracted to task-queue); two M4 metadata cross-refs to M4.1 |
| `devlog/changelog.md` | mutation-cadence "M4" to "M4.1" |
| `devlog/discussions/20260926-design-draft-mutation_corpus_runner.md` | "decided in M4" to "M4.1" |
| `docs/development/contributors.md` | "M4-M6" to "M4 (Multi-Agent Coordination, with M4.1-M4.7)" |
| `devlog/handovers/20260929-01-plan-multi_agent_coordination_umbrella.md` | this handover |

## Deferred items

- The `task-queue` prompt and the `parallel-auto` prompt stub are implementation work recorded on M4.7 and M4.6; not built this iteration.
- The old-M6 reference in `readme.md` ("Safe mode ... see M6") is a pre-existing staleness: Safe vs Unsafe Mode is M7 in the current table, a defect that predates and is independent of this renumber. Flagged, not fixed, to keep this commit scoped.

## What's Next

The autonomous-execution prompt track: build `task-queue` (M4.7) reusing the parallel-auto worktree-and-branch machinery, and stub `parallel-auto` as M4.6 background auto. Both land after the current M3.2.1 loop-to-workflow milestone, since they sit dormant under the M4 umbrella.
