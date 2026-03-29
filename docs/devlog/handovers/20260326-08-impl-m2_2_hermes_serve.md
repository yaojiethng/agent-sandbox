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
| [`docs/architecture/tool_interface.md`](docs/architecture/tool_interface.md) | Provider Interface table updated |
| [`docs/architecture/sandbox_lifecycle.md`](docs/architecture/sandbox_lifecycle.md) | Four phases; provider config pipeline |
| [`docs/architecture/container_model.md`](docs/architecture/container_model.md) | run_agent.sh ownership; copy-in/out sequence |
| [`docs/architecture/execution_model.md`](docs/architecture/execution_model.md) | start_agent/run_agent split; directory layout |
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
| `docs/architecture/tool_interface.md` | Provider Interface table updated — `run.sh` removed; optional files (`setup.sh`, provider overlay) added; Capability Layer Contract header updated |
| `docs/architecture/sandbox_lifecycle.md` | Four phases (Seed, Fork, Work, Join); provider config pipeline documented; copy-out noted as not yet implemented; session state flagged as future concern |
| `docs/architecture/container_model.md` | Compose generation ownership updated to `run_agent.sh`; provider overlay in mode composition table; "Why provider config is not mounted" rationale added; start/stop sequences updated |
| `docs/architecture/execution_model.md` | Invocation model split into `start_agent.sh` and `run_agent.sh`; directory layout updated; sandbox lifecycle description updated to four phases |

## Deferred items

| Item | Reason | Where next |
|---|---|---|
| `container_model.md` / `sandbox_lifecycle.md` structural overlap | The container lifecycle start/stop sequence in `container_model.md` partially duplicates the phase structure in `sandbox_lifecycle.md` — both describe the same session events, one in Docker terms and one in data-flow terms. A cross-cutting change (like copy-in/copy-out) touches both documents because sequencing lives in two places. The fix is to collapse the container lifecycle steps in `container_model.md` into references to the lifecycle phases in `sandbox_lifecycle.md`, making `container_model.md` purely about Docker mechanics (volumes, mounts, compose generation) and `sandbox_lifecycle.md` the single owner of all session sequencing. This is a doc cleanup pass, not an architecture change — the current split is functional, just friction-inducing for lifecycle changes. | Future doc cleanup pass |
| Session state persistence | Agents produce session logs, chat logs, and tool call logs that are currently ephemeral — lost on container teardown. A future milestone should define a session state persistence model using the same copy-out mechanism as provider config: provider declares tracked paths (e.g. a session database file or compressed log directory), harness copies them out after the agent exits. Exact files vary by provider and are a future provider integration concern. | Future milestone (post-M2) |

## Next session

M2.2 — Reasoning Layer Modularisation (validate Hermes, implement copy-in).

Trigger B has not run. Two acceptance criteria remain open; Claude Desktop and Pi remain deferred.

Blocking items for next session:

1. **Implement provider config copy-in.** The architecture documents describe copy-in as the mechanism for seeding provider config files into the container, but it is not yet implemented in `scripts/run_agent.sh`. The required change is: after `compose_sandbox_wait` and before the agent attaches, source `providers/<n>/copy_in.sh` if the file exists. `copy_in.sh` is a new optional provider file (alongside `setup.sh`) that uses `docker compose cp` to copy tracked files from `SANDBOX_DIR` into the container. For Hermes, this means copying `$OUTPUT_DIR/.hermes/config.yaml` and `$OUTPUT_DIR/.hermes/.env` into `/home/agentuser/.hermes/` inside the agent container. The existing bind mounts for these files in `docker-compose.hermes.yml` should be removed once copy-in is working — the two mechanisms are redundant and copy-in is the correct one. `provider_onboarding_guide.md` and `tool_interface.md` will need a follow-up update to document `copy_in.sh` as an optional provider file alongside `setup.sh`.

2. **Run `make dry-run PROVIDER=hermes`** — confirm it passes after the `run_agent.sh` refactor. OpenCode dry-run already passes.

3. **Run `make serve PROVIDER=hermes`** — confirm Open WebUI connects to the Hermes API without operator intervention. This is the outstanding acceptance criterion.

4. **Define base Dockerfiles for Hermes and OpenCode.** Both provider Dockerfiles currently install all dependencies (system packages, runtimes, agent source) in a single image, making iterative builds slow. Define a `Dockerfile.base` per provider that contains the slow, stable install layers (apt packages, uv/node, agent source clone and install, Playwright binaries). The provider `Dockerfile` then inherits from this base via `FROM <provider>-base-<project>`. Base images are rebuilt rarely (only when dependencies change); the provider image layer above them rebuilds quickly. `build.sh` for each provider needs updating to build the base image first if it does not exist or if `--no-cache` is passed.

5. **Implement provider config copy-out (if time allows).** Symmetric to copy-in: after the agent exits and before `docker compose down -v`, source `providers/<n>/copy_out.sh` if it exists. For Hermes, this copies `config.yaml` and `.env` back from the container to `SANDBOX_DIR`. Copy-out is noted as not yet implemented in the architecture docs — if implemented this session, remove that note from `sandbox_lifecycle.md` and `container_model.md`.
