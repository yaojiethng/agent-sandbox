# Agent Handover

**Date:** 2026-09-21
**Milestone:** M3 -- Autonomous Task Execution, Manual Review Workflow (major-loop planning)
**Type:** Plan -- reorganize the M3 roadmap into eight workstream tracks, propose resurrected M2 items, and route open feedback/gotchas into the tracks
**Status:** Closed

## Objective

Organize all current M3 roadmap items into eight named tracks, propose M2-era items for re-entry into those tracks, and give every open agent-feedback and gotchas entry a track destination.

## Scope

Planning output only -- no code or document rewrites beyond the roadmap reorganization, the feedback/gotchas routing and cleanup pass, and this handover's planning records. Phase 1 organizes existing M3 items into the eight operator-specified tracks (reorganize verbatim, then reword/combine). Phase 2 audits M2 deferred / stale-state / deprioritized items and resurrects three into tracks. Phase 3 routes every open/probation feedback and gotchas entry to a track, then runs a cleanup pass consolidating entries by shared roadmap solution and deleting confirmed-closed entries.

## Carried forward

None.

## Acceptance criteria

- [x] Phase 1: M3 roadmap reorganized into the eight tracks, T1-T8, with items combined and finding links pointing to live records
- [x] Phase 2: M2-era items audited; environment-change persistence added to T7, STE-clean sweep to T8, harness-sig cross-referenced in T4
- [x] Phase 3: every open/probation feedback and gotchas entry routed to a track; new roadmap rows created for the shared solutions
- [x] Cleanup pass: entries consolidated by shared roadmap solution (surviving entry in `AGENT_FEEDBACK.md`), confirmed-closed entries deleted, and each originating handover given a `[CORRECTION -- 2026-09-21]` reconciliation note; consolidation-and-deletion procedure added to the feedback/gotchas workflow policy
- [x] Lint gate clean across the iteration

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/roadmap.md`](devlog/roadmap.md) | M3 section reorganized into eight tracks |
| [`devlog/AGENT_FEEDBACK.md`](devlog/AGENT_FEEDBACK.md) | open entries get a track destination |
| [`devlog/GOTCHAS.md`](devlog/GOTCHAS.md) | open entries get a track destination |

## Decisions

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| Operator settled track placements: atomic install + semantic versioning under track 4 (Library migrations, subtask of the make evaluation); structured logs under track 5 (Archival, overlaps the new artifact-storage task); pre-snapshot validation gate under track 6; commit metadata under track 7 | steering | this iteration |
| Operator directed a two-pass write: reorganize first (await approval), then reword/combine/summarize | steering | this iteration |
| Operator directed a WIP commit mid-iteration; WIP commits have no codified rule. `docs/operations/git_policy.md` and the provider-layer `AGENTS.md` should document when WIP commits are acceptable (standard practice, not an exception), and that the delivery commit at iteration end still carries the type prefix | steering | roadmap |
| Full `scripts/lint.sh` takes ~30s because it lints every tracked file. The operator wants a way to lint only the newly changed files and an investigation into why the full run is so slow. Deferred to a later iteration (T2 perf / T3 backpressure neighbors); do not implement now | steering | next iteration |
| Operator directed that feedback/gotchas entries sharing a roadmap solution consolidate into a single entry (surviving in `AGENT_FEEDBACK.md` when a family spans both files), finalized during a cleanup pass with deletion of confirmed-closed entries, and that each deleted/merged entry gets a `[CORRECTION]` note in its originating handover to preserve history. Procedure written into the feedback/gotchas workflow policy | steering | this iteration |

## Completed

| File | Change |
|---|---|
| `devlog/roadmap.md` | M3 section reorganized into eight tracks; Phase 2 items added; Phase 3 shared-solution rows added (record write-back gate, evidence-validation, prompt-scope, doc-format lint, sourced-lib lint, tool-timeout, functional-stack, close-milestone, process-improvements rows) |
| `devlog/AGENT_FEEDBACK.md` | open/probation entries routed to tracks; cleanup pass consolidated 9 families into single dated entries and deleted confirmed-closed entries |
| `devlog/GOTCHAS.md` | routed entries to tracks; families spanning both files moved to `AGENT_FEEDBACK.md` |
| `devlog/discussions/20260809-design-settled-agent_feedback_and_gotchas_workflow.md` | added the consolidation-and-deletion cleanup-pass procedure |
| 15 handovers | each gained a `[CORRECTION -- 2026-09-21]` reconciliation note for closed/consolidated entries |
| `docs/development/bash-coding-conventions.md` | sections 4.4 and 4.5 added (sourced-lib reads; `--git-path` absolutization), resolving two Group-1 feedback entries |

## Deferred items

| Item | Reason | Destination |
|---|---|---|
| Changed-file-only lint + slowness investigation | not this iteration | T2 perf / T3 backpressure |
| WIP-commit policy documentation | planning record | roadmap T1 row |

## What's Next

The M3 roadmap is ready for the operator to pick chunks and promote them to sub-milestones. The eight tracks and their shared-solution rows are the working task list.
