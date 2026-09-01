# Agent Handover

**Date:** 2026-05-04
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Type:** Implementation
**Status:** Closed

## Objective

Add `/opt/workflow/` directory to the agent container with `agent/skills/` and `agent/prompts/` subdirectories, following the same build-convention used for `/opt/sandbox/bin/` and `/opt/sandbox/lib/`.

## Scope

- Stage `agent/skills/` and `agent/prompts/` into the agent build context in `libs/containers.sh` (same `cp -r` convention as `docs/architecture` and `docs/concepts`)
- Add COPY commands to each provider's `provider.Dockerfile` to populate `/opt/workflow/agent/skills/` and `/opt/workflow/agent/prompts/`
- `/opt/workflow/` is a data hierarchy for agent workflow files (prompts and skills) — no PATH modification needed
- No changes to sandbox container or base images
- A.3 documentation alignment deferred — resume after this session

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | `grep -c "cp -r.*agent/skills" libs/containers.sh` exits 0 — `agent/skills/` staged in `build_context_agent()` | pending |
| 2 | `grep -c "cp -r.*agent/prompts" libs/containers.sh` exits 0 — `agent/prompts/` staged in `build_context_agent()` | pending |
| 3 | Each provider Dockerfile has `COPY agent/skills /opt/workflow/agent/skills/` | pending |
| 4 | Each provider Dockerfile has `COPY agent/prompts /opt/workflow/agent/prompts/` | pending |
| 5 | `make build agent PROVIDER=<any>` succeeds | pending |
| 6 | `docker run --rm $(image) ls /opt/workflow/agent/` shows `skills` and `prompts` | pending |
| 7 | `grep "skills" providers/pi/config/agent/settings.json` shows `/opt/workflow/agent/skills` path | pending |
| 8 | `grep "prompts" providers/pi/config/agent/settings.json` shows `/opt/workflow/agent/prompts` path | pending |

## Hot files

| File | Why in scope |
|---|---|
| [`libs/containers.sh`](../../libs/containers.sh) | Add `agent/skills/` and `agent/prompts/` to `build_context_agent` |
| `providers/*/provider.Dockerfile` (4 files) | Add COPY commands for `/opt/workflow/agent/skills/` and `/opt/workflow/agent/prompts/` |
| [`providers/pi/config/agent/settings.json`](../../providers/pi/config/agent/settings.json) | Add `skills` and `prompts` paths pointing to `/opt/workflow/agent/` |

## Decisions made this session

None.

## Mid-session findings

None.

## Completed this session

| File | Change |
|---|---|
| [`libs/containers.sh`](../../libs/containers.sh) | Staged `agent/skills/` and `agent/prompts/` in `build_context_agent()` via `cp -r` |
| [`providers/pi/provider.Dockerfile`](../../providers/pi/provider.Dockerfile) | Added COPY for `/opt/workflow/agent/skills/` and `/opt/workflow/agent/prompts/` |
| [`providers/claude-code/provider.Dockerfile`](../../providers/claude-code/provider.Dockerfile) | Same |
| [`providers/hermes/provider.Dockerfile`](../../providers/hermes/provider.Dockerfile) | Same |
| [`providers/opencode/provider.Dockerfile`](../../providers/opencode/provider.Dockerfile) | Same |
| [`providers/pi/config/agent/settings.json`](../../providers/pi/config/agent/settings.json) | Added `skills` and `prompts` settings arrays pointing to `/opt/workflow/agent/` |

## Deferred items

None.

## Next session

M2.3 — Apply Workflow: Capability Layer Diff Pipeline. Documentation alignment (A.3) remains pending per prior handover.

**Conclusions from this session:** None.
