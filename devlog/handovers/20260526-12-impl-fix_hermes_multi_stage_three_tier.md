# Agent Handover

**Session date:** 2026-05-26
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Implementation
**Status:** Active

## Objective

Fix the Hermes multi-stage build (finding 1 from thermo-nuclear review): make the builder stage inherit from `agent-node-base` so the three-tier architecture actually provides value.

## Scope

**In scope:**
- Fix `src/reasoning/providers/hermes/base.dockerfile` builder stage to use `agent-node-base`
- Remove redundant Node.js install from builder stage
- Keep Python-specific build tools (`gcc`, `python3-dev`, `libffi-dev`) in builder
- Fix Findings 2, 3, 7, 8 from thermo-nuclear review (trap, build_if_missing, shared base name, error format)
- Fix apply.sh sources at top

## Carried forward

None.

## Acceptance criteria

See Gate 2 table in session log.

## Hot files

| File | Why in scope |
|---|---|
| `src/reasoning/providers/hermes/base.dockerfile` | Builder stage inherited from wrong base |
| `scripts/build.sh` | Trap safety, duplicate patterns, hardcoded string, error format |
| `src/build/image.sh` | Restore shared_base_image_name function |
| `scripts/workflows/apply.sh` | Sources at bottom of file |

## Decisions made this session

None.

## Mid-session findings

None.

## Completed this session

| File | Change summary |
|---|---|
| `src/reasoning/providers/hermes/base.dockerfile` | Builder now inherits from agent-node-base via ARG BUILDER_BASE |
| `src/build/image.sh` | Added shared_base_image_name() |
| `scripts/build.sh` | Trap function, build_if_missing helper, --no-cache rename, error format |
| `scripts/agent-sandbox.sh` | --no-cache-base -> --no-cache |
| `scripts/start_agent.sh` | --no-cache-base -> --no-cache |
| `scripts/workflows/apply.sh` | Sources moved to top, trailing blanks stripped |
| `src/capability/capability.dockerfile` | Added missing COPY diff.sh |

## Deferred items

None.

## Next session

Sub-milestone: M2.7 — Session Identity and Harness Versioning
