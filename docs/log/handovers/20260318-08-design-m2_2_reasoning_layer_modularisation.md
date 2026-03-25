# Agent Handover

**Session date:** 2026-03-18
**Milestone:** M2.2 — Reasoning Layer Modularisation
**Session type:** Design

## Objective
Design the shared logic extraction for M2.2 and update architecture docs to reflect confirmed design decisions and correct stale references, prior to implementation.

## Scope
Design (Step 2) and pre-implementation documentation (Step 5). Task groups targeted:
- Shared logic extraction — design confirmed
- Provider interface — design confirmed
- Documentation — `execution_model.md` and `tool_interface.md` updated to reflect design decisions and correct stale M2.1 references
- Base image split — deferred

Implementation begins next session.

## Acceptance criteria

Not yet defined.

## Hot files

| File | Why in scope |
|---|---|
| [`providers/opencode/start_agent.sh`](providers/opencode/start_agent.sh) | Primary audit target — shared vs provider-specific split |
| [`providers/opencode/build_agent.sh`](providers/opencode/build_agent.sh) | To be renamed `providers/opencode/build.sh` |
| [`scripts/build_sandbox.sh`](scripts/build_sandbox.sh) | Location corrected — was wrongly listed as `providers/opencode/build_sandbox.sh` in session-06 handover |
| [`docs/architecture/execution_model.md`](docs/architecture/execution_model.md) | Stale dir name table removed; mount paths and entrypoint section corrected |
| [`docs/architecture/tool_interface.md`](docs/architecture/tool_interface.md) | Command shapes, env var names, mount paths corrected |
| [`docs/development/roadmap.md`](docs/development/roadmap.md) | Updated with M2.2 design decisions and revised task list |
| [`docs/architecture/execution_model.md`](docs/architecture/execution_model.md) | Updated: stale dir table removed; three-table structure; diagram fixed; sibling convention removed |
| [`docs/architecture/tool_interface.md`](docs/architecture/tool_interface.md) | Updated: mount shape table unified; env table expanded with owner/default; command shapes corrected |

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
| `docs/architecture/execution_model.md` | Stale dir name table removed; three-table structure (host vars → container paths → host mount mapping); diagram fixed (no sibling convention, mount type annotations); sibling convention prose removed; host path variables and mount table replaced with cross-references to `tool_interface.md` |
| `docs/architecture/tool_interface.md` | Mount shape table unified (host `$VAR` + both container paths + owner); env table expanded (default + owner columns; added `SANDBOX_IMAGE_NAME`, `AGENT_IMAGE_NAME`; removed sibling default for `SANDBOX_DIR`); command shapes corrected (no implicit build); `Dockerfile.sandbox` ownership clarified |
| `docs/development/roadmap.md` | M2.2 task list rewritten to reflect confirmed design; design decisions block added; base image and entrypoint audit tasks resolved/deferred; acceptance criteria updated |

## Deferred items

None.

## Next session
**M2.2 — Reasoning Layer Modularisation — Implementation.**

Design is confirmed. Begin at the Documentation task group — update `execution_model.md` and `tool_interface.md` for `scripts/start_agent.sh` path and provider interface. Then proceed to shared logic extraction in order: move `start_agent.sh`, create `run.sh`, rename `build_agent.sh`.

**Watch-out items:**
1. `start_agent.sh` move — update any references in `agent-sandbox.sh` CLI dispatcher and project-side Makefile template that currently point to `providers/opencode/start_agent.sh`.
2. `run.sh` must absorb the full compose block including dry-run and serve mode handling — confirm nothing is left behind in `start_agent.sh`.
3. Validate with `make dry-run` before closing the sub-milestone.
