# Agent Handover

**Session date:** 2026-03-29
**Milestone:** M2.2 — Reasoning Layer Modularisation
**Session type:** Implementation

## Objective

Implement provider config copy-in and copy-out so that provider configuration files are seeded into the container at session start and retrieved back to `SANDBOX_DIR` at session end. Also ported Hermes base image improvements from upstream reference PR.

## Scope

Copy-in/copy-out implementation, Hermes base image rebuild optimisations, and architecture/operations doc updates. All items from prior session's Next session blockers addressed.

## Acceptance criteria

Carried from prior sessions (open):
- [ ] A second provider can be added with no changes to `scripts/` or `libs/` — confirmed structurally; proven empirically when a third provider is added

New this session — all accepted:
- [x] On `make start PROVIDER=hermes`, Hermes config files present in `AGENT_HOME` before agent command runs
- [x] After agent exits, `$SANDBOX_DIR/.hermes/` contains the session's final config state
- [x] `providers/hermes/docker-compose.hermes.yml` has no bind mounts for Hermes config files
- [x] `make start PROVIDER=opencode` functions correctly with new entrypoint wrapper
- [x] `make dry-run PROVIDER=hermes` passes (copy-in/copy-out not invoked in dry-run — no regression)

## Hot files

| File | Why in scope |
|---|---|
| `libs/provider-entrypoint.sh` | New — harness-owned wrapper; seeds config, registers copy-out EXIT trap, execs agent |
| `libs/containers.sh` | `build_context_agent` updated — provider arg, injects `provider-entrypoint.sh` and `config/` |
| `scripts/run_agent.sh` | `_provider_persist` move added post-exit; copy-in/copy-out functions removed |
| `providers/hermes/provider.Dockerfile` | COPY entrypoint + config; ENV AGENT_HOME + PROVIDER_NAME; image-layer config seed removed |
| `providers/opencode/provider.Dockerfile` | Same pattern as Hermes |
| `providers/hermes/base.Dockerfile` | Multi-stage build; optimised base image |
| `providers/hermes/config/config.yaml` | New — operator-populated default config |
| `providers/hermes/config/env.stub` | New — seeded as `.env`; operator-populated |
| `providers/opencode/config/env.stub` | New — seeded as `.env`; operator-populated |
| `providers/hermes/docker-compose.hermes.yml` | Bind mounts for config files removed |
| `docs/architecture/sandbox_lifecycle.md` | Phases 1 and 4 rewritten — copy-in/copy-out as implemented |
| `docs/architecture/tool_interface.md` | Provider Interface table updated |
| `docs/operations/provider_onboarding_guide.md` | New provider contract documented; Step 6 added for `config/` |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| Copy-in handled inside container by `provider-entrypoint.sh` | Eliminates race condition — config present before agent command runs | `sandbox_lifecycle.md`, `provider-entrypoint.sh` |
| Seed-if-missing per file (NousResearch reference pattern) | User edits survive; new seed files don't overwrite existing ones | `provider-entrypoint.sh` |
| `providers/<n>/config/` baked into image via build context | No runtime mount needed for first-run seed; provider author places files in one location | `containers.sh`, both Dockerfiles |
| `env.stub` naming for `.env` seed file | Avoids `.gitignore` match; seeded as `.env` inside container | `provider-entrypoint.sh` |
| Copy-out via EXIT trap in `provider-entrypoint.sh` | Fires on all exits including `docker stop`; no harness polling needed | `provider-entrypoint.sh` |
| `_provider_persist` move in `run_agent.sh` post-exit | Keeps copy-out target and canonical config location separate | `run_agent.sh` |
| `docker wait` in serve mode before persist and teardown | Ensures EXIT trap has fired before move | `run_agent.sh` |
| Multi-stage build for `hermes/base.Dockerfile` | Build tools excluded from runtime image; meaningful size and attack surface reduction | `hermes/base.Dockerfile` |
| `python:3.11-slim` base replaces `debian:bookworm` | Pinned Python version; smaller base | `hermes/base.Dockerfile` |
| Node.js 20 via NodeSource replaces apt default | Current LTS; explicit version pin vs whatever apt ships | `hermes/base.Dockerfile` |
| `uv` used exclusively; Playwright removed | Faster, consistent dependency management; ~2GB image size reduction | `hermes/base.Dockerfile` |
| `agent-base` image type deferred | Common dependency list not yet stable; reference note added to roadmap | roadmap.md |

## Completed this session

| File | Change |
|---|---|
| `libs/provider-entrypoint.sh` | New |
| `libs/containers.sh` | `build_context_agent` — provider arg, entrypoint + config injection |
| `scripts/run_agent.sh` | `_provider_persist` added; copy-in/copy-out removed; standard mode `run --rm` retained |
| `providers/hermes/provider.Dockerfile` | Rewritten — entrypoint wrapper, ENV vars, config COPY, image-layer seed removed |
| `providers/opencode/provider.Dockerfile` | Rewritten — same pattern |
| `providers/hermes/base.Dockerfile` | Rewritten — multi-stage, `python:3.11-slim`, Node 20, uv exclusively, Playwright removed |
| `providers/hermes/config/config.yaml` | New (operator-populated) |
| `providers/hermes/config/env.stub` | New (operator-populated) |
| `providers/opencode/config/env.stub` | New (operator-populated) |
| `providers/hermes/docker-compose.hermes.yml` | Bind mounts removed |
| `docs/architecture/sandbox_lifecycle.md` | Phases 1 and 4 rewritten |
| `docs/architecture/tool_interface.md` | Provider Interface table updated |
| `docs/operations/provider_onboarding_guide.md` | New provider contract; Step 6 added; steps renumbered |

## Deferred items

| Item | Reason | Where next |
|---|---|---|
| `container_model.md` / `sandbox_lifecycle.md` structural overlap | Carried from prior sessions | Future doc cleanup pass |
| Session state persistence | Carried from prior sessions | Future milestone (post-M2) |
| Claude Desktop provider integration | Explicitly out of scope | Future M2.2 session |
| Pi provider integration | Explicitly out of scope | Future M2.2 session |
| `agent-base` image type | Common dependency list not yet stable | Future milestone — reference `hermes/base.Dockerfile` for patterns |

## Next session

M2.2 — Reasoning Layer Modularisation.

Trigger B has not run. One acceptance criterion remains open (third provider empirical proof of no `scripts/`/`libs/` changes required).

Remaining work is provider integrations (Claude Desktop, Pi) or moving to M2.3. Confirm with operator which to prioritise.

Watch-out: `uv` is installed as root in `hermes/base.Dockerfile` and lands at `/root/.local/bin`. Once `provider.Dockerfile` switches to `agentuser`, verify `uv` remains on PATH — may need `/root/.local/bin` added explicitly or uv reinstalled for agentuser.
