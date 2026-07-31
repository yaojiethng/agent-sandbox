# Agent Handover

**Session date:** 2026-07-30
**Milestone:** M2.6.5 — Copy Model: Volume-backed Sandbox
**Session type:** Implementation — Interactive volume selector
**Status:** Closed

## Corrections

### 2026-07-30 (post-close) — 73f6474

Two bugs caught on live test after session close:

1. **Empty session-ts/run-id labels in selector.** Volume labels `session-ts` and `run-id` were only on the `x-session-labels` YAML anchor (applied to containers), not on the volume definition itself. Added to `docker-compose.yml` volume `labels:`. `discover_volumes()` now also filters by `agent-sandbox.session-ts` to exclude pre-multi-volume volumes that lack identity labels.

2. **REFRESH destroyed all volumes.** The REFRESH block called `docker volume rm` on every volume discovered for the sandbox directory. This was leftover from the single-volume mental model where "refresh" meant "reset the one volume." With multi-volume, REFRESH starts a new session alongside existing volumes — `prune --volumes` is the only destroy path. Removed the `docker volume rm` loop.

3. **Selector format tightened.** `branch: feat-x  host SHA: a34b95a` → `branch: feat-x (a34b95a)`.

## Objective

Wire up an interactive numbered picker when multiple volumes exist for a sandbox directory, matching the design from `20260730-design-settled-copy_model.md`. Replaces the current error-and-exit with a prompt.

## Design

```
Multiple sessions found for this sandbox directory:

  1) 20260730-130000  RUN_ID: a1b2c3  branch: feat-m2.6 (2d69a4d)
  2) 20260730-090000  RUN_ID: d4e5f6  branch: master (dfed41d) [STALE]
  3) [start new session]

Select (1-3):
```

Inline in `start_agent.sh` — no dependency on `workflows/interactive.sh`. Simple `read`-based picker, no external libraries needed.

## Scope

`scripts/start_agent.sh` — replace the multi-volume error block with interactive picker.
`src/build/docker-compose.yml` — add `session-ts` and `run-id` labels to volume definition (correction).

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | 2+ volumes displays numbered list | Accepted |
| 2 | Selecting a number resumes that volume | Accepted |
| 3 | Last option is always `[start new session]` | Accepted |
| 4 | Invalid input re-prompts | Accepted |
| 5 | Stale volumes flagged `[STALE]` | Accepted |
| 6 | `[start new session]` computes fresh identity | Accepted |
| 7 | Volume labels include session-ts and run-id | Accepted — correction 73f6474 |
| 8 | REFRESH does not destroy existing volumes | Accepted — correction 73f6474 |
