# Agent Handover

**Session date:** 2026-07-30
**Milestone:** M2.6.2 — Volume and Container Persistence
**Session type:** Implementation — Container persistence and pre-start cleanup refactoring
**Status:** Closed

## Objective

Implement container persistence: `compose_stop` uses `docker compose stop` instead of `down`, `stop.sh` drops `docker rm`. Refactor pre-start cleanup: remove `stop.sh` call from `start_agent.sh`, letting `run_agent.sh`'s `compose_stop` be the single pre-start mechanism.

## Scope

Two units:

**Unit 1 — Container persistence:**
- `src/build/compose.sh`: `compose_stop` → `docker compose stop` (preserves stopped containers)
- `scripts/stop.sh`: remove `docker rm` call (containers persist after stop)

**Unit 2 — Pre-start cleanup refactoring:**
- `scripts/start_agent.sh`: remove the `stop.sh` call in the pre-start guard block. The `compose_stop` in `run_agent.sh` handles pre-start cleanup.
- Trace tests updated for new command shapes (`stop` instead of `down` for compose_stop, no `rm` for stop.sh)

## Carried forward

| Item | From handover |
|---|---|
| Container persistence implementation | 20260730-03-impl-compose_name_leak_fix (design doc) |
| Pre-start cleanup deduplication | Chat — double-stop identified as refactoring opportunity |

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | `compose_stop` invokes `docker compose stop`, not `down` | `grep 'compose_stop' src/build/compose.sh` shows `docker compose ... stop` | Agent ✅ |
| 2 | `stop.sh` no longer calls `docker rm` | `grep 'docker rm' scripts/stop.sh` returns zero | Agent ✅ |
| 3 | `start_agent.sh` no longer calls `stop.sh` in pre-start guard | `grep 'stop.sh' scripts/start_agent.sh` returns zero | Agent ✅ |
| 4 | `bash -n` passes on all changed files | `bash -n scripts/run_agent.sh scripts/start_agent.sh scripts/stop.sh src/build/compose.sh` | Agent ✅ |
| 5 | All trace tests updated and pass (24 tests) | `bash tests/test_trace_*.sh` all exit 0 | Agent ✅ |

## Hot files

| File | Why in scope |
|---|---|
| [`src/build/compose.sh`](src/build/compose.sh) | `compose_stop`: `down` → `stop` |
| [`scripts/stop.sh`](scripts/stop.sh) | Remove `docker rm` |
| [`scripts/start_agent.sh`](scripts/start_agent.sh) | Remove pre-start `stop.sh` call |
| [`tests/test_trace_start.sh`](tests/test_trace_start.sh) | Update assertions for `stop` vs `down` |
| [`tests/test_trace_stop.sh`](tests/test_trace_stop.sh) | Remove `rm` assertion, verify `stop` only |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| `stop.sh` and `compose_stop` remain separate — label-based vs compose-based | Different scopes: all sessions vs one project. Combining adds complexity for no gain. | Chat |
| Pre-start `stop.sh` call removed from `start_agent.sh` | `compose_stop` in `run_agent.sh` handles pre-start cleanup. Eliminates double-stop. | Chat |

## Mid-session findings

None.

## Completed this session

| File | Change summary |
|---|---|
| [`src/build/compose.sh`](src/build/compose.sh) | `compose_stop`: `docker compose down` → `docker compose stop` |
| [`scripts/stop.sh`](scripts/stop.sh) | Removed `docker rm` call — containers persist after stop |
| [`scripts/start_agent.sh`](scripts/start_agent.sh) | Removed pre-start `stop.sh` call — `run_agent.sh`'s `compose_stop` handles cleanup |
| [`test/stubs/docker`](test/stubs/docker) | Added `stop` to compose subcommand list |
| [`tests/test_trace_start.sh`](tests/test_trace_start.sh) | Updated assertions: `compose down` → `compose stop` for compose_stop |
| [`tests/test_trace_stop.sh`](tests/test_trace_stop.sh) | Updated assertion: `docker rm` no longer expected |

## Deferred items

None.

## Next session

Continue M2.6.2 — multi-volume concurrency implementation.

**Conclusions from this session:** To be populated.
