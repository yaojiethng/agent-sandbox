# Agent Handover

**Session date:** 2026-03-29
**Milestone:** M2.2 — Reasoning Layer Modularisation
**Session type:** Implementation

## Objective

Implement the Pi provider (`providers/pi/`), refresh the Pi investigation document, apply two `make start` hardening fixes, and close M2.2.

## Scope

Pi provider implementation, investigation refresh, `start_agent.sh` hardening (stop-before-start, auto-build-if-missing), Trigger B.

## Acceptance criteria

Carried from prior sessions (open):
- [x] A second provider can be added with no changes to `scripts/` or `libs/` — proven empirically by Pi integration

New this session — all accepted:
- [x] `make dry-run PROVIDER=pi` passes
- [x] `make start PROVIDER=pi` launches Pi interactive TUI correctly
- [x] `make serve PROVIDER=pi` exits with a clear unsupported error (documented in serve overlay)
- [x] `make build TARGET=pi` builds `pi-base` and `pi-agent-<project>` images without error
- [x] `agent-sandbox onboard` appends Pi `.env` stubs to project `.env`
- [x] No changes required to `scripts/` or `libs/` to add Pi
- [x] `make start PROVIDER=<n>` stops any existing session containers before starting (via stop.sh delegation)
- [x] `make start PROVIDER=<n>` triggers an automatic build if images are not found

## Hot files

| File | Why in scope |
|---|---|
| `providers/pi/base.Dockerfile` | New |
| `providers/pi/provider.Dockerfile` | New |
| `providers/pi/docker-compose.serve.yml` | New |
| `providers/pi/.env.example` | New |
| `providers/pi/docker-compose.pi.yml` | New |
| `providers/pi/setup.sh` | New |
| `providers/pi/config/AGENTS.md` | New |
| `scripts/start_agent.sh` | Stop-before-start + auto-build-if-missing |
| `docs/discussions/investigation_pi.md` | Refreshed for Pi v0.63.1 |
| `docs/development/roadmap.md` | Trigger B — M2.2 removed, M2.3 promoted |
| `docs/development/changelog.md` | M2.2 entry appended |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| Pi `AGENTS.md` via two mechanisms: project-committed file (primary) + `providers/pi/config/AGENTS.md` global stub (fallback) | Project file takes precedence via Pi's discovery order; stub ensures working harness context on projects with no `AGENTS.md` | `investigation_pi.md`, `providers/pi/config/AGENTS.md` |
| `PI_SKIP_VERSION_CHECK=1` set via provider overlay | Suppresses noisy update checks on every container start | `providers/pi/docker-compose.pi.yml` |
| Pin Pi at `0.63.1` in `base.Dockerfile` | Rapid release cadence (~33 versions in 3 months); pinning prevents silent breakage | `providers/pi/base.Dockerfile` |
| `AGENT_HOME=/home/agentuser/.pi/agent` | Pi's config directory is `~/.pi/agent/`; `PI_CODING_AGENT_DIR` overrides if needed | `providers/pi/provider.Dockerfile` |
| Stop-before-start via compose project label check + stop.sh delegation | Label filter catches all containers regardless of provider; avoids redundant logic; clean start is silent | `scripts/start_agent.sh` |
| Auto-build missing images in `start_agent.sh`, not in `preflight` | `preflight` retains its role as a pure check; build logic stays with the orchestration layer | `scripts/start_agent.sh` |
| Claude Desktop provider deferred from M2.2 | Not in scope this session; operator confirmed M2.2 close | `roadmap.md` — M2.3 deferred note |

## Completed this session

| File | Change |
|---|---|
| `providers/pi/base.Dockerfile` | New — Node 20 slim + pinned Pi install |
| `providers/pi/provider.Dockerfile` | New — standard provider pattern |
| `providers/pi/docker-compose.serve.yml` | New — serve unsupported stub with documentation |
| `providers/pi/.env.example` | New — API key stubs for all supported LLM providers |
| `providers/pi/docker-compose.pi.yml` | New — `PI_SKIP_VERSION_CHECK=1` + API key injection |
| `providers/pi/setup.sh` | New — pre-creates `$SANDBOX_DIR/.pi/` |
| `providers/pi/config/AGENTS.md` | New — global fallback brief stub |
| `scripts/start_agent.sh` | Stop-before-start (compose label check + stop.sh) + auto-build-if-missing added before dispatch |
| `docs/discussions/investigation_pi.md` | Refreshed — all sections updated for Pi v0.63.1; implementation recorded |
| `docs/development/roadmap.md` | M2.2 removed (Trigger B); summary table row marked complete; M2.3 promoted as active |
| `docs/development/changelog.md` | M2.2 entry appended |

## Deferred items

| Item | Reason | Where next |
|---|---|---|
| Claude Desktop provider integration | Not in scope this session; operator confirmed M2.2 close | M2.3 — confirm at next session open whether to implement under M2.3 or push to `roadmap_future.md` |
| `container_model.md` / `sandbox_lifecycle.md` structural overlap | Carried from prior sessions | Future doc cleanup pass |
| Session state persistence | Carried from prior sessions | Post-M2 milestone |

## Next session

M2.3 — Apply Workflow: Capability Layer Diff Pipeline.

Trigger B has run. M2.2 is closed.

First task at next session open: confirm with operator whether Claude Desktop integration should be pulled into M2.3 scope or deferred further, before beginning M2.3 design work.

Watch-out: verify `AGENT_HOME=/home/agentuser/.pi/agent` is correct on first `make start PROVIDER=pi` — Pi may write config to a slightly different path. Check with `docker exec <container> ls ~/.pi/` if copy-out state is absent after session exit.
