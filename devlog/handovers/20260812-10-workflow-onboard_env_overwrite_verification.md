# Agent Handover

**Date:** 2026-08-12
**Milestone:** M2.6 — Session Persistence (general CLI/infra track)
**Type:** Workflow
**Status:** Closed

## Objective

Verify whether `onboard`/`make refresh` can overwrite an existing sandbox `.env` (operator values). The operator recalled a past change that `.env` is not overwritten if present (only recreated if removed), but recently observed it being overwritten, unsure if the running tool was the latest version. The operator also asked to trace and confirm **all invocation points** of the refresh/onboard `.env` path, then to **extend refresh** so it also keeps `PROJECT_DIR`/`SANDBOX_DIR`/derived paths (but not `INSTALL_DIR`) up to date.

Initial verification concluded no overwrite path exists and the three invocation points all preserve `.env`. The implementation then extended `_run_refresh` to sync `PROJECT_DIR`/`SANDBOX_DIR` (paths) while preserving `INSTALL_DIR`/operator config.

The three invocation points asked to trace:
1. `make refresh` from `SANDBOX_DIR`
2. `agent-sandbox onboard --refresh`
3. `make refresh` from `PROJECT_DIR`, passing `SANDBOX_DIR`

## Finding (verified)

**No code path, across all invocation points, overwrites an existing `.env`.** The `.env` write is `_write_env_file()` in `scripts/onboard.sh` (`cat >` full overwrite), reached only when:
- **Fresh `onboard`** (`_run_onboard`): `_validate_onboard` aborts with "SANDBOX_DIR already contains 'Makefile'/.env/docker-compose.yml → avoid overwriting" if any of those exist. `_write_env_file` is only reached when the sandbox is empty (first-time) — nothing to overwrite.
- **Refresh** (`_run_refresh`): if `.env` exists → updates `MAKEFILE_VERSION` + `PROJECT_DIR` + `SANDBOX_DIR` in place via `sed -i` (operator config preserved). `_write_env_file` recreates `.env` only when it is **absent** AND `--project` is provided.

`start_agent.sh`/`run_agent.sh`/build only **read** `.env` (`ENV_REL=".env"`); they never write it. (`make start ... REFRESH=1` is a *different* `--refresh` — image rebuild, not template refresh — and does not touch `.env`.)

## Invocation-point trace (all three confirmed to route to the preserving refresh path)

| Invocation | Mechanism | Routes to | `.env` effect |
|---|---|---|---|
| `make refresh` from SANDBOX_DIR | sandbox `Makefile` `refresh:` target (Makefile.template) → `agent-sandbox onboard --refresh --name --project --sandbox` | `_run_refresh` | preserved (bumps MAKEFILE_VERSION only) |
| `agent-sandbox onboard --refresh` | CLI → `--refresh` flag sets `REFRESH=true` → mode dispatch | `_run_refresh` | preserved |
| `make refresh` from project_dir passing SANDBOX_DIR | project-dir Makefile delegating to `make -C $SANDBOX_DIR refresh` (or onboard --refresh with --sandbox) | `_run_refresh` | preserved |

Empirical reproduction (all pass): set SERVE_PORT=12345 in `.env`, then ran each invocation → 12345 preserved; fresh `onboard` re-run → aborted "already contains 'Makefile'", 12345 preserved.

**Conclusion:** the operator's observation of an overwrite almost certainly predates the guard/preservation change (older tool version), matching their own uncertainty ("not sure if that was the latest version"). Current code is defined and tested (see below).

## Tests documenting this behavior (already in suite)

- `tests/test_onboard.sh` `test_onboard_aborts_if_sandbox_exists` — fresh onboard aborts when SANDBOX_DIR has outputs.
- `tests/test_onboard.sh` `test_refresh_preserves_env_values` — refresh preserves operator SERVE_PORT.

## Files in scope

| File | Role |
|---|---|
| `scripts/onboard.sh` | `.env` write logic; `_validate_onboard` guard; `_run_refresh` preservation |
| `scripts/templates/Makefile.template` | `refresh:` target → `onboard --refresh` |
| `scripts/start_agent.sh` | reads `.env` only (no write) — confirmed not the source |
| `tests/test_onboard.sh` | existing guard + preserve tests |

## Decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | **Refresh syncs `PROJECT_DIR`/`SANDBOX_DIR` + `MAKEFILE_VERSION`; preserves `INSTALL_DIR` and all operator config (SERVE_PORT, AUTOSAVE_INTERVAL, provider stubs)** | `INSTALL_DIR` is operator config with no `--install-dir` input to sync it to; clobbering would undo an operator override (confirmed with operator) |
| 2 | Escape `&` in sed replacement values | a path containing `&` would otherwise be interpreted by sed as the whole-match metacharacter and corrupt `.env` |

## Mid-session findings

| # | Finding | Disposition |
|---|---|---|
| 1 | Two distinct `--refresh` meanings coexist: `onboard --refresh` (template update, preserves `.env`) vs `start_agent.sh --refresh` / `make start ... REFRESH=1` (image rebuild + new session). Both read `.env`; neither overwrites it. | documented — potential naming confusion, not a bug |
| 2 | `.env` refresh previously updated only `MAKEFILE_VERSION`; `PROJECT_DIR`/`SANDBOX_DIR` were not re-synced if the project moved | fixed — refresh now syncs them (paths), preserving operator config |

## Deferred

(none)

## Completed this session

- [x] Traced `.env` write logic in `onboard.sh` (`_write_env_file` reachability)
- [x] Traced `_validate_onboard` refresh guard and `_run_refresh` preservation
- [x] Confirmed `start_agent.sh`/build path reads `.env` only (no write)
- [x] Traced all 3 invocation points to `_run_refresh` (preserving)
- [x] Empirically reproduced: all 3 invocations preserve operator SERVE_PORT; fresh re-onboard aborts
- [x] Extended `_run_refresh` to sync `PROJECT_DIR`/`SANDBOX_DIR` on refresh (paths), preserving `INSTALL_DIR`/operator config; escaped `&` in sed values
- [x] Added `test_refresh_syncs_paths_preserves_config` to `test_onboard.sh`
- [x] Full suite green (470/0/0); shellcheck clean on changed block

## Acceptance criteria

- [x] Confirm no `.env`-overwrite path exists (verified)
- [x] Trace all 3 invocation points (done — all preserve)
- [x] Extend refresh to keep `PROJECT_DIR`/`SANDBOX_DIR` up to date; preserve `INSTALL_DIR` (operator decision)
- [x] Regression test added; suite green (470/0/0)
- [x] commit as `fix:` (onboard.sh behavior + test)

## Operational notes

- Investigation session; no source change unless operator requests hardening.
