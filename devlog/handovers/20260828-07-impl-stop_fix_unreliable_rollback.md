# Agent Handover

**Date:** 2026-08-28
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Fix Bug E (task brief `task-brief-20260828-bug-E-stop.md`): two defects in the `make stop` path. (1) the `stop:` target in `scripts/templates/Makefile.template` omits `--project`, so `make stop PRUNE=1` errors out; (2) a duplicate-container-ID / `docker rm ... already in progress` defect — mechanism to diagnose, then fix. Parallel notebooks: Bug D was resolved elsewhere (`20260828-04`), and a stop-teardown change may land from `20260828-05` (last_stopped `.log`, per the brief); operator manages rebase.

## Scope

In scope (both defects from the brief's objective/ACs):
- **Defect 1 — Makefile `stop:` omits `--project`:** add `--project=$(PROJECT_DIR)` to the `stop:` target in `scripts/templates/Makefile.template` (other commands in the same template already pass it). `stop.sh` already parses `--project` and forwards it to prune; `--sandbox=$(SANDBOX_DIR)` is already present. No prune behavior change.
- **Defect 2 — duplicate-ID / `docker rm ... already in progress`:** diagnose the mechanism (docker-stub trace + code reasoning; no docker host in-env), then fix defensively:
  - Dedupe `CONTAINER_IDS` after the `docker ps -aq` capture (defensive against duplicate emission).
  - Make `docker rm` tolerant of already-removed / already-being-removed containers (the race with `run_agent.sh`'s EXIT-trap `compose down` under the Container State Contract — durable state lives in the volume/bind mounts, containers are disposable). Keep `docker ps` fail-closed (`test_stop_docker_failure_aborts` contract).
  - Add a docker-stub hook to simulate `docker rm` failure ("already in progress") + a trace test asserting stop still completes cleanly.
- Tests: lock both fixes (a Makefile-target assertion for Defect 1; a trace test for Defect 2). Full suite + lint green.

Deferred / not in scope:
- Confirming the runtime race against a real docker host (operator e2e) — I verify the mechanism from code + stub only.
- Any change to `prune.sh` (Defect 1 is Makefile-only, per brief).
- Bug D (`20260828-04`) and resume/teardown changes from other parallel sessions.

## Carried forward

| Item | From handover |
|---|---|
| Bug E — `make stop` template missing `--project`/`--sandbox` + duplicate container-ID emission -> `docker rm ... already in progress`; "operator is already on it" | `20260828-02` findings (assigned to this brief) |

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| AC1 | `make stop` succeeds; `make stop PRUNE=1` no longer errors (`--project` forwarded from the Makefile target) | met (agent) - target test PASS, fails on old template; operator: docker host |
| AC2 | No `docker rm ... already in progress` abort on the stop path; removal made idempotent; trace test locks it in | met (agent) - race test PASS, fails on old stop.sh; operator: docker e2e |
| AC3 | `make stop` still preserves the session volume (no-destroy); existing stop trace tests + Bug D resume tests stay green | met (agent) - full suite 662/0/0 including test_stop_docker_failure_aborts (ps fail-closed kept) |
| AC4 | Suite green + lint `-S warning` = 0; new tests added (2) | met - 662/0/0, lint 0 |

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/templates/Makefile.template`](../../scripts/templates/Makefile.template) | `stop:` target — add `--project=$(PROJECT_DIR)` |
| [`scripts/stop.sh`](../../scripts/stop.sh) | dedupe `CONTAINER_IDS`; tolerant `docker rm` (race) |
| [`tests/test_trace_stop.sh`](../../tests/test_trace_stop.sh) | new trace test for the rm-failure tolerance; keeps existing stop/prune tests green |
| [`test/stubs/docker`](../../test/stubs/docker) | add a `docker rm` failure hook (e.g. `DOCKER_STUB_RM_FAIL`) |
| [`tests/test_onboard.sh`](../../tests/test_onboard.sh) | template-version site — lock the `stop:` target flag set (AC1) |

## Decisions

| Decision | Status |
|---|---|
| Defect 2 root cause: the "already in progress" is the RACE with `run_agent.sh`'s EXIT-trap `compose down`, NOT duplicate IDs in the `ps` capture (`docker ps -aq` yields each matched container once; `docker rm id id` does not error). "Lists same IDs twice" is stop-then-rm normal output. Fix = make `docker rm` idempotent; NO internal dedupe (dropped per operator - redundant under idempotent semantics) | CONFIRMED (operator) |
| `docker rm` failure handling: make `docker rm "${CONTAINER_IDS[@]}" || true` (silent, commented) the idempotent tolerance; keep `docker stop` fail-closed (stop failure = containers not signalled -> real precondition failure; rm failure = disposable containers already gone -> tolerate). `|| true` is the repo-canonical scoped idiom (bash-coding-conventions rule 1.16/4.3) | CONFIRMED (operator) |
| Handover numbering `-06` | CONFIRMED (operator: continue with own numbering) |

## Findings

- **Defect 1 confirmed by code read:** `stop:` target (`Makefile.template` lines 208-212) passes only `--name`, `--sandbox`, `$SESSION_ID_FLAG`, `$PRUNE_FLAG`; `stop.sh` errors `--prune requires --project` when `--project` is absent. Every other command in the template (start/resume/build/dry-run/diff/apply) already passes `--project`. No test asserts the stop target, so the omission was invisible to the suite (same class as the confirm-savepoint bug last iteration — untested path).
- **Defect 2 diagnosis (from code + stub):** `stop.sh` captures unique IDs from `docker ps -aq`, then `docker stop` then `docker rm "${CONTAINER_IDS[@]}"`. On a docker host, `docker stop` signals the running agent; `run_agent.sh`'s EXIT trap runs `session_teardown`/`compose down`, removing the same containers concurrently → `stop.sh`'s subsequent `docker rm` hits `removal of container ... already in progress` and, under `set -e`, aborts. The "same IDs listed twice" in the operator's symptom is `docker stop` then `docker rm` printing the same IDs (normal output), not duplicate capture entries.
- **Parallel-overlap risk (flagged):** `scripts/stop.sh` teardown may also be edited by `20260828-05` (last_stopped `.log`, per brief gotcha) and Bug D touched stop/resume tests (`20260828-04`). My stop.sh changes will be rebased by the operator.

## Completed

| File | Change |
|---|---|
| [`scripts/templates/Makefile.template`](../../scripts/templates/Makefile.template) | Defect 1: `stop:` target now passes `--project=$(PROJECT_DIR)` (was omitted -> `make stop PRUNE=1` errored; `--sandbox` already present) |
| [`scripts/stop.sh`](../../scripts/stop.sh) | Defect 2: `docker rm "${CONTAINER_IDS[@]}" || true` -- idempotent against the run_agent EXIT-trap `compose down` removal race (commented); `docker stop` stays fail-closed; no dedupe (dropped per operator) |
| [`test/stubs/docker`](../../test/stubs/docker) | `DOCKER_STUB_RM_FAIL` hook simulates the "already in progress" removal race |
| [`tests/test_trace_stop.sh`](../../tests/test_trace_stop.sh) | `test_stop_removal_race_is_tolerated` (PASS on fix, FAIL on old stop.sh); `DOCKER_STUB_RM_FAIL` added to per-test unset; `test_stop_docker_failure_aborts` kept green |
| [`tests/test_onboard.sh`](../../tests/test_onboard.sh) | `test_stop_target_forwards_project_dir` locks the `stop:` target flag set (PASS on fix, FAIL on old template) |
| This handover | scope, brief reception, diagnosis, decisions, ACs |

## Deferred items

- Runtime race confirmation on a docker host (operator e2e): `make start` then `make stop`, observe whether `docker rm already in progress` is eliminated.
- Any prune/resume/teardown changes outside the brief.

## What's Next

M2.6 - Session Persistence. Post-close bookkeeping: none (mid-series; parallel sessions continue).
After operator scope + decision confirmation: fix the Makefile `stop:` target (AC1), implement dedupe + tolerant `docker rm` + stub hook + trace test (AC2), lock the Makefile target with a test, run the full suite + lint, commit only my files (exclude the dry-run pair), present the AC table, close.
Watch-outs: GOTCHAS `[G] 2026-08-19` dual-grep bridge + `[G] 2026-08-23` full-tree close-out greps; keep `docker ps` fail-closed (`test_stop_docker_failure_aborts` cannot regress); no `git add -A` over the dry-run pair; `make test` runs files with `< /dev/null` stdin.