# Agent Handover

**Session date:** 2026-04-07
**Milestone:** M2.4 — Session and Config Persistence
**Session type:** Implementation

## Objective

Fix the copy-out workflow (broken by `exec` in `provider-entrypoint.sh`) and validate that provider config is correctly persisted across a session.

## Scope

Bug fixes to `provider-entrypoint.sh` and all three provider Dockerfiles. Copy-out workflow validated end-to-end including the SIGTERM (docker stop) path. Commit persistence in the diff pipeline investigated as an adjacent question.

## Acceptance criteria

- [ ] **Multi-session round-trip** — run a session, allow the agent to write state to `AGENT_HOME`, stop the container, then start a new session. Confirm that the state written in session N is present in `AGENT_HOME` at the start of session N+1. Pass: state persists. Fail: `AGENT_HOME` starts empty or reverts to onboarding templates.

## Hot files

| File | Why in scope |
|---|---|
| [`libs/provider-entrypoint.sh`](../../../libs/provider-entrypoint.sh) | Copy-out bug fixed here |
| [`providers/hermes/provider.Dockerfile`](../../../providers/hermes/provider.Dockerfile) | Mount point pre-creation added |
| [`providers/opencode/provider.Dockerfile`](../../../providers/opencode/provider.Dockerfile) | Mount point pre-creation added |
| [`providers/pi/provider.Dockerfile`](../../../providers/pi/provider.Dockerfile) | Mount point pre-creation added |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| `exec "$@"` replaced with background launch + `wait` in `provider-entrypoint.sh` | `exec` replaces the shell process — EXIT trap is discarded and copy-out never runs. Background launch keeps the shell alive so the EXIT trap fires on exit. | `provider-entrypoint.sh` |
| SIGTERM forwarded to child; SIGINT trapped as no-op | Two termination cases: (1) normal exit — agent quits, `wait` returns, EXIT trap fires; (2) `docker stop` — SIGTERM arrives at PID 1 (shell) only, TERM trap forwards it to the child then exits. SIGINT is not forwarded — the child receives it directly via the process group and the TUI handles it internally. Forwarding INT caused every Ctrl-C inside the TUI to kill the agent. | `provider-entrypoint.sh` |
| `/opt/provider-config` pre-created as root before `USER agentuser` in provider Dockerfiles | Docker auto-creates missing bind mount targets as root; pre-creating before the USER switch is explicit and keeps the image layer clean. | all three `provider.Dockerfile` |
| Commit history not preserved in `staged.diff` — deferred to M2.3 | `git diff BASELINE..HEAD` captures net file delta only. Commit history preservation (checkpoint branches, bundles) is M2.3 scope. No action for M2.4. | roadmap.md |

## Completed this session

| File | Change |
|---|---|
| `libs/provider-entrypoint.sh` | Replaced `exec "$@"` with background launch + `wait`; TERM trap forwards to child, INT trap is no-op; comments updated to reflect two-case termination model |
| `providers/hermes/provider.Dockerfile` | Added `RUN mkdir -p /opt/provider-config` before `USER agentuser` |
| `providers/opencode/provider.Dockerfile` | Added `RUN mkdir -p /opt/provider-config` before `USER agentuser` |
| `providers/pi/provider.Dockerfile` | Added `RUN mkdir -p /opt/provider-config` before `USER agentuser` |
| `docs/devlog/roadmap.md` | M2.4 scope note updated to reflect current state |

## Deferred items

None.

## Next session

M2.4 — Session and Config Persistence, close-out.

Define formal acceptance criteria and run a dry-run against a real provider image. If the dry-run passes, close M2.4 (Trigger B).

Watch-out items:
1. The entrypoint change (`exec` → background + `wait`) means the shell is now PID 1 and the agent runs as a child. Verify the agent receives SIGTERM correctly on `docker stop` during the manual test — the grace period before SIGKILL is 10s by default.
2. The `provider-entrypoint.sh` is baked into the image at build time — images must be rebuilt before the manual test reflects the fix.
3. Acceptance criteria should be operator-runnable against the manual test output — file presence in `$SANDBOX_DIR/.<provider>/` after container exit is the observable to check.
4. Two termination paths to verify: (a) normal TUI exit — quit the agent from within the TUI and confirm copy-out ran; (b) `docker stop` — stop the container externally and confirm copy-out ran.
