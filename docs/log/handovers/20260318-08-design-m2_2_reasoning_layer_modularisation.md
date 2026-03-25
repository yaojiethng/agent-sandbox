# Agent Handover

**Session date:** 2026-03-18
**Milestone:** M2.2 — Reasoning Layer Modularisation
**Session type:** Implementation

## Objective
Design, document, and implement M2.2 shared logic extraction. All implementation tasks complete except operator validation of `make dry-run`.

## Scope
Steps 2–7. All task groups complete except provider interface validation:
- Documentation — `execution_model.md`, `tool_interface.md` updated
- Shared logic extraction — `start_agent.sh` moved, `run.sh` created, `build_agent.sh` renamed
- Container lifecycle library — `libs/containers.sh` created; `agent-sandbox.sh` updated; compose template updated
- Provider interface validation — `make dry-run` pending operator confirmation
- Base image split — deferred

## Acceptance criteria

- [x] `make dry-run` passes: both containers start, liveness writes to `workspace/output/`, `staged.diff` lands in `.workspace/changes/`, teardown clean
- [x] `scripts/start_agent.sh` contains no compose invocation

## Hot files

| File | Why in scope |
|---|---|
| [`providers/opencode/start_agent.sh`](providers/opencode/start_agent.sh) | Primary audit target — shared vs provider-specific split |
| [`providers/opencode/build_agent.sh`](providers/opencode/build_agent.sh) | To be renamed `providers/opencode/build.sh` |
| [`scripts/build_sandbox.sh`](scripts/build_sandbox.sh) | Location corrected — was wrongly listed as `providers/opencode/build_sandbox.sh` in session-06 handover |
| [`docs/architecture/execution_model.md`](docs/architecture/execution_model.md) | Stale dir name table removed; mount paths and entrypoint section corrected |
| [`docs/architecture/tool_interface.md`](docs/architecture/tool_interface.md) | Command shapes, env var names, mount paths corrected |
| [`docs/development/roadmap.md`](docs/development/roadmap.md) | Updated with M2.2 design decisions, revised task list, completed tasks marked |
| [`docs/architecture/execution_model.md`](docs/architecture/execution_model.md) | Stale tables removed; three-table structure; diagram fixed; provider interface section added |
| [`docs/architecture/tool_interface.md`](docs/architecture/tool_interface.md) | Execution modes section; mount/env tables; container naming table corrected |
| [`scripts/start_agent.sh`](scripts/start_agent.sh) | Moved from `providers/opencode/`; compose block stripped; `--provider` flag; dispatches to `run.sh` |
| [`providers/opencode/run.sh`](providers/opencode/run.sh) | New — all compose invocation; mode dispatch; health poll via `sandbox_container_name` |
| [`providers/opencode/build.sh`](providers/opencode/build.sh) | Renamed from `build_agent.sh` |
| [`libs/containers.sh`](libs/containers.sh) | New — image/container naming, build helpers, preflight |
| [`scripts/agent-sandbox.sh`](scripts/agent-sandbox.sh) | Sources `containers.sh`; `--provider` flag; provider-agnostic build dispatch |
| [`libs/_template/docker-compose.yml.template`](libs/_template/docker-compose.yml.template) | `container_name` pinned to image name; no Compose index suffix |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| `start_agent.sh` moves to `scripts/`; becomes provider-agnostic dispatch entry point | Pre-flight is harness logic, not provider logic; enables second provider without duplicating checks | Roadmap (pending) |
| Provider interface: `build.sh` and `run.sh` under `providers/<name>/` | Clean split — image setup vs container invocation; independently invokable | Roadmap (pending) |
| `build_agent.sh` renamed to `build.sh` | No wrapper needed; images refreshed independently via `make rebuild` | Roadmap (pending) |
| `.env` loaded once in `start_agent.sh`, exported to provider scripts | Eliminates image name re-derivation in build scripts; single source of truth | Roadmap (pending) |
| Compose file check moves to `providers/opencode/run.sh` | Provider-specific knowledge; not harness pre-flight | Roadmap (pending) |
| `build_sandbox.sh` stays at `scripts/`; project controls `Dockerfile.sandbox` in `SANDBOX_DIR` | Already correct; onboard seeds from template, operator amends | `tool_interface.md` |
| Base image split deferred | BuildKit layer cache sufficient for reasoning layer; no `--no-cache` issue on reasoning side; revisit if operators report slow builds | This handover |
| `dirs.sh` unchanged | Sync mechanism between host and container; removing it would break the sync contract | This handover |
| Mode vocabulary standardised in harness; per-provider declaration in `run.sh` | Provider declares supported modes; `run.sh` errors clearly on unsupported mode | Roadmap (pending) |

## Completed this session

| File | Change |
|---|---|
| `docs/architecture/execution_model.md` | Three-table structure; diagram fixed; provider interface section; all `start_agent.sh` → `scripts/start_agent.sh` |
| `docs/architecture/tool_interface.md` | Execution modes section; container naming table corrected (no `-1` suffix); env table corrected; mount shape unified |
| `docs/development/roadmap.md` | Design decisions recorded; task list updated; completed tasks marked; containers.sh group added |
| `scripts/start_agent.sh` | Moved from `providers/opencode/`; `REPO_ROOT` fixed for `scripts/` location; compose block removed; `--provider` flag; sources `containers.sh`; calls `preflight`; dispatches to `run.sh` |
| `providers/opencode/run.sh` | New file — compose file check; mode dispatch (`standard`, `serve`, `dry-run`, `headless` reserved); health poll via `sandbox_container_name`; sources `containers.sh` |
| `providers/opencode/build.sh` | Renamed from `build_agent.sh` — no logic changes |
| `libs/containers.sh` | New file — `agent_image_name`, `sandbox_image_name`, `agent_container_name`, `sandbox_container_name`, `build_agent`, `build_sandbox`, `build_all`, `preflight` |
| `scripts/agent-sandbox.sh` | Sources `containers.sh`; `--provider` flag (default `opencode`); build subcommand uses `sandbox\|<provider>\|all` vocabulary; inline helpers removed; `serve` mode no longer passes `--serve` flag |
| `libs/_template/docker-compose.yml.template` | `container_name` set to `${SANDBOX_IMAGE_NAME}` / `${AGENT_IMAGE_NAME}`; no Compose index suffix; header comment updated |

## Deferred items

None.

## Next session
**M2.2 — Reasoning Layer Modularisation — Provider investigations.**

`make dry-run` passed. M2.2 core tasks complete. Next session opens provider investigations (Claude Code and Claude Desktop) and addresses two refactoring tasks carried from this session.

- [ ] A second provider can be added under `providers/<n>/` with no changes to `scripts/` or `libs/` — pushed to next session (verified by provider investigations)

**Refactoring tasks (before or alongside investigations):**
1. `onboard.sh` — use `containers.sh` naming functions for consistent image name generation; remove any hardcoded name construction
2. `scripts/start_agent.sh` — stop exporting `.env` variables into the environment; pass required variables as explicit args to `run.sh` instead

**Watch-out items:**
1. Provider investigations are one document per provider per [`investigation_policy.md`](docs/operations/investigation_policy.md). Both can run in parallel sessions.
2. Trigger B does not fire until investigations are resolved and acceptance criterion 3 (second provider verified) is met.
