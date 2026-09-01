# Agent Handover

**Date:** 2026-08-01
**Milestone:** M2.6.5 — Copy Model: Volume-backed Sandbox (reopened)
**Type:** Design — `make start` command shape and session lifecycle UX

## Status at entry

M2.6.5 was closed after the onboard.sh consolidation commit. This session reopens it for UX design: the `make start` invocation shape and default session behavior.

The operator reports the current design is unintuitive — unclear when to use `--resume`, what the default should be, and whether a "new session" implies `--refresh`.

## Mid-session findings

### Current state

Three flags (`REFRESH`, `RESUME`, `REBUILD`) conflate two independent axes:
1. **Volume lifecycle** — new volume vs. resume existing
2. **Image staleness** — use cached images vs. rebuild

Default is "new session" (destroy volume, build snapshot). RESUME=1 is opt-in.
REFRESH forces new-session AND rebuild.

### Operator feedback

- Default of "new session" is unintuitive given session persistence is the whole point
- `--refresh` should only control images, not force new session
- "fresh volume" means: baseline has changed (merge, version bump) — future sessions should reflect it. Not an image concern.
- `make stop` should have no bearing on `make start` behavior
- Not sure about interactive prompts. Cost of undoing a misplaced command is low.

### Design

**Two truly independent axes:**

| Axis | Default | Explicit override |
|---|---|---|
| Volume | Resume if non-stale volume exists, else new | TBD — need a flag for "force new volume" |
| Image | Use cached | `REFRESH=1` (rebuild sandbox+provider), `REBUILD=1` (rebuild everything including base) |

**New default:** resume when a non-stale volume exists. When stale → interactive picker (choose which volume, including option to start fresh). When no volumes → new session.

**The "force new volume" case:** user wants a clean slate because project baseline changed (merge, version bump). This should be explicit. Need a flag name that communicates "new volume, fresh snapshot." Candidate: `RESET=1`?

**REFRESH semantics:**
- Before: REFRESH = new session + rebuild images
- After: REFRESH = rebuild images only. Volume decision follows the same default logic.
- REBUILD = superset of REFRESH (--no-cache).

**Pending questions:**
1. Flag name for "force new volume" — operator rejected `FRESH`/`NEW`. Other candidates: `RESET`, `CLEAN`, `--new-session`?
2. When code changed (new commits pulled), should a resume-on-stale present the picker or warn+auto-resume?
3. The operator noted this pressure toward Mount Model is a sign of the copy model being awkward for rapid iteration. Accepted — M2.6.6 is still the plan.

## Completed this session

| # | Task | Status |
|---|---|---|
| 1 | Investigate current `make start` / `start_agent.sh` code paths | done |
| 2 | Design proposal for revised command shape | done |
| 3 | Implement auto-resume default, refactor picker, update docs | done |

## Decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | Default `make start` auto-resumes non-stale volume | Session persistence is the norm; new-session is the exception |
| 2 | `REFRESH`/`REBUILD` keep "new session" semantics | Operator cannot envision wanting rebuild without fresh volume |
| 3 | Stale volume: warn + auto-resume with picker hint | Cost of undoing is low; hint tells operator how to switch |
| 4 | Multiple non-stale volumes → picker | Operator must disambiguate; can't guess intent |
| 5 | `RESUME=1` repurposed to "always show picker" | Originally it was "enable resume"; now resume is default, so it becomes the explicit disambiguation path |

## Deferred items

| # | Item | Reason |
|---|---|---|
| - | (none yet) | - |
