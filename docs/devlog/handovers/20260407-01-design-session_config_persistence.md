# Agent Handover

**Session date:** 2026-04-07
**Milestone:** M2.4 — Session and Config Persistence
**Session type:** Design + Implementation (partial)

## Objective

Redesign the provider config lifecycle — seed-in and persist-out — replacing the implicit `config/` image-baking convention with an explicit onboarding-time population model. Produce implementation artifacts and updated documentation.

## Scope

Design settled. All implementation artifacts applied to repo except two `compose.sh` bug fixes. `run_agent.sh` dead code removal produced this session and ready to apply.

Claude Desktop provider integration: cancelled.

## Acceptance criteria
Not yet defined.

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| M2.4 reordered before M2.3 | Config seeding bugs affect every provider now; cleaner foundation | roadmap.md |
| M2.4 renamed to "Session and Config Persistence" | "Session Persistence" undersold the scope | roadmap.md |
| Claude Desktop provider integration cancelled | Operator decision | roadmap.md |
| No manifest — copy-everything model | Simpler first; manifest deferred if copy-out scope becomes a problem | provider_lifecycle.md |
| `providers/<n>/config/` is onboarding template only | Never baked into image; `agent-sandbox onboard` copies to `$SANDBOX_DIR/.<n>/` | provider_lifecycle.md, tool_interface.md |
| `env.stub → .env` rename happens at onboard time | Runtime entrypoint never sees `env.stub` | onboard.sh, provider_lifecycle.md |
| `/opt/provider-config/` as bind mount intermediary | Agent needs full ownership of `AGENT_HOME`; direct mount fails on Windows | execution_model.md |
| `mkdir -p $SANDBOX_DIR/.<provider>/` is harness responsibility | Belongs in `run_agent.sh`, not provider `setup.sh` | run_agent.sh |
| `container_model.md` collapsed into `execution_model.md` | Significant overlap; execution_model was a weak index document | execution_model.md |
| `sandbox_lifecycle.md` owns fork/work/join only | Single responsibility — provider lifecycle split to new doc | sandbox_lifecycle.md, provider_lifecycle.md |
| Mermaid diagram replaces prose lifecycle sections | More readable; lives in markdown as code block | execution_model.md |

## Completed this session

| File | Change |
|---|---|
| `libs/provider-entrypoint.sh` | Rewritten — copy-in from `/opt/provider-config/`, copy-out EXIT trap |
| `libs/containers.sh` | `build_context_agent` stripped of `config/` copy |
| `scripts/onboard.sh` | Provider config seeding block added; `env.stub → .env` rename |
| `providers/hermes/setup.sh` | Reduced — `mkdir -p` removed (moved to harness) |
| `providers/*/provider.Dockerfile` | `COPY config/` removed; `/opt/provider-config` added to `RUN mkdir -p` |
| `libs/docker-compose.yml` | `/opt/provider-config/` bind mount added; `{{PROVIDER_NAME}}` placeholder added |
| `scripts/run_agent.sh` | Dead code removed (`_provider_persist`, `PROVIDER_CONFIG_OUT`, `PROVIDER_CONFIG_HOST`); comment updated |
| `docs/architecture/execution_model.md` | Full rewrite — absorbs container_model, mermaid diagram, compose substitution model |
| `docs/architecture/sandbox_lifecycle.md` | Trimmed to fork/work/join |
| `docs/architecture/provider_lifecycle.md` | New document |
| `docs/architecture/tool_interface.md` | Command Reference (operator-facing); mount shape updated; Provider Interface updated |
| `docs/operations/provider_onboarding_guide.md` | `config/` purpose rewritten; Dockerfile template updated |
| `docs/architecture/container_model.md` | Deleted; links in `system_overview.md` and `two_layer_model.md` updated |
| `libs/compose.sh` | add `-e "s|{{PROVIDER_NAME}}|\${provider_name}|g"` and `-e "s|\${SANDBOX_DIR}|${SANDBOX_DIR:-}|g"` to `compose_generate` sed block |


## Next session

M2.4 — Session and Config Persistence, close-out.

Validate copy-out workflow for session and config, define acceptance criteria and close M2.4 once dry-runs pass.
