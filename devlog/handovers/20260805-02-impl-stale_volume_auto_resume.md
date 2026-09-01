# Agent Handover

**Date:** 2026-08-05
**Milestone:** M2.6.5 — Copy Model: Volume-backed Sandbox
**Type:** Implementation
**Status:** Closed

## Objective

Fix `_auto_resume_or_new` behavior: when a single stale volume exists, auto-resume it with a warning instead of showing the interactive picker.

## Scope

One logic change in `scripts/start_agent.sh` — `_auto_resume_or_new()`.

Exhaustive cases after fix:

| Volumes | Non-stale | Stale | Action |
|---|---|---|---|
| 0 | 0 | 0 | New session |
| 1 | 1 | 0 | Resume silently |
| 1 | 0 | 1 | Resume stale + warn |
| 2+ | any | any | Picker |

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Single stale volume auto-resumes with warning (no picker) | Accepted |
| 2 | All six cases exhaustively handled | Accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/start_agent.sh`](../../scripts/start_agent.sh) | `_auto_resume_or_new` function — case 2 logic change |

## Decisions made this session

None.

## Mid-session findings

None.

## Completed this session

| File | Change |
|---|---|
| `scripts/start_agent.sh` | `_auto_resume_or_new`: added {0 non-stale, 1 stale} → resume + warn branch; removed redundant stale warning from `_resume_from_volume`; updated function header comment |

## Deferred items

None.

## Next session

Sub-milestone: M2.6.6 — Mount Model: Host-backed Sandbox

Post-close bookkeeping: not applicable.
