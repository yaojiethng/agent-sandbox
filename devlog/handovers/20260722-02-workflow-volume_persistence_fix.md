# Agent Handover

**Date:** 2026-07-22
**Milestone:** M2.6 — Session Resume and Mount Model Redesign
**Type:** Workflow — Volume persistence bugfix and REFRESH env var leak fix
**Status:** Closed

## Objective

Fix two related bugs that cause the named `sandbox-data` volume to be removed when it should persist across `make stop` / `make start` cycles.

## Bug 1 — `stop.sh` removes volumes

`stop.sh` contains stale volume-deletion logic that predates M2.6.2's named-volume persistence model. The `sandbox-data` named volume was introduced in M2.6.2 specifically to survive stop/start, but `stop.sh` removes all volumes matching project labels — including `sandbox-data` when label conditions are met.

The compose template comment explicitly states the intent:
> preserved across `make stop` / `make start`, destroyed only on `make start REFRESH=1` or `docker compose down -v`

`stop.sh` should stop containers only. Volume cleanup is delegated to `prune.sh`, `make start REFRESH=1`, or explicit `docker compose down -v`.

## Bug 2 — REFRESH env var leak through `exec`

`start_agent.sh` does `export REFRESH=true` when `--refresh` is passed, then `exec`s `run_agent.sh`. The exported variable leaks into the child process. When the agent exits and `run_agent.sh` runs teardown, it reads `${REFRESH:-false}` from the environment and runs `docker compose down -v` — removing the named volume even though the user didn't ask to refresh on exit. Any subsequent `make start` (without `REFRESH=1`) starts with a fresh volume, losing session state.

The fix: pass `--refresh` as a CLI flag to `run_agent.sh` instead of leaking through the environment. Both `compose_teardown()` and the inline teardown blocks use a local variable, not the env.

## Scope

- `scripts/stop.sh` — Remove volume-deletion block
- `src/build/compose.sh` — Refactor `compose_teardown()` and `compose_dry_run()` to accept a flag parameter instead of reading `REFRESH` from env
- `scripts/run_agent.sh` — Accept `--refresh` flag, store in local `REFRESH_MODE`, pass to compose functions and inline teardown
- `scripts/start_agent.sh` — Stop exporting `REFRESH=true`; pass `--refresh` flag to `run_agent.sh` `exec`
- `src/reasoning/agent/drafts/bash-scripting-traps.skill.md` — Add trap: don't set state via exported vars when a parameter works
- Propagation: update docs/tests that reference these behaviors

## Acceptance criteria

| # | Criterion | Verifiable by |
|---|---|---|
| 1 | `stop.sh` no longer calls `docker volume rm` | `grep -c 'docker volume rm' scripts/stop.sh` = 0 |
| 2 | `compose_teardown` accepts `$1` flag instead of reading `REFRESH` from env | `grep -c 'REFRESH' src/build/compose.sh` = 0 |
| 3 | `compose_dry_run` accepts `$4` flag instead of reading `REFRESH` from env | `grep -c 'REFRESH' src/build/compose.sh` = 0 |
| 4 | `run_agent.sh` stores `--refresh` in a local variable, not env | `grep -c 'export.*REFRESH' scripts/run_agent.sh` = 0 |
| 5 | `start_agent.sh` no longer exports `REFRESH` | `grep -c 'export.*REFRESH' scripts/start_agent.sh` = 0 |
| 6 | All existing tests pass | `bash scripts/run_tests.sh` — 0 failures |
| 7 | bash-scripting-traps skill has the new trap | grep -c passes |

## Mid-session findings

**Schedule an investigation into `prune.sh` next session** — to properly scope out the volume removal rules and ensure the prune/refresh/stop boundary is clean. The three-tier model (stop=containers only, stop PRUNE=old volumes only, start REFRESH=all) needs clear ownership.

## Hot files

| File | Change |
|---|---|
| `scripts/stop.sh` | Remove volume-deletion block; update header/usage comments |
| `src/build/compose.sh` | `compose_teardown` and `compose_dry_run` take flag param instead of env |
| `scripts/run_agent.sh` | Add `--refresh` flag parsing; use `REFRESH_MODE` local var in teardown |
| `scripts/start_agent.sh` | Stop exporting REFRESH; pass `--refresh` flag to `run_agent.sh` exec |
| `src/reasoning/agent/drafts/bash-scripting-traps.skill.md` | New trap: don't set state via env vars |
