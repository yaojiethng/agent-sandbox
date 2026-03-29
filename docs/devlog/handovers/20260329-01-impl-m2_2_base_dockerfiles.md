# Agent Handover

**Session date:** 2026-03-29
**Milestone:** M2.2 — Reasoning Layer Modularisation
**Session type:** Implementation

## Objective

Define base Dockerfiles for Hermes and OpenCode so that slow install layers (apt packages, runtimes, agent source) are separated from the fast-changing provider layer, reducing iterative build times.

## Scope

Point 4 from the prior session's Next session blockers. Expanded during session to cover the full build system refactor.

## Acceptance criteria

Carried from prior sessions (open):
- [x] Open WebUI ↔ Hermes API connection confirmed in serve mode
- [ ] A second provider can be added with no changes to `scripts/` or `libs/` — confirmed structurally; proven empirically when a third provider is added

New this session:
- [x] `make build PROVIDER=opencode` succeeds, building base image then provider image in sequence
- [x] `make build PROVIDER=hermes` succeeds, building base image then provider image in sequence
- [x] `make dry-run PROVIDER=opencode` passes after Dockerfile split
- [x] `make dry-run PROVIDER=hermes` passes after Dockerfile split
- [x] Open WebUI ↔ Hermes API connection confirmed in serve mode

## Hot files

| File | Why in scope |
|---|---|
| `providers/opencode/base.Dockerfile` | New — stable install layers for OpenCode |
| `providers/opencode/provider.Dockerfile` | New — provider layer inheriting from opencode-base |
| `providers/hermes/base.Dockerfile` | New — stable install layers for Hermes |
| `providers/hermes/provider.Dockerfile` | New — provider layer inheriting from hermes-base |
| `providers/opencode/Dockerfile` | Deleted — replaced by base/provider split |
| `providers/hermes/Dockerfile` | Deleted — replaced by base/provider split |
| `providers/opencode/build.sh` | Deleted — replaced by build_container.sh |
| `providers/hermes/build.sh` | Deleted — replaced by build_container.sh |
| `scripts/build_container.sh` | New — unified build script for all image types |
| `scripts/build_sandbox.sh` | Deleted — replaced by build_container.sh |
| `libs/containers.sh` | Added agent_base_image_name, build_context_sandbox, build_context_agent, build_image; build_agent/build_sandbox delegate to build_container.sh |
| `libs/build_context.sh` | Deleted — absorbed into containers.sh |
| `libs/agent-sandbox.sh` | Provider discovery glob updated; REBUILD_BASE flag added |
| `Makefile.template` | REBUILD_BASE variable and flag added |
| `docs/architecture/tool_interface.md` | Image naming table updated; Provider Interface table updated |
| `docs/operations/provider_onboarding_guide.md` | Steps 2/3 rewritten for base/provider split; build.sh step removed |
| `providers/hermes/quickstart.md` | New — day-to-day commands and serve mode troubleshooting |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| Base image named `<provider>-base` (no project suffix) | Base contains no project-specific content; project suffix would be misleading | `tool_interface.md`, `containers.sh` |
| `base.Dockerfile` / `provider.Dockerfile` filenames | `Dockerfile` treated as extension, consistent naming | All provider Dockerfiles |
| `useradd` in `provider.Dockerfile`, not base | User identity is a runtime interface concern, not a dependency install concern | `provider.Dockerfile` comments |
| `npm install -g` as root; `NPM_CONFIG_PREFIX` removed | Root install writes to `/usr/local` which is already on PATH; prefix redirect was only needed for non-root installs | `opencode/base.Dockerfile` |
| `build_container.sh` replaces all per-provider `build.sh` and `build_sandbox.sh` | Eliminates duplication; no provider-level branches or hardcodes; providers discovered by `providers/*/base.Dockerfile` glob | `build_container.sh`, `agent-sandbox.sh` |
| `build_context` absorbed into `containers.sh` | Single library file; `build_context.sh` had no callers remaining after build.sh deletion | `containers.sh` |
| Base skipped if exists; `--rebuild-base` forces full rebuild with `--no-cache` | Base is slow to build; skip by default; explicit flag for when dependencies change | `build_container.sh`, `Makefile.template` |
| Provider image always rebuilt (no skip, no `--no-cache`) | Provider layer is fast; always rebuild ensures no stale layers; `--no-cache` unnecessary since layer inputs change | `build_container.sh` |
| Hermes gateway requires `--host 0.0.0.0` | Default binds to loopback only; Open WebUI cannot reach it cross-container without binding to all interfaces | `providers/hermes/docker-compose.serve.yml` |

## Completed this session

| File | Change |
|---|---|
| `providers/opencode/base.Dockerfile` | New |
| `providers/opencode/provider.Dockerfile` | New |
| `providers/hermes/base.Dockerfile` | New |
| `providers/hermes/provider.Dockerfile` | New |
| `providers/opencode/Dockerfile` | Deleted |
| `providers/hermes/Dockerfile` | Deleted |
| `providers/opencode/build.sh` | Deleted |
| `providers/hermes/build.sh` | Deleted |
| `scripts/build_container.sh` | New |
| `scripts/build_sandbox.sh` | Deleted |
| `libs/containers.sh` | Extended — base naming, build context, build_image, delegate pattern |
| `libs/build_context.sh` | Deleted |
| `libs/agent-sandbox.sh` | Provider discovery glob; REBUILD_BASE flag |
| `Makefile.template` | REBUILD_BASE variable and flag |
| `docs/architecture/tool_interface.md` | Image naming and Provider Interface tables updated |
| `docs/operations/provider_onboarding_guide.md` | Steps 2/3 rewritten; build.sh step removed |
| `providers/hermes/quickstart.md` | New |

## Deferred items

| Item | Reason | Where next |
|---|---|---|
| Installed `agent-sandbox` CLI and Makefile not updated on disk | Operator must install updated scripts and rebuild stale base images with `docker rmi <provider>-base` before `make build` will work correctly end-to-end | Next session before any build verification |
| `container_model.md` / `sandbox_lifecycle.md` structural overlap | Carried from prior session — doc cleanup pass | Future doc cleanup pass |
| Session state persistence | Carried from prior session | Future milestone (post-M2) |
| copy-in / copy-out implementation | Not addressed this session | Next session |
| Claude Desktop and Pi provider integrations | Explicitly out of scope | Future M2.2 session |

## Next session

M2.2 — Reasoning Layer Modularisation.

Trigger B has not run. One prior acceptance criterion remains open (second provider empirical proof).

Before running any build targets next session, operator must:
1. Install updated `agent-sandbox` CLI and Makefile from this session's outputs
2. `docker rmi opencode-base hermes-base` to clear stale base images
3. `make build` to verify clean rebuild end-to-end

Remaining work:
1. **Implement provider config copy-in.** The architecture documents describe copy-in as the mechanism for seeding provider config files into the container, but it is not yet implemented in `scripts/run_agent.sh`. The required change is: after `compose_sandbox_wait` and before the agent attaches, source `providers/<n>/copy_in.sh` if the file exists. `copy_in.sh` is a new optional provider file (alongside `setup.sh`) that uses `docker compose cp` to copy tracked files from `SANDBOX_DIR` into the container. For Hermes, this means copying `$OUTPUT_DIR/.hermes/config.yaml` and `$OUTPUT_DIR/.hermes/.env` into `/home/agentuser/.hermes/` inside the agent container. The existing bind mounts for these files in `docker-compose.hermes.yml` should be removed once copy-in is working — the two mechanisms are redundant and copy-in is the correct one. `provider_onboarding_guide.md` and `tool_interface.md` will need a follow-up update to document `copy_in.sh` as an optional provider file alongside `setup.sh`.

2. **Implement provider config copy-out (if time allows).** Symmetric to copy-in: after the agent exits and before `docker compose down -v`, source `providers/<n>/copy_out.sh` if it exists. For Hermes, this copies `config.yaml` and `.env` back from the container to `SANDBOX_DIR`. Copy-out is noted as not yet implemented in the architecture docs — if implemented this session, remove that note from `sandbox_lifecycle.md` and `container_model.md`.

3. Verify `make dry-run PROVIDER=hermes` and `make serve PROVIDER=hermes` pass with updated scripts

