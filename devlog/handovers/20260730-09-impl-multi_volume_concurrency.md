# Agent Handover

**Session date:** 2026-07-30
**Milestone:** M2.6.5 — Copy Model: Volume-backed Sandbox
**Session type:** Implementation — Multi-volume concurrency
**Status:** Closed

## Objective

Implement volume-per-session concurrency: each session gets its own named volume (`<project>-<run-id>_sandbox-data`), compose project names incorporate RUN_ID, start_agent.sh discovers and selects volumes by label, and volume locking prevents concurrent attachment.

## Scope

Four files:

| File | Change |
|---|---|
| `src/build/docker-compose.yml` | Volume name: `sandbox-data` → `{{RUN_ID}}-sandbox-data`; add `session-ts` label |
| `src/build/compose.sh` | `compose_args`: project name by RUN_ID not sandbox dir hash; `compose_generate`: add RUN_ID substitution |
| `scripts/start_agent.sh` | Volume discovery by label, resume from volume labels, new session creation, volume locking |
| `scripts/run_agent.sh` | Pass RUN_ID volume name through; RESET_VOLUME destroys correct volume |

## Design reference

[`devlog/discussions/20260730-design-settled-copy_model.md`](devlog/discussions/20260730-design-settled-copy_model.md)

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Volume name includes RUN_ID | Accepted — `{{RUN_ID}}-sandbox-data` |
| 2 | Compose project name includes RUN_ID | Accepted — `agent-sandbox-<PROJECT>-<RUN_ID>` |
| 3 | Volume discovery queries by sandbox-dir label | Accepted — `discover_volumes()` |
| 4 | New session creates volume with correct labels | Accepted — `agent-sandbox.session-ts`, `agent-sandbox.run-id` |
| 5 | Resume reads identity from volume labels | Accepted — `volume_label()` |
| 6 | .run-identity retains backward compatibility | Accepted — written on both new and resume |
| 7 | Volume locking prevents concurrent attachment | Accepted — `volume_in_use()` check |
| 8 | `make start REFRESH=1` destroys and recreates | Accepted — `docker volume rm` before new identity |
| 9 | Trace tests pass (25/25) | Accepted |
| 10 | Staleness warning on mismatched host-head-sha | Accepted — `volume_is_stale()` |
| 11 | Multiple volumes lists sessions with RUN_ID | Accepted — error with listing, interactive picker deferred |

## Completed this session

| File | Change summary |
|---|---|
| `src/build/docker-compose.yml` | Volume: `sandbox-data` → `{{RUN_ID}}-sandbox-data`. Added `agent-sandbox.session-ts` label |
| `src/build/compose.sh` | `compose_args`: project name = `agent-sandbox-<PROJECT>-<RUN_ID>`. `compose_generate`: added `{{RUN_ID}}` substitution |
| `scripts/start_agent.sh` | Volume discovery, label-based resume, new session volume creation, locking |
| `scripts/run_agent.sh` | compose_destroy: `docker volume rm` for targeted volume on `--reset-volume` |
| `tests/test_trace_*.sh` | Updated for new volume naming + compose project naming |

## Deferred items

- **Interactive volume selector** — 2+ volumes currently lists sessions and exits. Next session will wire up a numbered picker (like `make draft`'s interactive mode) with `[start new session]` option.
