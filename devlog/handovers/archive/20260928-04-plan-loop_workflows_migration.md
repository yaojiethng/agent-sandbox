# Agent Handover

**Date:** 2026-09-28
**Milestone:** M3 - Autonomous Task Execution, Manual Review Workflow
**Type:** Plan
**Status:** Closed

## Objective

Scope M3.2.1 (Loops as Workflows) into a concrete migration plan and land its planning records. This iteration produces the design record, the reorganised M3.2.1 roadmap rows, and the migration unit table. It does not implement the migration; execution is U1 and U2 in the iterations that follow.

## Scope

Planning owns the records a migration needs before implementation starts. The deliverable is the plan, not the migration.

- The design record capturing decisions 1-18 from the 2026-09-28 design walk.
- The M3.2.1 roadmap re-organisation: consolidate the stale rows, fold the T1 stale-artifact row into M3.2.1, and add the per-prompt quality tasks.
- The migration unit table (U1 skeleton, U2 minor-loop migration, and the review-heavy per-unit policy migration after).

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | The design record exists and captures the loop taxonomy, the separation rule, the ADR scope, the concept-doc plan, and the migration units | read `devlog/discussions/archive/20260928-design-settled-loop_workflows_migration.md` | Agent [x] accepted: all five parts present, migration unit table added |
| AC2 | The M3.2.1 roadmap section shows the consolidated rows and the per-prompt quality tasks | read `devlog/roadmap.md` | Agent [x] accepted: ADR row, four migration units, fold row, four quality passes |
| AC3 | The migration unit table names each unit, its commit type, its owned files, and its handover | read this handover | Agent [x] accepted: unit table in the design record, roadmap rows mirror U1-U4 |
| AC4 | The T1 stale-artifact row is folded into M3.2.1 | read `devlog/roadmap.md` | Agent [x] accepted: row 108 closed with fold note, M3.2.1 gains the fold row |
| AC5 | Lint clean, one commit carrying the handover | `lint.sh`, `git log` | Agent [ ] in pre-state: lint clean, commit pending close |

## Hot files

| File | Why in scope |
|---|---|
| `devlog/discussions/archive/20260928-design-settled-loop_workflows_migration.md` | the design record this iteration lands |
| `devlog/roadmap.md` | M3.2.1 rows reorganised, T1 stale-artifact row folded |
| `devlog/handovers/archive/20260928-04-plan-loop_workflows_migration.md` | this handover, rides the commit |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The plan and the migration are separate iterations | planning owns the records; implementation conforms to them | this handover |

## Findings

| Finding | Type | Impact | Triage |
|---|---|---|---|
| None. | | | |

## Completed

| File | Change |
|---|---|
| `devlog/discussions/archive/20260928-design-settled-loop_workflows_migration.md` | created: the design record capturing decisions 1-18, the loop taxonomy, the separation rule, the ADR scope, the concept-doc plan, and the migration-unit table |
| `devlog/roadmap.md` | M3.2.1 reorganised: ADR row expanded, four migration units (U1-U4), fold row, four per-prompt quality passes; summary status to In progress; T1 stale-artifact row closed with fold note |
| `devlog/handovers/archive/20260928-04-plan-loop_workflows_migration.md` | this handover, carries the plan records |

## Deferred items

| Item | Why deferred | Where it goes |
|---|---|---|
| None. | | |

## What's Next

M3.2.1 migration execution. U1 (skeleton: ADR-index shell, four loop stubs, concept shell, policy links) lands first as its own handover and commit, then U2 (minor-loop procedure into `/iter`). U3 and U4 follow; then the four per-prompt quality passes. The migration unit table is in the design record and mirrors the M3.2.1 roadmap rows.
