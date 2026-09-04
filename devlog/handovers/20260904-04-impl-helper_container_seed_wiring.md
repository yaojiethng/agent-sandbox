# Handover 20260904-04 — impl helper container seed wiring (old path intact)

**Milestone:** M2.6 - Session Persistence
**Type:** impl
**Status:** Closed
**Date:** 2026-09-04

## Objective

Wire the helper-container seed transport (ADR `sandbox_delivery_model.md` 2026-09-04 entry, amended by handover 20260904-03) as the active mechanism, with the legacy `docker cp` pipeline kept intact but unused. Operator plan: (1) wire new mechanism; (2) operator resets to a fresh baseline with REFRESH=1 and verifies the `.agent-sandbox-seed/` folder no longer appears; (3) removal of the legacy path happens in a later iteration once the new one is error-free.

## Design (from the amended ADR, wiring decisions)

| # | Decision | Rationale |
|---|---|---|
| D1 | Transport switch: `SEED_TRANSPORT` env in `run_agent.sh`, values `helper` (default) and `legacy`. | Operator test (step 2) requires the new mechanism active by default; legacy stays reachable for comparison until removal. |
| D2 | Seeder script `src/capability/seed_volume.sh` runs in a one-shot `seeder` compose service from the sandbox image; the script itself is bind-mounted read-only from the harness repo (`{{REPO_ROOT}}` template var, new). | Baking the script into the image would make every seeder run depend on image freshness and on per-project Dockerfile template copies. A bind mount means the seeder always executes current source. |
| D3 | Seeder mounts: project read-only at `/src`, session volume at `/dest`, harness `src/libs` read-only (for `session_state.sh`), harness `src/capability` read-only (the script). User: `${HOST_UID}:${HOST_GID}` — same as the sandbox service. | UID parity (F3 of 20260904-03): no root extraction, volume files owned by the host uid. |
| D4 | Helper seed flow in `run_agent.sh`: preseed checks → `timeout`-wrapped `docker compose run --rm seeder` → exit code is the readiness signal; nonzero or timeout aborts the start and tears the session volume down (`compose down -v`). Sandbox container is created by the normal start flow afterward. | ADR completion-signal block. No container create before the seed; no in-volume sentinel; no half-seeded volume can boot. |
| D5 | Entrypoint needs no new branch: with the seeder having written `.git` + `SESSION_STATE`, the copy-delivery flow takes the existing already-initialized path, which writes the workspace-path keys. Legacy fresh-init branch stays for `SEED_TRANSPORT=legacy`. | Minimal surface; removal iteration deletes the legacy branch. |

## Scope

| # | Item | Status |
|---|---|---|
| 1 | `src/capability/seed_volume.sh`: guards (sentinel tripwire, linked-worktree gitfile, unborn HEAD, submodules — readable errors), `cp -a .git`, existence-filtered enumeration tar pipe (skipped when enumeration is empty), SESSION_STATE write, porcelain self-check | done |
| 2 | `src/build/docker-compose.copy.yml`: `seeder` service definition | done |
| 3 | `src/build/compose.sh`: `{{REPO_ROOT}}` substitution | done |
| 4 | `scripts/run_agent.sh`: `SEED_TRANSPORT` branch, helper seeder with timeout + teardown on failure | done |
| 5 | `tests/test_seed_volume.sh`: 19 seeder tests (guards, existence filter, porcelain parity, self-check divergence, SESSION_STATE, empty worktree) | done |
| 6 | Suite green including legacy path tests (legacy intact): 775/775, lint Clean | done |

## Changes

| File | Change |
|---|---|
| `src/capability/seed_volume.sh` | New: the seeder. Guards fail closed; `cp -a .git`; existence-filtered enumeration tar; SESSION_STATE (init_sha/session_ts/session_id/host_head_sha); porcelain self-check. `SEED_VOLUME_NO_MAIN` guard for sourcing |
| `src/build/docker-compose.copy.yml` | `seeder` service (one-shot): project ro at `/src`, session volume at `/dest`, harness lib/script ro bind mounts, `HOST_UID` user parity, `bash` entrypoint override. Header updated to describe both transports |
| `src/build/compose.sh` | `{{REPO_ROOT}}` template substitution |
| `scripts/run_agent.sh` | `SEED_TRANSPORT` switch (helper default / legacy); `seed_sandbox_volume_helper`: timeout-wrapped `compose run --rm seeder`, exit-code readiness, volume discard on failure or timeout |
| `tests/test_seed_volume.sh` | New: 19 tests over the seeder contract |

## Deferred (removal iteration, step 3)

- `run_agent.sh` legacy body, `snapshot_seed_tar`, `snapshot_init_git` fresh-init branch, `snapshot_archive_head`, entrypoint legacy branch, `.gitignore` sentinel line, architecture doc sweep (`sandbox_lifecycle.md` Phase 1, `execution_model.md`), test retirements per the design doc audit, the mount-path `snapshot_copy_worktree` enumeration fix.

## Findings

| # | Finding | Status |
|---|---|---|
| F1 | `compose_sandbox_wait` already implements a bounded wait (SANDBOX_WAIT_TIMEOUT, default 120s) with exited-state fail-fast — the readiness scope is confined to the seeder wait. | Resolved |
| F2 | The sandbox image is built from a per-project Dockerfile template copy; baking the seeder into the image would require template versioning per project. Avoided by D2. | Resolved |
| F3 | YAML anchors do not resolve across compose merge files: referencing the base file's `*session_labels` anchor from the copy overlay would fail at real runtime (no YAML parser exists in the test environment; the docker stub cannot catch it). Seeder carries no labels — it is a `--rm` one-shot, lifecycle tooling cannot observe it. | Resolved |
| F4 | On the helper path the entrypoint takes its existing already-initialized branch, whose message says "Resuming existing volume" even on a fresh start. Functionally correct (workspace keys written, identity matches); message refinement deferred to the removal iteration. | Open (cosmetic) |

## Decisions

| # | Decision | Rationale | Source |
|---|---|---|---|
| D1–D5 | See table above. | | This iteration |

## Acceptance criteria (pre-close)

| # | Criterion | Status |
|---|---|---|
| AC1 | `SEED_TRANSPORT=helper` (default) seeds via the seeder service; no `.agent-sandbox-seed/` is created anywhere | done (unit level; live verification = operator step 2, AC7) |
| AC2 | `SEED_TRANSPORT=legacy` preserves the existing docker cp flow, legacy tests green | done (775/775) |
| AC3 | Seeder guards fail closed with readable errors (submodules, unborn HEAD, linked worktree, tracked sentinel) | done (4 tests) |
| AC4 | Porcelain self-check aborts the seed on induced divergence | done (verify_parity unit test) |
| AC5 | SESSION_STATE written by the seeder (init_sha = HEAD, session_id, session_ts) | done |
| AC6 | New tests pass; full suite green; lint Clean | done (775/775; lint exit 0) |
| AC7 | Operator REFRESH=1 baseline reset shows no seed folder in the fresh container (operator step 2, post-close verification) | pending (operator) |
