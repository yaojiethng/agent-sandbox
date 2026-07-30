# Agent Handover

**Session date:** 2026-07-30
**Milestone:** M2.6 — Session Resume and Mount Model Redesign
**Session type:** Implementation — Volume teardown fix and compose lifecycle modularization
**Status:** Closed

## Objective

Fix the post-agent `-v` teardown bug. Ensure `--rebuild` is a proper superset of `--refresh` for lifecycle behavior. Modularize `compose_teardown` into `compose_stop` / `compose_destroy`. Rename `--refresh` flag in `run_agent.sh` to `--reset-volume`.

## Scope

Three units across `scripts/run_agent.sh`, `scripts/start_agent.sh`, and `src/build/compose.sh`:

**Unit 1 — Post-agent teardown fix:** Remove `-v` from both post-agent teardown blocks in `run_agent.sh`. Post-agent always uses `docker compose down` without `-v`.

**Unit 2 — `--rebuild` forwards `--reset-volume`:** In `start_agent.sh`, the flag forwarding check becomes `[[ "${REFRESH:-false}" == "true" || "${REBUILD:-false}" == "true" ]]` so both flags independently trigger `--reset-volume`.

**Unit 3 — Modularize compose lifecycle + rename flag:** In `compose.sh`, split `compose_teardown` into `compose_stop` (`down`, no `-v`) and `compose_destroy` (`down -v`). In `run_agent.sh`, replace all teardown calls with the appropriate primitive. Rename the `--refresh` flag in `run_agent.sh` to `--reset-volume` and the internal variable from `REFRESH_MODE` to `RESET_VOLUME`.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | Post-agent teardown never uses `-v` | `grep 'down -v' scripts/run_agent.sh` returns zero matches | Accepted |
| 2 | Pre-start uses `compose_destroy` when `--reset-volume` is set | Read `run_agent.sh` | Accepted |
| 3 | `--rebuild` forwards `--reset-volume` to `run_agent.sh` | Read `start_agent.sh` | Accepted |
| 4 | `compose_stop` and `compose_destroy` exist, `compose_teardown` is removed | Read `compose.sh` | Accepted |
| 5 | `run_agent.sh` accepts `--reset-volume`, not `--refresh` | `grep -- '--refresh' scripts/run_agent.sh` returns zero | Accepted |
| 6 | `bash -n` passes on all changed files | Run `bash -n` | Accepted |
| 7 | End-to-end: `make start REFRESH=1` → session completes → subsequent `make start` resumes with git history intact | Operator | Accepted |
| 8 | End-to-end: `make start REBUILD=1` → same lifecycle behavior as `REFRESH=1` plus `--no-cache` builds | Operator | Accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/run_agent.sh`](scripts/run_agent.sh) | Post-agent teardown, `--reset-volume` rename, `compose_stop`/`compose_destroy` call sites |
| [`scripts/start_agent.sh`](scripts/start_agent.sh) | `--rebuild` must forward `--reset-volume` flag |
| [`src/build/compose.sh`](src/build/compose.sh) | `compose_teardown` → `compose_stop` / `compose_destroy` split |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Post-agent teardown never uses `-v` | Volume must survive session exit; refresh/rebuild reset the baseline, not session output | Chat |
| `--rebuild` must forward `--reset-volume` to `run_agent.sh` | Both flags independently trigger volume reset; differ only in image build behavior | Chat |
| `compose_teardown` split into `compose_stop` / `compose_destroy` | Separate concerns — stop is routine, destroy is explicit | Chat |
| `--refresh` flag in `run_agent.sh` renamed to `--reset-volume` | More accurate: it controls volume destruction, not image rebuilds | Chat |

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| Post-agent teardown passes `-v` when `REFRESH_MODE=true` | bug | Unit 1 |
| `--rebuild` does not forward `--reset-volume` to `run_agent.sh` | bug | Unit 2 |
| `compose_teardown($REFRESH_MODE)` conflates stop vs destroy operations | design | Unit 3 |

## Completed this session

| File | Change summary |
|---|---|
| [`scripts/run_agent.sh`](scripts/run_agent.sh) | Renamed `--refresh`/`REFRESH_MODE` to `--reset-volume`/`RESET_VOLUME`; replaced post-agent `-v` teardown with `compose_stop`; pre-start uses `compose_destroy` when `RESET_VOLUME=true` |
| [`scripts/start_agent.sh`](scripts/start_agent.sh) | `--rebuild` now forwards `--reset-volume` alongside `--refresh` |
| [`src/build/compose.sh`](src/build/compose.sh) | Split `compose_teardown` into `compose_stop` (`down`) and `compose_destroy` (`down -v`); `compose_dry_run` uses function dispatch instead of `$_down_vol` variable |

## Deferred items

| Item | Reason | Destination |
|---|---|---|
| End-to-end test harness with stubbed docker/compose covering all `agent-sandbox` subcommands | Separate session — verifies this session's output | Next session |

## Next session

**Session type:** Implementation — Docker command-trace test harness

Stub `docker` and `docker compose` to record commands. Write end-to-end tests invoking `agent-sandbox` subcommands and assert recorded commands match expectations. Verifies Units 1-3 from this session.

**Conclusions from this session:** Three fixes in `run_agent.sh`, `start_agent.sh`, and `compose.sh`: post-agent `-v` removed, `--rebuild` → `--reset-volume` forwarding, and `compose_stop`/`compose_destroy` replacing `compose_teardown`. `run_agent.sh` flag renamed to `--reset-volume`.
