# Agent Handover

**Session date:** 2026-03-16
**Milestone:** M2.1 — General Capability Layer Prototype
**Session type:** Implementation

## Objective
Implement the two-container model: capability layer Dockerfile/entrypoint, reasoning layer adaptation, Docker Compose orchestration, path alignment, two-image staleness, dry-run update.

## Scope
All implementation task groups in `roadmap.md` M2.1: Capability layer container, Reasoning layer container, Orchestration & lifecycle, Path alignment, Build & staleness, Dry-run, Validation. Architecture docs are the spec — see `tool_interface.md` and `execution_model.md`.

## Acceptance criteria
Carried from M2.1 roadmap entry:
- `make start` brings up two containers via `docker compose up`; capability layer starts first — **not yet tested**
- Agent modifies a file in `sandbox/`; `staged.diff` appears in `.workspace/changes/` — **not yet tested**
- `make apply` applies the diff cleanly — **not yet tested**
- `make serve` exposes port via compose override — **not yet tested**
- `make dry-run` runs both containers, reasoning writes to sandbox, graceful termination, diff written — **not yet tested**
- Capability layer exits cleanly and triggers diff pipeline — **not yet tested**
- Mount isolation: reasoning cannot see `.snapshot/`; capability cannot see `agent-input/` or `agent-output/` — **not yet tested**
- `make build sandbox|agent|all` builds correct images; staleness warns per-image — **not yet tested**

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/sandbox-entrypoint.sh`](scripts/sandbox-entrypoint.sh) | New — capability layer entrypoint |
| [`libs/_template/dockerfile-default.sandbox`](libs/_template/dockerfile-default.sandbox) | New — default capability Dockerfile template |
| [`providers/opencode/Dockerfile`](providers/opencode/Dockerfile) | Reasoning layer changes |
| [`providers/opencode/container-entrypoint.sh`](providers/opencode/container-entrypoint.sh) | Assess for elimination |
| [`providers/opencode/start_agent.sh`](providers/opencode/start_agent.sh) | Two-container lifecycle, compose generation |
| [`libs/snapshot.sh`](libs/snapshot.sh) | Path update: `.agent-input/` → `.snapshot/` |
| [`libs/diff.sh`](libs/diff.sh) | Verify — grep only |
| [`libs/image.sh`](libs/image.sh) | Two-image staleness |
| [`scripts/dry_run.sh`](scripts/dry_run.sh) | Two-container dry-run |
| [`libs/_template/docker-compose.yml.template`](libs/_template/docker-compose.yml.template) | New — compose template |

## Decisions made this session

None.

## Completed this session

No file changes this session.

## Deferred items

None.

## Next session

Continue M2.1 implementation. This handover was created before implementation began; the session was interrupted by workflow policy restructuring work.

**Watch-out items:**
1. `sandbox/` mount path differs between containers: `/home/agentuser/sandbox/` (capability) vs `/home/agentuser/project/sandbox/` (reasoning)
2. `container-entrypoint.sh` elimination must be an explicit decision, not a silent drop
3. Dogfood compose file first, then derive template
