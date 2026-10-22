---
date: 2026-10-03
milestone: M3 - Manual Dispatch, Autonomous Execution, Manual Review
type: Plan
status: Closed
---

# Handover - Plan: consolidate the pi-bump rows into T12

## Objective

Move every roadmap row whose subject is the pinned `@earendil-works/pi-coding-agent` version, the compatibility surface of the shipped extensions, or a report filed upstream against pi, into one track, `T12 - Pi Dependency and Extension Upkeep`, so the dependency's open work reads as one set. Retarget the bump rows to the next version, 1.0.0.

## Scope

| In | Out |
|---|---|
| The T12 track and its rows | Any bump or extension work; the rows move, nothing executes |
| The T intro update | The `task-queue` quality rows, which stay with M3.2.3 |
| The `#### Not in scope: M3.2.3` position fix | `Decide the two settings questions the harness boundary raised`, which stays |

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | `#### T12 - Pi Dependency and Extension Upkeep` exists under the T section, after T11 | `devlog/roadmap.md` | Accepted |
| 2 | The track holds the 15 named rows | grep each row title, one hit | Accepted |
| 3 | No moved row remains in its old section | same grep set, no hit outside T12 | Accepted |
| 4 | The T intro names T12 and the series range reads `T4 to T12` | `devlog/roadmap.md` | Accepted |
| 5 | `#### Not in scope: M3.2.3` sits after the task list | `devlog/roadmap.md` | Accepted |
| 6 | Gates clean | `bash scripts/lint.sh` | Accepted |

## Hot files

`devlog/roadmap.md`.

## Decisions

1. **T12 owns five subjects: the pin, the bump procedure, the extension compatibility surface, the `model-refresh` extension, and the upstream reports.** The two T1 rows and the T7 capacity row join at the operator's direction, because each names the pi-bump procedure or depends on the bump.
2. **The `task-queue` rows stay with M3.2.3.** The track owns the compatibility surface of both extensions, but the task-queue quality work is dispatch work, not pi dependency upkeep.
3. **The `#### Not in scope: M3.2.3` block moves after the task list.** It sat before the acceptance criteria and the task list, so those rendered under the Not-in-scope heading. The fix is in the same region.
4. **The bump rows target 1.0.0.** The 1.0.0 changelog carries no fix for the default-model report, so that row now names both versions.
5. **T12 is a track, not a milestone.** The tracks are rough groupings, so the handover's milestone is M3.

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The pi-bump rows were scattered across the M3.2.3 block, T1 and T7, so no single read showed the dependency's open work | record | fixed by T12 |
| `#### Not in scope: M3.2.3` preceded the acceptance criteria and task list, so they rendered under the Not-in-scope heading | record | fixed in this commit |

## Completed

`#### T12 - Pi Dependency and Extension Upkeep` added under the T section; 15 rows moved from the M3.2.3 block, T1 and T7; the T intro updated; `#### Not in scope: M3.2.3` moved after the task list; two provenance notes corrected; the bump rows retargeted to 1.0.0.
