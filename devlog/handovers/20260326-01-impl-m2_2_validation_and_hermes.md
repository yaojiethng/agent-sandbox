# Agent Handover

**Session date:** 2026-03-26
**Milestone:** M2.2 — Reasoning Layer Modularisation
**Session type:** Implementation

## Objective

Validate all M2.2 proposals from the prior session, fix issues found during testing, and close the sub-milestone.

## Scope

- Validate and fix Makefile/CLI refactor (`--target` for build, `make stop`)
- Validate and fix Hermes provider (Dockerfile pip install failure, entrypoint/serve mode)
- Update architecture docs (`tool_interface.md`, `execution_model.md`)
- Run acceptance criteria

## Acceptance criteria

- [x] `agent-sandbox onboard` produces `.env` with stubs from all `providers/*/env.example`; no `docker-compose.serve.yml` in `SANDBOX_DIR`
- [x] `make build TARGET=opencode` builds `opencode-agent-<project>` image
- [x] `make build` (no TARGET) builds sandbox + all providers
- [x] `make dry-run PROVIDER=opencode` passes — regression check on refactored infrastructure
- [x] `make serve PROVIDER=opencode` resolves serve overlay from `providers/opencode/` not `SANDBOX_DIR`
- [x] `make build TARGET=hermes` builds `hermes-agent-<project>` image
- [x] `make dry-run PROVIDER=hermes` passes — Hermes liveness check
- [ ] `make stop` stops all session containers and volumes — **deferred** (see below)
- [ ] A second provider can be added under `providers/<n>/` with no changes to `scripts/` or `libs/` — **deferred**, revisit when a new provider is added; Hermes itself was the refactor that made this true going forward
- [x] Architecture documents in scope describe the system as built

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/agent-sandbox.sh`](scripts/agent-sandbox.sh) | `--target` flag for build; `stop` subcommand added |
| [`libs/_templates/Makefile.template`](libs/_templates/Makefile.template) | `TARGET=` variable; `stop` target added |
| [`providers/hermes/Dockerfile`](providers/hermes/Dockerfile) | pip→uv; plain git clone; `ENTRYPOINT ["hermes"]` |
| [`providers/hermes/run.sh`](providers/hermes/run.sh) | `chat` injected for standard mode; serve log messages updated |
| [`providers/hermes/docker-compose.serve.yml`](providers/hermes/docker-compose.serve.yml) | `command: ["api"]`; Open WebUI connected via `OPENAI_API_BASE_URL` |
| [`docs/architecture/tool_interface.md`](docs/architecture/tool_interface.md) | Build command shapes updated to `TARGET=` |
| [`docs/architecture/execution_model.md`](docs/architecture/execution_model.md) | Provider interface section updated to `TARGET=` |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| `make build` uses `--target=` not `--provider=` for build target selection | `TARGET` reflects what is being built; `PROVIDER` is for run-time provider selection | `Makefile.template`, `agent-sandbox.sh` |
| `--target=` (empty value) is an error; absent `--target` and `--target=all` both build everything; Makefile always emits `--target=all` if unset | Eliminates silent fallback; makes intent explicit | `agent-sandbox.sh` |
| Hermes Dockerfile uses `uv` for Python deps; plain `git clone` (no submodules) | mini-swe-agent removed in hermes-agent#2804; uv aligns with official install script | `providers/hermes/Dockerfile` |
| `ENTRYPOINT ["hermes"]` with no CMD; subcommand injected by `run.sh` per mode | Consistent with OpenCode pattern; keeps Dockerfile minimal; mode dispatch explicit in run.sh | `providers/hermes/Dockerfile`, `run.sh` |
| Open WebUI connects to Hermes via `OPENAI_API_BASE_URL=http://agent:8642/v1` on internal compose network; port 8642 not exposed to host | Internal network sufficient for Open WebUI↔Hermes; no host exposure needed | `providers/hermes/docker-compose.serve.yml` |
| `make stop` dispatches to `agent-sandbox stop` → `scripts/stop.sh` (not yet implemented); uses Option B2: `docker ps --filter` by compose project name | Avoids `--provider` requirement at stop time; no compose file variable resolution needed | This handover |
| `make stop` deferred — blocked by compose template placeholder issue | See deferred items | This handover |

## Completed this session

| File | Change |
|---|---|
| `scripts/agent-sandbox.sh` | `--target` flag for build with error handling; `stop` subcommand stub (sources `.env`, dispatches to compose down — superseded by B2 approach next session) |
| `libs/_templates/Makefile.template` | `TARGET=` variable; `TARGET_FLAG` always emits `--target=all` if unset; `stop` target added |
| `providers/hermes/Dockerfile` | `uv` for Python; plain `git clone`; `ENTRYPOINT ["hermes"]`; mini-swe-agent and tinker-atropos removed |
| `providers/hermes/run.sh` | `chat` injected for standard mode; serve log messages updated |
| `providers/hermes/docker-compose.serve.yml` | `command: ["api"]`; agent port 8642 internal only; Open WebUI `OPENAI_API_BASE_URL` wired to agent service |
| `docs/architecture/tool_interface.md` | Build command shapes: `PROVIDER=` → `TARGET=` |
| `docs/architecture/execution_model.md` | Provider interface: `make build PROVIDER=<n>` → `make build TARGET=<n>` |

## Deferred items

**`make stop` — blocked, two issues to resolve together:**

1. `docker-compose.yml` in `SANDBOX_DIR` contains unresolved template placeholders (`${SANDBOX_IMAGE_NAME}`, `${AGENT_IMAGE_NAME}`, etc.) rather than baked values. Docker Compose validates all variable references before running any command including `down`, so stop fails when these vars are absent from the environment. Root cause: the compose template generation mechanism needs investigation — why are placeholders not resolved at onboard/run time?

2. `stop` needs to work without `--provider` — the agent container name requires `PROVIDER_NAME` which is only known at run time and not stored in `.env`. Solution agreed: Option B2 — use `docker ps --filter label=com.docker.compose.project=<project>` to find and stop all containers by compose project name, derived from `SANDBOX_DIR` alone. Implement in `scripts/stop.sh`; dispatch from `agent-sandbox stop`.

Both issues are related and should be resolved in the same session. Start with the compose placeholder issue — understanding why `docker-compose.yml` still contains `${...}` placeholders will inform whether `stop.sh` needs to source `.env` at all.

**Hermes serve mode model configuration** — `HERMES_HOME/.hermes/.env` inside the container needs provider credentials (e.g. `OPENROUTER_API_KEY`) to show models in Open WebUI. Currently ephemeral — no credentials threaded through from host `.env` to container. Needs: (1) variables added to `providers/hermes/.env.example`; (2) serve overlay injects them into agent environment. Defer to dedicated session.

**Second provider addition criterion** — deferred to when a new provider is actually added. Hermes itself was the refactor that made the criterion achievable; the criterion is structurally met but not empirically proven by a third provider.

## Next session

**M2.2 close + M2.3 prep — or dedicated `make stop` / compose template fix session.**

Priority order:
1. Investigate why `docker-compose.yml` in `SANDBOX_DIR` still contains `${...}` placeholders — expected to be baked at onboard or run time. Upload `scripts/start_agent.sh` and `scripts/onboard.sh` to diagnose.
2. Implement `scripts/stop.sh` using Option B2 (compose project filter) once root cause is understood.
3. If stop is resolved and all criteria met: run Trigger B for M2.2.
4. Hermes model config (`.env` passthrough) — separate session after M2.2 closes.

**Watch-out items:**
1. `docker-compose.yml` placeholder issue may reveal that the compose file is meant to be regenerated each run by `start_agent.sh` — in which case `stop.sh` should not depend on it at all and Option B2 is the right path regardless.
2. Trigger B cannot fire until `make stop` acceptance criterion is resolved or explicitly dropped from M2.2 scope.
3. Architecture docs are current as of this session — no further doc updates needed before Trigger B.
