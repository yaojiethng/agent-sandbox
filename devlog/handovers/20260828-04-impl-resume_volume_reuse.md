# Agent Handover

**Date:** 2026-08-28
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation (bugfix)
**Status:** Closed

## Objective
Verify and fix `make resume` so it ATTACHES the existing session's volume (preserving the persisted baseline/state) rather than recreating the volume / resetting the baseline. Refines the Bug D finding from `20260828-03` (the earlier `make start RESUME=1` report was an outdated invocation; the live question is whether the `make resume` path reuses the persisted session volume for both deliveries -- copy: named volume; mount: worktree).

## Scope
TBD -- confirmed with operator at Gate 1.

## Carried forward

| Item | From handover |
|---|---|
| Bug D -- `make resume` volume-reuse (this iteration) | `20260828-02` finding, refined `20260828-03`, roadmap bullet |
| SERVE mode integration (roadmap bullet) | `20260828-02` |
| Bug E -- `make stop` template + duplicate-ID | `20260828-02` |
| Contextual-knowledge-light naming principle | `20260828-02` |

## Acceptance criteria
| # | Criterion | Status | Evidence |
|---|---|---|---|
| AC1 | `make resume` does NOT destroy the session's named volume (copy delivery) | MET | `tests/test_trace_resume.sh`: zero `compose down -v`, zero `volume rm`, zero `--reset-volume`; teardown = `compose down`; sandbox re-attached via `compose up -d sandbox` |
| AC2 | `make resume` does NOT destroy state for mount (worktree) delivery | MET | mount-mode resume: zero `down -v` / `volume rm` / `--reset-volume` |
| AC3 | resume reuses the record's SESSION_ID, so the compose namespace + `SESSION_ID-sandbox-data` volume are stable across start -> resume | MET | regenerated `.compose/<id>.yml` keeps `agent-sandbox.session-id` == record; project/volume name is SESSION_ID-derived (copy overlay `{{SESSION_ID}}-sandbox-data`) |
| AC4 | Suite stays green and lint clean with the new tests + runner fix | MET | suite 719/42 (was 708/41); lint 0 warnings/99 files |


## Hot files
TBD -- after repo reconnaissance.

## Decisions
| Decision | Rationale | Scope |
|---|---|---|
| Bug D verified as NOT reproducible in the resume path: resume preserves the session volume. Original "RESUME reset" report was the deprecated `make start RESUME=1` (by-design fresh start; creates a NEW SESSION_ID -- the old session's volume is preserved under its own id). No production-code fix required. | trace + code audit: teardown keeps volumes, no destroy/reset ops, volume name is SESSION_ID-stable, entrypoint resume branch skips re-seed | resume verification + regression-guard tests |
| Deliverable for Bug D = regression tests locking in the no-destroy + namespace-stability invariants, plus a test-infra fix exposed by the new test. | Bug D request was "verify it attaches the existing volume"; verification is the deliverable | tests + runner |


## Findings
- **Bug D verdict (this iteration) -- resume correctly preserves the session volume; no production bug found.** Trace of the full resume path under the docker stub (copy + mount) shows: teardown is `compose down` (keeps named volumes -- never `down -v`/`session_destroy`); no `docker volume rm`; no `--reset-volume` forwarding (RESET_VOLUME stays false); sandbox re-attached via `compose up -d sandbox`. `compose_args` project = `normalised-SESSION_ID` and the copy overlay volume = `{{SESSION_ID}}-sandbox-data`, and resume reuses the RECORD's SESSION_ID (via `session_env_names`), so Docker attaches the SAME volume. The capability entrypoint resume branch (volume already has `.git`) skips `snapshot_init_git` re-seed and preserves SESSION_STATE. The original "RESUME reset" observation was the deprecated `make start RESUME=1`: start always begins a NEW session (new SESSION_ID/new volume); the old session's volume is preserved under its own SESSION_ID. `make start RESUME=1` is already documented as unsupported (Makefile "NOTE ON RESUME").
- **Latent test-runner bug EXPOSED and FIXED by adding the resume trace test (`run_tests.sh`).** `run_single` ran each test file with shared stdin: the runner iterates test files via `<<< "$TEST_FILES"` (a temp-file FD shared with every `bash "$FILE"` subprocess). A subprocess that read stdin (the resume test's `run_agent.sh` chain) advanced the FD offset, causing `read` in the discovery loop to hit EOF early and silently SKIP trailing files (here: `test_trace_start.sh`+`test_trace_stop.sh` = 31 tests), so the suite reported 40 files/688 instead of 42/719. Fixed with `< /dev/null` on the `bash "$FILE"` invocation in `run_single`, so test subprocesses can no longer touch the loop's stdin. Reproduced the mechanism minimally (a per-iteration `read x < /dev/stdin` halves loop iterations).
- **Stub compose-config artifact (documented, not a bug):** the docker stub's `compose config` returns only the first input file (does not merge overlays), so the named volume can't be asserted from a stub-merged output -- asserted at the overlay level (`docker-compose.copy.yml` carries `{{SESSION_ID}}-sandbox-data`) + the namespace-stability test here.
- **Note:** `make start RESUME=1` is an unused var in the start target (fresh start by design); not a data-loss path for the old session (its volume persists under its SESSION_ID).

## Completed
- **Verification (Bug D):** audited + traced the full resume path under the docker stub for copy and mount deliveries; confirmed resume preserves the session volume (no destroy/reset, SESSION_ID-stable namespace, entrypoint resume branch keeps SESSION_STATE). No production-code fix needed.
- `tests/test_trace_resume.sh` (NEW, 11 tests): `test_resume_copy_keeps_named_volume` (no `down -v`/`volume rm`/`--reset-volume`; teardown `compose down`; sandbox re-attached), `test_resume_reuses_record_session_id` (regenerated compose keeps record SESSION_ID), `test_resume_mount_keeps_worktree` (mount-mode no-destroy).
- `scripts/run_tests.sh` (FIX): `run_single` now runs each test with stdin from `/dev/null`, so test subprocesses cannot advance the discovery loop's shared here-string FD and silently drop trailing files. Suite restored to the true 42-file/719-test count.
- Verified: suite 719/42/0; lint `-S warning` 0 warnings/99 files; shellcheck clean on runner + new test.

## Deferred items
- SERVE mode integration (roadmap).
- Bug E -- `make stop` template + duplicate-ID (escalate at iteration end).
- Contextual-knowledge-light naming principle (conventions at iteration end).

## What's Next
M2.6 - Session Persistence. Post-close bookkeeping: n/a (mid-milestone).
Bug D is VERIFIED as non-reproducible in the resume path: `make resume` preserves the session volume (regression tests `tests/test_trace_resume.sh` lock in the no-destroy + namespace-stability invariants for copy and mount deliveries; a latent test-runner stdin bug was also fixed). Original "RESUME reset" was the deprecated `make start RESUME=1` (by-design fresh start; old volume preserved). Remaining escalations: SERVE mode integration (roadmap), Bug E (`make stop` template + duplicate-ID), contextual-knowledge-light naming principle (conventions).
Watch-outs: dual-grep bridge; full-tree close-out greps.