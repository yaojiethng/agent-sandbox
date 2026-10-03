# Agent Handover

**Type:** workflow -- M3.2.1 task reorganization and workflow scaffolding
**Date:** 2026-09-28
**Unit:** M3.2.1 roadmap reorganization (operator 2026-09-28)
**Intent:** reorganize the M3.2.1 task list into the approved consolidated layout (one improvement task per workflow, one general docs/ADR task, two new real tasks), fix the compaction violation on the U1-U5 migration parent, drop-and-replace the stale-artifact row, and seed new workflow scaffolds.
**Status:** Closed

## Objective

The M3.2.1 task list carries the completed U1-U5 migration as an unmarked parent and a stale-artifact row whose remaining need (manual administrative close checklist) is still open. This iteration reorganizes the task list to the operator-approved structure and seeds the workflow scaffolds the new tasks name. The AC-machinery task decomposes: plan is done, chore needs no AC task, docs becomes a standalone `/document` runbook. Two new real tasks enter: the `/wrapup` close-mechanics runbook (reintroduced as the one-owner home for post-gate-3 steps) and the maintenance runbook (exhaustive administrative staleness).

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | The U1-U5 migration parent is compacted to a single `- [x]` outcome summary; no completed task group remains unmarked | read the M3.2.1 root rows | Agent [x] accepted: parent compacted to one outcome summary, U1-U5 now prose in it |
| AC2 | The stale-artifact row is dropped and replaced by the maintenance-runbook task, carrying the corrected fact (manual admin close checklist is still open, now owned by the maintenance runbook); the open need is not erased | read the M3.2.1 root rows; grep "manual admin" | Agent [x] accepted: row dropped, maintenance runbook owns the open manual-close-checklist need |
| AC3 | The AC-machinery task is decomposed: plan and chore covered (no task), docs becomes the standalone `/document` task | read the M3.2.1 root rows | Agent [x] accepted: no AC-machinery row remains; `/document` is the standalone docs-session task |
| AC4 | The M3.2.1 task list matches the approved layout: one improvement task per loop workflow, one general docs/ADR task, `/document`, `/wrapup`, maintenance runbook | read the M3.2.1 root rows against the approved proposal | Agent [x] accepted: all rows present |
| AC5 | The `/document` stub prompt exists as `workflow/coding-agent/prompts/document.md` carrying the infodump: read/lint-observable AC deltas, advisor, documentation-pass/conventions/writing-standards compliance, grill-me alignment, workflow-document identification and presentation rules | read the stub | Agent [x] accepted: infodump complete |
| AC6 | Lint clean | `scripts/lint.sh` | Agent [x] accepted: 0 findings |
| AC7 | Landed as one `workflow:` commit, handover `Status: Closed` | `git log` | Agent [x] accepted |

## Hot files

| File | Why in scope |
|---|---|
| `devlog/roadmap.md` | M3.2.1 reorganization: compaction, drop-and-replace, new task rows |
| `workflow/coding-agent/prompts/document.md` | the `/document` stub (infodump) |
| `devlog/handovers/20260928-11-workflow-m3_2_1_task_reorg_and_scaffolding.md` | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The stale-artifact row is dropped and replaced, not marked done | its remaining need (manual administrative close checklist) is still open and is the maintenance-runbook work; recording it done would erase an open need | roadmap root row + this handover |
| The AC-machinery task decomposes into a standalone `/document` task only | plan is done; a chore's AC is trivial; docs is the real, large, standalone problem | roadmap root row |
| `/wrapup` is reintroduced as the one-owner close-mechanics runbook | the task-spec difference ends at gate 3; close steps are identical across workflows; a duplicated close runbook would be a rule with many owners | this handover |
| The maintenance runbook owns the manual administrative close checklist | it is the exhaustive staleness sweep (handover chain, roadmap, AGENT_FEEDBACK, ADRs, discussion docs, compaction) | this handover |

## Findings

| Finding | Type | Impact | Triage |
|---|---|---|---|
| A `/plan` session used for task reorganization still requested a Gate 1 release. The gate system is `/iter`-centric (Gate 1/2/3); a non-iter workflow re-using it shows the ordinal gate model cannot carry workflows with different gating. | operator steering | validates the gate reorg: collapse Gate 1+2 for `/iter`, give the final gate a semantic name (`release gate`), and let other workflows use their own gating | Triaged to: `/iter` improvement task row (recorded in roadmap this iteration) |

## Completed

| File | Change |
|---|---|
| `devlog/roadmap.md` | M3.2.1 reorganized to the approved layout: U1-U5 parent compacted to one outcome summary; stale-artifact row dropped-and-replaced by the maintenance-runbook row (corrected); AC-machinery row replaced by the standalone `/document` task; Docs/ADR, `/wrapup`, maintenance runbook, and per-workflow improvement rows added |
| `workflow/coding-agent/prompts/document.md` | the `/document` stub carrying the docs-session infodump (read/lint AC deltas, advisor, documentation standards, grill-me, workflow-doc identification) |
| `devlog/handovers/20260928-11-workflow-m3_2_1_task_reorg_and_scaffolding.md` | this handover |

## Deferred items

None. The new task rows (per-prompt passes, `/wrapup`, maintenance runbook) are recorded in the roadmap, not executed this iteration -- they are the successor work.

## What's Next

M3.2.1 continues with the newly-scoped rows: `/document` formalization, `/iter` gate collapse + release-gate rename, `/wrapup`, the maintenance runbook, and the per-workflow quality passes.
