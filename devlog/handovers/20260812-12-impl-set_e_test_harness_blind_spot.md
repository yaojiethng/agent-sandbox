# Agent Handover

**Date:** 2026-08-12
**Milestone:** M2.6 — Session Persistence (general CLI/infra track)
**Type:** Implementation
**Status:** Closed

## Objective

Close the **`set -e` test-harness blind spot** (roadmap item at `devlog/roadmap.md`): `tests/test_*.sh` and `tests/libs/test_common.sh` run under `set -uo pipefail` **without** `-e`, so the trace tests never execute production scripts under the `set -euo pipefail` runtime. This is how the silent `REFRESH`-build abort (session `20260812-03`) slipped through. Make the harness (or targeted build/start_agent tests) exercise the `set -e` runtime so this class of abort is caught.

## Root cause of the blind spot (verified)

- `scripts/run_agent.sh` sets `set -euo pipefail` (line 40) — invoked as a subprocess in `test_trace_start.sh` (`invoke_run_agent_rc` → `bash run_agent.sh`), so run_agent's own `-e` applies there. That path is fine.
- **`scripts/build.sh` does NOT set `set -euo pipefail` itself** — it relies on the caller. In production, `start_agent.sh`/`run_agent.sh` (which set `-e`) invoke it, so `_buildkit_run` runs under `-e`. In tests, `test_trace_build.sh` `invoke_build` runs `bash build.sh` as a subprocess whose parent (the harness) has NO `-e` — so build.sh's `_buildkit_run` runs **without** `-e` in the test. Hence the production abort path is never exercised.
- `test_trace_build.sh` also `source`s `build.sh` + `buildkit_progress.sh` into the harness (lines 12-15), which runs under no-`-e`.

So the blind spot: **`build.sh`'s `set -e` behavior is caller-inherited and untested**, and there is no test that runs the build path under `-e` to catch `_buildkit_run`-class aborts.

## Candidate fix approaches (to confirm with operator)

- **(a) Make production scripts self-contained**: add `set -euo pipefail` at the top of `scripts/build.sh` (and audit any other sourcing script that relies on caller-`-e` but is also invoked/involved in tests). This makes production behavior explicit and deterministic, and fixes the subprocess-test blind spot for free (any `bash build.sh` then runs under `-e`). Cleanest in principle; touches production behavior.
- **(b) Harness-side**: have test invocations set `-e` explicitly (e.g. `invoke_build` wraps with `set -euo pipefail; bash build.sh`), only affecting tests, not production. Does not change production; but leaves `build.sh`'s reliance on caller-`-e` implicit.
- **(c) Targeted regression test**: add a test that runs `_buildkit_run`/`build.sh` under `set -e` and asserts the failure path is caught/descriptive (mirroring the session-03 fix).

Recommendation: **(a) + (c)** — make `build.sh` self-set `-e` (so invocation semantics are explicit and tests exercise it), then keep a regression test asserting the build-failure path under `-e`. Confirm whether the operator prefers production-side (a) or harness-only (b).

## Files in scope

| File | Role |
|---|---|
| `scripts/build.sh` | does not set `set -euo pipefail`; caller-inherited — the blind-spot locus (now self-enables `-e` on standalone) |
| `tests/test_trace_build.sh` | sources build.sh/buildkit_progress.sh + subprocess invoke under no-`-e`; added regression test |
| `test/stubs/docker` | added `DOCKER_STUB_BUILD_RC` env-gated `docker build` failure toggle |
| `scripts/run_agent.sh` | already sets `set -euo pipefail` (subprocess-safely) — reference |
| `tests/libs/test_common.sh` | harness `set -uo pipefail`, no `-e` |

## Deferred

(none)

## Completed this session

- [x] Reproduced/verified the blind spot: `build.sh` lacks self-set `-e`; subprocess tests inherit the harness's no-`-e`; `test_trace_start.sh` is safe (run_agent self-sets) but `test_trace_build.sh` is not.

## Decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | **`build.sh` self-enables `set -euo pipefail` on standalone invocation** (guarded so sourcing does not mutate callers) | production callers (start_agent/run_agent) already set `-e` before sourcing; standalone `bash build.sh` (tests) previously inherited the harness's no-`-e` — the blind spot. Guarded by `[[ BASH_SOURCE[0] == "$0" ]]` so sourcing into a test/consumer does not turn on `-e` there |
| 2 | Added `DOCKER_STUB_BUILD_RC` mock toggle | the existing mock could not make `docker build` fail (only compose up/run had RC stubs); required to write the build-failure-path regression test. [Flagged to operator — minor, pattern-consistent extension] |
| 3 | Regression test `test_build_image_failure_surfaces_descriptive_error_under_e` | verifies a failing `docker build` under standalone `set -e` surfaces the descriptive `build_image: ERROR build FAILED` message rather than a silent abort |

## Mid-session findings

| # | Finding | Disposition |
|---|---|---|
| 1 | The build failure-surfacing behavior (`build_image` `_build_rc` capture) already yields a descriptive error whether or not `-e` is set — so a failure-path test cannot distinguish the added `-e` flag on `-e`-clean code. The fix's value is *forward*: any future `set -e` landmine in the build path will now abort the trace tests (which invoke `build.sh` standalone under `-e`). The added test locks the failure-surfacing contract + the `-e` runtime context. | documented — the trace suite itself running under `-e` is the primary catch mechanism |
| 2 | Sourcing `build.sh` must not turn on `-e` for the caller/consumer | verified the guard makes sourcing a no-op for shell options (production callers already set `-e` themselves) |

## Deferred

(none)

## Completed this session

- [x] Verified the blind spot: `build.sh` lacks self-set `-e`; standalone `bash build.sh` in tests inherited the harness's no-`-e`
- [x] Added `set -euo pipefail` to build.sh's standalone guard (sourcing does not mutate callers)
- [x] Added `DOCKER_STUB_BUILD_RC` to the docker mock (env-gated `docker build` failure)
- [x] Added `test_build_image_failure_surfaces_descriptive_error_under_e` regression test
- [x] Full suite green (471/0/0); roadmap entry resolved

## Acceptance criteria

- [x] Production build path runs under `set -euo pipefail` deterministically on standalone invocation
- [x] A test exercises the build failure path under `-e` and asserts the descriptive failure (catches the silent-abort class)
- [x] Full suite green (471 passed, 0 failed, 0 skipped)
- [x] Roadmap item resolved; commit as `fix:`

## Operational notes

- `-e` semantics: a sourced library function returning non-zero aborts the whole script under `set -e` unless guarded (`|| true` / `|| _rc=$?` — repo-canonical per `bash-coding-conventions.md` rule 4.3).
- Follow `docs/development/bash-coding-conventions.md`; shellcheck-clean.
