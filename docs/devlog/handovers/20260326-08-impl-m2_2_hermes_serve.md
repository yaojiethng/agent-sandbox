# Agent Handover

**Session date:** 2026-03-26
**Milestone:** M2.2 — Reasoning Layer Modularisation
**Session type:** Implementation

## Objective

Complete the Open WebUI ↔ Hermes serve mode connection: persist Hermes config across container runs, inject provider credentials, and validate end-to-end Open WebUI ↔ Hermes API connection in serve mode.

## Scope

Single task group: Open WebUI ↔ Hermes serve mode connection (deferred breakdown item from M2.2 roadmap).

Deferred (explicitly out of scope this session): Claude Desktop provider integration, Pi provider integration.

## Acceptance criteria

Carried from prior sessions (open):
- [ ] Open WebUI ↔ Hermes API connection confirmed in serve mode
- [ ] A second provider can be added with no changes to `scripts/` or `libs/` — confirmed structurally; proven empirically when a third provider is added

## Hot files

| File | Why in scope |
|---|---|
| [`providers/hermes/run.sh`](providers/hermes/run.sh) | Compose generation moving here; pre-run hooks (HERMES_HOME, file seeding) |
| [`providers/hermes/docker-compose.hermes.yml`](providers/hermes/docker-compose.hermes.yml) | New — provider-level overlay; HERMES_HOME env var, config.yaml and .env file mounts |
| [`providers/hermes/docker-compose.serve.yml`](providers/hermes/docker-compose.serve.yml) | Credential env var injection into agent service |
| [`providers/hermes/Dockerfile`](providers/hermes/Dockerfile) | ENTRYPOINT changed to `["bash", "-c"]` |
| [`providers/hermes/.env.example`](providers/hermes/.env.example) | Document provider credential variables |
| [`scripts/start_agent.sh`](scripts/start_agent.sh) | Compose generation removed; passes env file path to run.sh |
| [`libs/compose.sh`](libs/compose.sh) | No changes expected; `compose_generate` signature unchanged |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| `ENTRYPOINT ["bash", "-c"]` in Hermes Dockerfile; command injected via `run.sh` | `hermes chat` exits immediately after setup; operator needs to drop to bash after config runs. Serve mode uses `hermes api` which blocks. Both handled cleanly via command injection. | `providers/hermes/Dockerfile` |
| `HERMES_HOME` file-level mounts for `config.yaml` and `.env` only | Entire directory mount caused `shutil.move` cross-device failures — Hermes installs `tirith` binary by moving from `/tmp` to `HERMES_HOME/bin/`, which fails across filesystem boundaries on Windows-mounted paths. File-level mounts of `config.yaml` and `.env` only avoids the binary install path. `bin/`, `sessions/`, `cron/` remain inside the container's own filesystem. | `providers/hermes/docker-compose.hermes.yml` |
| `config.yaml` seeded from `providers/hermes/config.yaml` on first run | Hermes config baked into image layer is shadowed by file bind mount. Seeding from a repo-tracked template preserves `terminal.backend: local` and any pre-configuration without requiring a rebuild. Guard: only copy if file does not already exist on host. | `providers/hermes/run.sh` |
| Compose generation moved from `start_agent.sh` to `run.sh` | Provider-specific vars (`HERMES_HOME`, `HERMES_CONFIG_FILE`, `HERMES_ENV_FILE`) must exist before compose generation. These vars belong in `run.sh`. Original rationale for `start_agent.sh` placement (mode-awareness) doesn't hold — `run.sh` receives mode as first positional argument. Tmpfile ownership and cleanup also simplifies — no implicit cross-script trap coupling. `start_agent.sh` becomes genuinely provider-agnostic. | `scripts/start_agent.sh`, `providers/hermes/run.sh` |
| Provider-level compose overlay (`docker-compose.hermes.yml`) introduced | Hermes requires mounts and env vars in all modes, not just serve. Merged before the mode overlay. Optional by convention — providers without one simply omit the file. | `providers/hermes/docker-compose.hermes.yml`, `providers/hermes/run.sh` |

## Completed this session

| File | Change |
|---|---|
| `scripts/run_agent.sh` | New — owns full provider lifecycle: setup hook, compose assembly, generation, teardown, sandbox wait, dispatch |
| `scripts/start_agent.sh` | Compose generation removed; dispatches to `run_agent.sh` with `--env` and `--provider` |
| `providers/hermes/setup.sh` | New — exports `HERMES_CONFIG_FILE`, `HERMES_ENV_FILE`; pre-creates host dirs and seeds config on first run |
| `providers/hermes/docker-compose.hermes.yml` | Bug comment removed; `${HERMES_CONFIG_FILE}` and `${HERMES_ENV_FILE}` now resolved correctly via setup.sh export order |
| `providers/hermes/docker-compose.serve.yml` | `command: ["hermes", "api"]` added; standard command injected via `run_agent.sh` |
| `providers/hermes/Dockerfile` | `ENTRYPOINT ["bash", "-c"]`; comment updated |
| `providers/opencode/run.sh` | Deleted — lifecycle now owned by `run_agent.sh` |
| `providers/hermes/run.sh` | Deleted — lifecycle now owned by `run_agent.sh` |
| `docs/operations/provider_onboarding_guide.md` | `run.sh` removed from file list; `setup.sh` and provider overlay added as optional; libs/scripts separation documented; Steps renumbered |

## Deferred items

None.

## Next session

M2.2 — Reasoning Layer Modularisation (validate refactor, then Hermes serve end-to-end).

Trigger B has not run. Two acceptance criteria remain open; Claude Desktop and Pi remain deferred.

Blocking items for next session:
1. Run `make dry-run PROVIDER=opencode` and `make dry-run PROVIDER=hermes` — confirm both pass after refactor.
2. Run `make serve PROVIDER=hermes` — confirm Open WebUI connects to Hermes API without operator intervention.
3. `tool_interface.md` Provider Interface section still lists `run.sh` as a required provider file — needs updating to match `provider_onboarding_guide.md`.
