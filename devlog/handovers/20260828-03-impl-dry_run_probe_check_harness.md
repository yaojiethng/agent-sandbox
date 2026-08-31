# Agent Handover

**Date:** 2026-08-28
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective
Build a host-side unit-test harness for the dry-run bearer probe checks, so every readiness assertion is exercised without a manual docker dry-run (the probes are otherwise invoked exactly once, through dry-run). Parameterize the probe lib path so the host suite can inject stubs for the in-container libs, then unit-test each layer's check in isolation.

## Scope
Roadmap item: "dry-run probe-check unit-test harness (test-harness hardening follows on the dry-run refactor)".

In scope:
- Parameterize `scripts/dry_run_capability.sh` + `scripts/dry_run_reasoning.sh` to source their in-container libs from a configurable `LIBS_DIR` (default `/opt/sandbox/lib`), so a host test can point at stubs.
- `test/stubs/libs/` with minimal `session_state_read` / `diff_export` / `dirs_resolve` / `routing` implementations needed to run each probe to completion.
- New `tests/test_dry_run_probe_*.sh` that run each probe in isolation with stubbed libs + a deterministic env and assert per-layer PASS/FAIL (docker_image / workspace_mounts / session_state / session_data / container_network / agent_runtime), including negative cases.
- Suite stays green (657 baseline) with no regression to the existing dry-run/record tests.

Deferred / not in scope: SERVE integration (its own roadmap bullet), Bug E stop-template, Bug D resume-volume (all escalated).

## Carried forward

| Item | From handover |
|---|---|
| Dry-run probe-check unit-test harness — the `LIBS_DIR` parameterization + stubbed-lib tests (recommended next step at the close of the dry-run execution-point iteration) | `20260828-02-impl-dry_run_container_startup` |
| SERVE mode integration (roadmap bullet; serve overlays rebased but untested; pi lacks server-mode support) | `20260828-02` finding |
| Bug E — `make stop` template missing `--project`/`--sandbox` + duplicate container-ID emission | `20260828-02` finding |
| Contextual-knowledge-light naming principle — fold into communications conventions at iteration end | `20260828-02` finding |

## Acceptance criteria
| # | Criterion | Status | Evidence |
|---|---|---|---|
| AC1 | Probes source libs from configurable `LIBS_DIR` (default `/opt/sandbox/lib`) with no container-behavior change | MET | both probes `LIBS_DIR="${LIBS_DIR:-/opt/sandbox/lib}"`; container env injects neither `LIBS_DIR`/`ROOT`/`SANDBOX_DIR`, defaults preserved |
| AC2 | Stubbed libs under `tests/stubs/libs/` drive each probe to completion with deterministic outcomes | MET | `session_state/diff_export/routing/dirs` + `BASH_ENV` loader |
| AC3 | Per-layer PASS/FAIL unit tests for BOTH probes, incl. one FAIL per red branch | MET | 47 new assertions in `tests/test_dry_run_probe.sh` (capability session_state/session_data/network; reasoning session_state/workspace_mounts/agent_runtime/network; healthy all-PASS + no-image-layer guard) |
| AC4 | Suite stays green with no regression to existing dry-run/record tests | MET | full suite 708/41 (was 657/40; 704 before init_sha lib test); 0 fail | 
| AC5 | Lint gate stays clean | MET | `check_lint.sh` 0 warnings/98 files | 
| AC6 | init_sha-validity hardens (rejects bogus hex, accepts a real commit) | MET | shared `init_sha_is_valid` in `session_state.sh`; harness bogus-hex FAIL + healthy PASS | 
| AC7 | Consolidation -- ONE init_sha-validity implementation across probe + all diagnostics, stale `session.sh` sourcing fixed | MET | `init_sha_is_valid` wired into probe + `diagnose_{preflight,autosave,dry_run_reasoning}`; `test_init_sha_is_valid_lib` | 


## Hot files
| File | Why in scope |
|---|---|
| `scripts/dry_run_capability.sh` / `dry_run_reasoning.sh` | parameterize lib path (`LIBS_DIR`) |
| `test/stubs/libs/` | minimal `session_state_read` / `diff_export` / `dirs_resolve` / routing stubs |
| `tests/test_dry_run_probe_*.sh` | new host-side per-layer unit tests |
| `tests/run_tests.sh` (or harness) | discover/run the new probe tests |

## Decisions
| Decision | Rationale | Scope |
|---|---|---|
| Bug D refined (operator): `make start RESUME=1` is intentionally removed via the `start`/`resume` two-command split; the reported baseline-reset was the OUTDATED invocation. The real residual to verify is whether `make resume` reuses the existing session volume (or recreates/resets it). | correct diagnosis of the reported bug; `start` no longer carries resume args | escalates to a named roadmap bullet this iteration |
| Harness uses a subshell-isolated probe run that writes results to a `key=value` state file; assertions are made in the PARENT scope (not the subshell) | `pass`/`fail` in `( ... )` fork the shell and lose the counters -> "NO-ASSERTION" (observed) | tests |
| Stub functions injected into probe `bash -c` sub-shells via `BASH_ENV` loader (`tests/stubs/libs/bash_env.sh`) rather than PATH executables | the probes spawn `bash -c` (export_path check) which does not inherit sourced function defs; BASH_ENV is the single mechanism | tests |
| `SANDBOX_DIR`/`ROOT`/`EXPECTED_MOUNT_TARGET` parameterized with `:-` defaults so the host suite can inject fixture roots | the probes hardcoded `/home/agentuser/...`; defaults preserve in-container behavior exactly | probes |

## Findings
- **Bug D refined (operator, `20260828-03`):** The earlier `RESUME=1` report is two bugs mixed. (1) `make start RESUME=1` is intentionally gone (start/resume split, `20260818-02`; `start` carries no `--resume`/`--session-id`) — invoking it is the OUTDATED path, not a live start bug. (2) `make resume` may genuinely be recreating the volume / resetting the baseline instead of attaching the persisted session volume. The actionable item is (2): verify `make resume` volume reuse for both deliveries (copy: volume; mount: worktree). Escalated to a named roadmap bullet (`make resume` volume reuse).
- **Finding RESOLVED (this iteration) -- init_sha-validity now verified via a single shared lib function.** Original weakness: `git rev-parse --verify --quiet <full-40-hex>` returns 0 for ANY well-formed full-length hex id (git does not verify object existence -- all-zeros and `f…f` both passed), so a bogus-but-well-formed hex init_sha passed the readiness depth gate. **Consolidation (operator: "refresh the diagnostic scripts to use the existing implementation"):** extracted `init_sha_is_valid SANDBOX_DIR` into `src/libs/session_state.sh` (`git cat-file -e "$sha^{commit}"` -- refuses nonexistent or non-commit objects) and rewired ALL consumers to it -- the capability probe gate AND the three knowledge diagnostics (`diagnose_{preflight,autosave,dry_run_reasoning}.sh`). This also fixed the diagnostics' stale `source /opt/sandbox/lib/session.sh` (no such file in the repo) to `session_state.sh`, so those blocks now actually run. New unit test `test_init_sha_is_valid_lib` (+4): valid commit -> 0; bogus hex -> non-zero; missing -> 1; non-commit blob -> non-zero. Behavior change: dry-run is STRICTER (a bogus-but-well-formed hex init_sha now red-lines session_state); healthy hosts unaffected.
- **Harness pattern note -- subshell assertions lose counters:** `pass`/`fail` called inside `( ... )` do not reach the parent (fork), producing "NO-ASSERTION". Solved by writing probe results to a state file in the subshell and asserting in parent scope.
- **Harness isolation note -- capability session_data FAIL uses `STUB_DIFF_EXPORT_FAIL`:** the diff_export stub gets a dedicated failure lever independent of repo state, so session_data can be flipped red while SESSION_STATE stays valid (removing `.git` would also trip session_state).

## Completed
- `scripts/dry_run_capability.sh` + `dry_run_reasoning.sh`: parameterized lib path + fixture roots (`LIBS_DIR`/`ROOT`/`SANDBOX_DIR`; reasoning `EXPECTED_MOUNT_TARGET`) with `:-` defaults preserving in-container behavior.
- `scripts/dry_run_capability.sh`: `check_init_sha_valid` removed; the gate now calls the shared `init_sha_is_valid "$SANDBOX_DIR"` from `session_state.sh` (operator-authorized hardening + consolidation).
- `src/libs/session_state.sh`: added `init_sha_is_valid SANDBOX_DIR` (single implementation; `git cat-file -e "$sha^{commit}"`).
- `tests/knowledge/diagnose_{preflight,autosave,dry_run_reasoning}.sh`: sharelibed the init_sha check; replaced stale `source .../session.sh` with `session_state.sh`.
- `tests/stubs/libs/session_state.sh`: mirrored `init_sha_is_valid` for the probe gate against the stub.
- `tests/test_dry_run_probe.sh`: session_state-fail fixture uses a realistic bogus 40-hex; added `test_init_sha_is_valid_lib` (4 direct library assertions).
- `tests/stubs/libs/`: `session_state.sh`, `diff_export.sh` (incl. `STUB_DIFF_EXPORT_FAIL` isolation lever + `wait_git_lockfile`), `routing.sh` (`export_path`), `dirs.sh`, `bash_env.sh` (BASH_ENV loader for `bash -c` sub-shells).
- `tests/test_dry_run_probe.sh`: 47 new tests -- healthy all-PASS (rc=0, record status/container/identity, all six layers) for both probes; FAIL branch per layer (capability session_state/session_data/container_network; reasoning session_state/workspace_mounts/agent_runtime/container_network); no-docker_image-layer guard.
- Fixture git repos now make a root commit (so `rev-parse HEAD` works); subshell/state-file harness pattern.
- Verified: full suite 704/41/0 (was 657/40/0, +47 new tests), lint gate 0 warnings.

## Deferred items
- Bug D — `make resume` volume-reuse verification (named roadmap bullet).
- Bug E — `make stop` template + duplicate-ID (escalate at iteration end).
- SERVE mode integration (named roadmap bullet).
- Contextual-knowledge-light naming principle (fold into communications conventions at iteration end).

## What's Next
M2.6 - Session Persistence. Post-close bookkeeping: n/a (mid-milestone).
The dry-run probe-check unit-test harness is delivered (this iteration): LIBS_DIR-parameterized probes + stubbed-lib per-layer tests (47 new). No manual-docker dependency remains for the readiness assertions. Pending escalations carried forward: SERVE mode integration (roadmap), Bug E (stop template), Bug D (`make resume` volume reuse, roadmap), contextual-knowledge-light naming principle (conventions), and a flagged adjacent finding (`check_init_sha_valid` verifies hex-form, not object existence -- potential hardening follow-on).
Watch-outs: dual-grep bridge; full-tree close-out greps.