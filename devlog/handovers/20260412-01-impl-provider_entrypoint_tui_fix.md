# Agent Handover

**Session date:** 2026-04-12
**Milestone:** M2.4 — Session and Config Persistence
**Session type:** Implementation

## Objective

Diagnose and fix the TUI regression introduced in the prior session's `provider-entrypoint.sh` change, produce a regression test suite, record findings in an investigation document, and harden the dry-run diagnostic.

## Scope

Emergency bug fix within M2.4. The prior session replaced `exec "$@"` with a background-job + `wait` pattern to enable copy-out, which broke TUI interaction. This session covered: root cause analysis across multiple iterations, final fix implementation, investigation document (11 findings), test suite, and dry-run hardening.

The investigation went through four candidate implementations before reaching the correct solution. Each failure exposed a new root cause. The investigation document is the authoritative record of why each approach failed.

## Acceptance criteria

- [ ] **Multi-session round-trip** *(carried from prior session, pushed — awaits image rebuild and manual test)* — run a session, allow the agent to write state to `AGENT_HOME`, stop the container, start a new session. Confirm that state written in session N is present in `AGENT_HOME` at session N+1. Pass: state persists. Fail: `AGENT_HOME` starts empty or reverts to onboarding templates.

Note: only test termination path (a) — normal TUI exit. Path (b) — `docker stop` mid-session — does not trigger copy-out under the final design (SIGTERM limitation; see Decisions).

## Hot files

| File | Why in scope |
|---|---|
| [`libs/provider-entrypoint.sh`](../../../libs/provider-entrypoint.sh) | TUI regression fixed here; final design is synchronous foreground child |
| [`tests/test_provider_entrypoint.sh`](../../../tests/test_provider_entrypoint.sh) | New file — 11 regression tests including stdin guard |
| [`docs/discussions/investigation_provider_entrypoint_tui_regression.md`](../../../docs/discussions/investigation_provider_entrypoint_tui_regression.md) | New file — 11 findings, full root cause record |
| [`tests/dry_run.sh`](../../../tests/dry_run.sh) | Hardened — PASS/FAIL/WARN framework, non-zero exit on critical failures |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| Final design: synchronous foreground child — `"$@"` then `_copy_out` | Every background-job approach failed TUI input. POSIX mandates stdin=/dev/null for background jobs in non-interactive shells; the agent read from /dev/null the entire time. Synchronous child inherits stdin (PTY in Docker), is in the shell's foreground process group, and has no SIGTTIN on reads. | `provider-entrypoint.sh`, investigation doc Finding 11 |
| `set -m` + `fg` approach retired | `set -m` gives the background job its own process group, outside the terminal foreground group. First terminal read generates SIGTTIN, stopping the agent mid-TUI-initialisation. `fg` resumes it but TUI library is in an inconsistent state. | investigation doc Finding 10 |
| Background without `set -m` also retired | Without job control, POSIX redirects background job stdin to /dev/null regardless of process group. Verified by `readlink /proc/$$/fd/0` in a non-interactive bash background child. | investigation doc Finding 11 |
| SIGTERM limitation accepted | With synchronous child, bash defers TERM trap until child exits. `docker stop` mid-session does not trigger copy-out; after 10s grace period Docker sends SIGKILL. Normal exit path (user quits TUI) is unaffected. If copy-out on forced stop is required, implement at harness level via `docker cp` after container exit. | `provider-entrypoint.sh`, investigation doc Finding 11 |
| `PROVIDER_CONFIG_DIR` required — no default | Prior design had `PROVIDER_CONFIG_DIR=${VAR:-/opt/provider-config}`. Hardcoded default paths may be read-only on some systems. Now validated at startup like `AGENT_HOME` and `PROVIDER_NAME`; provider Dockerfiles supply the value via `ENV`. | `provider-entrypoint.sh` |
| Script modularised into `_require_var`, `_copy_in`, `_copy_out` named functions | Easier to read, test, and audit independently. `_copy_in` call was dropped during an earlier refactor pass and only caught by the test suite — modularisation makes this class of omission visible. | `provider-entrypoint.sh` |
| `dry_run.sh`: removed `set -e`; added PASS/FAIL/WARN framework with non-zero exit | Original script exited on first failure (never ran remaining checks) and always exited 0 regardless of failures. Now all checks run; exits 1 if any CRITICAL check fails. | `tests/dry_run.sh` |
| `dry_run.sh`: stdin-not-/dev/null check added as CRITICAL | Direct regression guard: if anyone reintroduces a background job in the entrypoint, the dry-run catches it immediately. Uses inode comparison against /dev/null for robustness. | `tests/dry_run.sh`, investigation doc Finding 11 |
| `dry_run.sh`: `PROVIDER_CONFIG_DIR` writability added as CRITICAL | Copy-in and copy-out silently fail if the bind-mount isn't writable. Previously undetected until a live session. | `tests/dry_run.sh` |
| `dry_run.sh`: env var presence checks added as CRITICAL | `AGENT_HOME`, `PROVIDER_NAME`, `PROVIDER_CONFIG_DIR` are now required by the entrypoint; missing any causes silent failure at runtime. | `tests/dry_run.sh` |
| `dry_run.sh`: `workspace/input` read-only check added as CRITICAL | Security invariant — agent must not be able to modify the input channel. | `tests/dry_run.sh` |

## Completed this session

| File | Change |
|---|---|
| `libs/provider-entrypoint.sh` | Rewritten: synchronous `"$@"` approach; `_require_var`, `_copy_in`, `_copy_out` as named functions; `PROVIDER_CONFIG_DIR` required (no default); no `set -m`, no `fg`, no background job |
| `tests/test_provider_entrypoint.sh` | New file — 11 tests: env validation, copy-in (3 cases), copy-out (2 cases), exit code (2 cases), stdin-not-/dev/null regression guard; all passing |
| `docs/discussions/investigation_provider_entrypoint_tui_regression.md` | New file — 11 findings documenting every failure mode encountered, constraints, final resolution with rationale, TUI requirements explanation, and testing plan |
| `tests/dry_run.sh` | Hardened: removed `set -e`, added check framework (PASS/FAIL/WARN), non-zero exit on critical failures, 14 checks across 7 sections including stdin, env vars, and PROVIDER_CONFIG_DIR |

## Deferred items

None.

## Next session

M2.4 — Session and Config Persistence, close-out.

Trigger B is pending — the multi-session round-trip acceptance criterion has not been run.

Steps before closing M2.4:
1. `make build` — `provider-entrypoint.sh` is baked in at build time; the fix is not live until all three provider images (hermes, opencode, pi) are rebuilt.
2. `make dry-run PROVIDER=<n>` — verify the hardened diagnostic passes. Key checks to watch: AGENT_HOME/PROVIDER_NAME/PROVIDER_CONFIG_DIR are set, stdin is not /dev/null, PROVIDER_CONFIG_DIR is writable.
3. `make start PROVIDER=<n>` — verify TUI input works (keystrokes reach the agent).
4. Run the multi-session round-trip: start a session → agent writes state to AGENT_HOME → quit the TUI normally → start a new session → confirm state is present. Test normal TUI exit only; `docker stop` mid-session does not trigger copy-out by design.
5. If criterion passes, run Trigger B to close M2.4.

Watch-out items:
1. All prior decisions about background+wait, `set -m`, and `fg` are superseded. The authoritative design is the synchronous approach. The investigation document (Finding 10 and 11) is the rationale. Do not reintroduce any `"$@" &` pattern without understanding both findings first.
2. The `"$@"` job-control notification noise that appeared in prior test runs is gone — `fg` is eliminated. If it reappears, `set -m` has been reintroduced.
3. `PROVIDER_CONFIG_DIR` must be set via `ENV` in every provider Dockerfile. Any provider without it will fail the dry-run env var check and the entrypoint validation.
