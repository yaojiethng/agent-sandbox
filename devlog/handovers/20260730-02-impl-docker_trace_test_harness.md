# Agent Handover

**Session date:** 2026-07-30
**Milestone:** M2.6 — Session Resume and Mount Model Redesign
**Session type:** Implementation — Docker command-trace end-to-end test harness
**Status:** Closed

## Objective

Build a PATH-based docker stub and end-to-end trace tests that invoke `agent-sandbox` subcommands against it, asserting the recorded docker/compose commands match expectations. Verifies volume lifecycle fixes from the prior session.

## Scope

Two units:

**Unit 1 — Docker stub:** `test/stubs/docker` — a single executable that intercepts `docker` invocations via PATH shadowing. Records all commands to `DOCKER_TRACE_LOG`. For `compose config`, returns the first `-f` input file as valid YAML. For `inspect` healthcheck queries, returns `healthy`. For `wait`, returns immediately. Handles compose arg parsing (`-f`, `--project-name`, `--project-directory`, flags) to correctly identify the subcommand.

**Unit 2 — Trace tests:** Four test files following existing conventions (`tests/libs/test_common.sh`, `mktemp -d` fixtures, `trap` cleanup):

| Test file | Scenarios | Tests |
|---|---|---|
| `tests/test_trace_start.sh` | `start` (standard), `start --refresh`, `start --rebuild`, `serve` | 8 |
| `tests/test_trace_stop.sh` | `stop`, `stop --prune`, `prune` (standalone) | 6 |
| `tests/test_trace_dry_run.sh` | `dry-run` with/without `--reset-volume` | 4 |
| `tests/test_trace_build.sh` | `build` | 3 |

## Carried forward

| Item | From handover |
|---|---|
| End-to-end test harness with stubbed docker/compose covering all `agent-sandbox` subcommands | 20260730-01-impl-volume_teardown_and_lifecycle_modularization |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | `docker` stub syntax valid and executable | `bash -n test/stubs/docker` passes | Accepted |
| 2 | `compose config` stub returns valid YAML so `compose_generate` doesn't fail | `docker compose -f ... config --no-interpolate` returns valid YAML | Accepted |
| 3 | `inspect` healthcheck returns `healthy` so `compose_sandbox_wait` doesn't loop | `docker inspect --format '{{.State.Health.Status}}'` returns `healthy` | Accepted |
| 4 | All trace tests pass (21 tests across 4 files) | `bash tests/test_trace_*.sh` all exit 0 | Accepted |
| 5 | `start` trace: zero `down -v` | `test_trace_start.sh` tests 1, 4 | Accepted |
| 6 | `start --refresh` trace: exactly one `down -v` (pre-start) | `test_trace_start.sh` tests 5, 6 | Accepted |
| 7 | `stop` and `stop --prune` traces: no compose invocations | `test_trace_stop.sh` tests 1, 3 | Accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`test/stubs/docker`](test/stubs/docker) | New: docker command-recording stub |
| [`tests/test_trace_start.sh`](tests/test_trace_start.sh) | New: start subcommand trace tests |
| [`tests/test_trace_stop.sh`](tests/test_trace_stop.sh) | New: stop subcommand trace tests |
| [`tests/test_trace_dry_run.sh`](tests/test_trace_dry_run.sh) | New: dry-run subcommand trace tests |
| [`tests/test_trace_build.sh`](tests/test_trace_build.sh) | New: build subcommand trace tests |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| PATH-based shadowing for docker stub | Scripts under test call `docker` as external command; stub named `docker` on PATH intercepts all invocations | Chat |
| Stub returns first `-f` file for `compose config` | Already valid YAML after sed substitution; no dynamic generation needed | Chat |
| Tests follow existing convention: `tests/test_trace_*.sh` | Per testing policy — flat in `tests/`, prefix naming, source `tests/libs/test_common.sh` | Chat |

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| Stub arg parser needed to skip `--project-name` and `--project-directory` flags to correctly identify compose subcommand | bug | Unit 1 — fixed by expanding flag-skipping logic |
| `compose config` stub initially failed because `-f` was incorrectly parsed as subcommand | bug | Unit 1 — fixed by iterating through args to skip `-f <file>` pairs |
| Fixture directory names containing "compose" caused false `grep "compose"` matches in trace logs | scope change | Unit 2 — renamed fixture dirs to avoid substring collision |

## Completed this session

| File | Change summary |
|---|---|
| [`test/stubs/docker`](test/stubs/docker) | PATH-based docker/compose command-recording stub; handles compose arg parsing, inspect healthcheck, compose config passthrough |
| [`tests/test_trace_start.sh`](tests/test_trace_start.sh) | 8 tests: start standard, --refresh, --rebuild, serve — verify compose down/up/run commands and `-v` placement |
| [`tests/test_trace_stop.sh`](tests/test_trace_stop.sh) | 6 tests: stop, stop --prune, prune standalone — verify no compose invocations, ps/stop/rm/system prune commands |
| [`tests/test_trace_dry_run.sh`](tests/test_trace_dry_run.sh) | 4 tests: dry-run — verify compose up/exec/down, `-v` only with --reset-volume |
| [`tests/test_trace_build.sh`](tests/test_trace_build.sh) | 3 tests: build — verify docker image inspect, docker build, no compose invocations |

## Deferred items

None.

## Next session

Continue M2.6.4 mount model design.

**Conclusions from this session:** The PATH-based docker stub enables trace-level testing of all `agent-sandbox` subcommands without a Docker daemon. 21 tests across 4 files verify correct `-v` placement: pre-start only on `--refresh`/`--rebuild`, never post-agent, never in stop/prune.
