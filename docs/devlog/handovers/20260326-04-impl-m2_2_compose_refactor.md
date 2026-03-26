# Agent Handover

**Session date:** 2026-03-26
**Milestone:** M2.2 — Reasoning Layer Modularisation
**Session type:** Implementation

## Objective

Close M2.2: resolve `make stop` project naming bug, extract shared compose primitives, eliminate harness-managed files from `SANDBOX_DIR`, and clean up onboarding outputs.

## Scope

- `make stop` project name fix (label filter using `--name`)
- `libs/compose.sh` extraction — `compose_generate`, `compose_args`, `compose_dry_run`, `compose_teardown`, `compose_sandbox_wait`
- Compose generation refactor — single merged tmpfile per run, never written to `SANDBOX_DIR`
- `run.sh` thinning — receives `--compose-file`, drives harness functions directly
- `onboard.sh` cleanup — removed `docker-compose.yml`, `Dockerfile.sandbox`, version tracking for both
- `build_sandbox.sh` cleanup — removed `check_template_version`
- `execution_model.md` update

## Acceptance criteria

- [x] `make stop` finds and stops containers by correct compose project label
- [x] `make serve PROVIDER=opencode` starts cleanly — compose file generated as tmpfile, no files written to `SANDBOX_DIR`
- [x] `make serve PROVIDER=hermes` starts cleanly
- [x] `make dry-run PROVIDER=opencode` passes
- [x] `make dry-run PROVIDER=hermes` passes
- [x] `agent-sandbox onboard` on a fresh directory does not produce `docker-compose.yml` or `Dockerfile.sandbox` in `SANDBOX_DIR`
- [x] Architecture documents in scope describe the system as built
- [ ] Claude Desktop provider integration complete
- [ ] Pi provider integration complete
- [ ] Open WebUI ↔ Hermes API connection confirmed in serve mode

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/stop.sh`](scripts/stop.sh) | New — label-filter stop |
| [`scripts/agent-sandbox.sh`](scripts/agent-sandbox.sh) | `stop)` case updated |
| [`libs/_templates/Makefile.template`](libs/_templates/Makefile.template) | `stop` passes `--name` |
| [`libs/compose.sh`](libs/compose.sh) | New — shared compose primitives |
| [`libs/docker-compose.yml`](libs/docker-compose.yml) | Renamed from `_templates/`; `{{VAR}}` baked values; explicit bind syntax |
| [`libs/docker-compose.dry-run.yml`](libs/docker-compose.dry-run.yml) | Moved from `_templates/`; explicit bind syntax |
| [`scripts/start_agent.sh`](scripts/start_agent.sh) | Compose generation block; `--compose-file` passthrough |
| [`providers/opencode/run.sh`](providers/opencode/run.sh) | Receives `--compose-file`; harness function calls; tmpfile cleanup |
| [`providers/hermes/run.sh`](providers/hermes/run.sh) | Same |
| [`scripts/onboard.sh`](scripts/onboard.sh) | Removed compose/Dockerfile generation and version tracking |
| [`scripts/build_sandbox.sh`](scripts/build_sandbox.sh) | Removed `check_template_version` |
| [`docs/architecture/execution_model.md`](docs/architecture/execution_model.md) | Directory layout; container lifecycle step 3 |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| `make stop` derives compose project name from `--name` (PROJECT_NAME), not SANDBOX_DIR basename | SANDBOX_DIR basename is deployment-specific; PROJECT_NAME is the stable harness identity | `stop.sh`, `agent-sandbox.sh`, `Makefile.template` |
| Compose file generated as tmpfile, never written to SANDBOX_DIR | Eliminates operator-visible harness artefacts; single source of truth in repo templates | `start_agent.sh`, `compose.sh` |
| `compose_generate` merges via `docker compose config --no-interpolate`; bakes image names and host paths; preserves operator secrets as `${VAR}` | Produces a single debuggable file; Compose runtime resolves only secrets it needs | `compose.sh` |
| Explicit `type: bind` in all volume mounts | `docker compose config` misclassifies `${VAR}` sources as named volumes in short syntax | `docker-compose.yml`, `docker-compose.dry-run.yml` |
| Host path variables baked at generation time, not runtime | `docker compose config --no-interpolate` relativises unresolved paths against staging dir | `compose.sh` |
| `run.sh` remains executor (not config); receives `--compose-file`; drives `docker compose` calls directly | Preserves provider-specific handling and unsupported-mode hooks; eliminates file resolution duplication | `providers/*/run.sh` |
| `Dockerfile.sandbox` already repo-owned (`libs/sandbox.Dockerfile`); removed from onboard outputs | `build_sandbox.sh` already reads from repo; operator copy was stale risk with no benefit | `onboard.sh`, `build_sandbox.sh` |
| `docker-compose.dry-run.yml` moved to `libs/` as static harness file | Never operator-visible; same content for all providers | `libs/docker-compose.dry-run.yml` |

## Completed this session

| File | Change |
|---|---|
| `scripts/stop.sh` | New — derives compose project from `--name`; filters containers by label; removes volumes |
| `scripts/agent-sandbox.sh` | `stop)` dispatches to `stop.sh` with `--name` and `--sandbox` |
| `libs/_templates/Makefile.template` | `stop` target passes `--name=$(PROJECT_NAME)` |
| `libs/compose.sh` | New — `compose_generate` (merge + bake + preserve), `compose_args`, `compose_dry_run`, `compose_teardown`, `compose_sandbox_wait` |
| `libs/docker-compose.yml` | Renamed from `_templates/docker-compose.yml.template`; `{{VAR}}` for image names; explicit bind syntax for all volumes |
| `libs/docker-compose.dry-run.yml` | Moved from `_templates/docker-compose.dry-run.yml.template`; explicit bind syntax; `{{DRY_RUN_SCRIPT}}` baked |
| `scripts/start_agent.sh` | Replaced ad-hoc compose generation with `compose_generate`; mode-aware file list; passes `--compose-file` to `run.sh` |
| `providers/opencode/run.sh` | Receives `--compose-file`; calls `compose_args`/`compose_dry_run`/`compose_teardown`/`compose_sandbox_wait`; tmpfile cleanup trap |
| `providers/hermes/run.sh` | Same |
| `scripts/onboard.sh` | Removed: `docker-compose.yml` generation, `Dockerfile.sandbox` copy, `COMPOSE_VERSION`, `DOCKERFILE_SANDBOX_VERSION`, both from `REQUIRED_TEMPLATES` and `.env`; updated usage/summary strings |
| `scripts/build_sandbox.sh` | Removed `check_template_version` call, comment block, `TEMPLATES` variable; `build_context.sh` source relocated |
| `docs/architecture/execution_model.md` | `Dockerfile.sandbox` removed from SANDBOX_DIR tree; container lifecycle step 3 split to reflect `start_agent.sh` generates compose, `run.sh` assembles overlays |

**Deleted files:**
- `libs/_templates/docker-compose.yml.template` — replaced by `libs/docker-compose.yml`
- `libs/_templates/docker-compose.dry-run.yml.template` — replaced by `libs/docker-compose.dry-run.yml`

## Deferred items

**Hermes serve mode model configuration** — `HERMES_HOME/.hermes/.env` inside the container needs provider credentials (e.g. `OPENROUTER_API_KEY`) to show models in Open WebUI. Needs: (1) variables added to `providers/hermes/.env.example`; (2) serve overlay injects them into agent environment. Defer to dedicated session after M2.2 closes.

**Second provider addition criterion** — structurally met by the refactor; not empirically proven by a third provider. Revisit when a new provider is added.

**`make serve PROVIDER=hermes` and `make dry-run PROVIDER=hermes` final validation** — not confirmed by operator this session. Required before Trigger B.

## Next session

**M2.2 — Reasoning Layer Modularisation** (continuing — provider integrations and docs audit).

Trigger B has not run. Remaining open items:
- Claude Desktop provider integration
- Pi provider integration  
- Open WebUI ↔ Hermes API connection in serve mode

Docs audit task (schedule for next session):
- Review design decisions in roadmap M2.2 section — move decisions with architectural significance to the relevant `docs/architecture/` documents, compact the rest to a brief rationale note or remove entirely
- Review Known Limitations in roadmap and consolidate by functionality, clear redundant points
- Final pass: confirm no architecture document contradicts the system as built after this session's changes

Watch-out items:
1. Delete `libs/_templates/docker-compose.yml.template` and `libs/_templates/docker-compose.dry-run.yml.template` from disk — superseded, will cause confusion if left.
2. Patch existing sandbox `Makefile` `stop` target to add `--name=$(PROJECT_NAME)`, or run `agent-sandbox onboard --refresh`.
