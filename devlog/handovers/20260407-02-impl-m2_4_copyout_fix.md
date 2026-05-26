# Agent Handover

**Session date:** 2026-04-07
**Milestone:** M2.4 — Session and Config Persistence
**Session type:** Implementation

## Objective

Fix the copy-out workflow (broken by `exec` in `provider-entrypoint.sh`) and validate that provider config is correctly persisted across a session.

## Scope

Bug fixes to `provider-entrypoint.sh` and all three provider Dockerfiles. Copy-out workflow validated end-to-end including the SIGTERM (docker stop) path. Commit persistence in the diff pipeline investigated as an adjacent question.

## Acceptance criteria

- [x] **Multi-session round-trip** — run a session, allow the agent to write state to `AGENT_HOME`, stop the container, then start a new session. Confirm that the state written in session N is present in `AGENT_HOME` at the start of session N+1. Pass: state persists. Fail: `AGENT_HOME` starts empty or reverts to onboarding templates.
- `libs/provider-entrypoint.sh` — background launch + `wait` with EXIT/TERM traps for copy-out.
- All three provider Dockerfiles — `/opt/provider-config` pre-created before `USER agentuser`.

## Hot files

| File | Why in scope |
|---|---|
| [`libs/provider-entrypoint.sh`](../../../libs/provider-entrypoint.sh) | Copy-out bug fixed here |
| [`providers/hermes/provider.Dockerfile`](../../../providers/hermes/provider.Dockerfile) | Mount point pre-creation added |
| [`providers/opencode/provider.Dockerfile`](../../../providers/opencode/provider.Dockerfile) | Mount point pre-creation added |
| [`providers/pi/provider.Dockerfile`](../../../providers/pi/provider.Dockerfile) | Mount point pre-creation added |
| `docs/devlog/handovers/20260407-02-impl-m2_4_copyout_fix.md` | Acceptance criterion marked as passed |
| `docs/devlog/roadmap.md` | M2.4 status updated from "In progress" to "Complete" |

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

M2.3 — Apply Workflow: Capability Layer Diff Pipeline is the next milestone in the M2 track. See roadmap for scope.