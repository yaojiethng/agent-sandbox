# Agent Handover

**Date:** 2026-05-22
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Chore
**Status:** Closed

## Objective

Bump Pi and Node to latest, lock down dependency versions, document the npm/pnpm decision, clean up stale roadmap sections, and record corrections to past documents about the bind mount failure.

## Scope

1. Bump Pi from `0.70.6` to `0.75.4` and Node from `20-slim` to `22.22.3-slim`.
2. Evaluate npm vs pnpm for dependency management; record decision.
3. Clean up roadmap: move Governance Hardening and Dependency Security to `roadmap_future.md`.
4. Record mid-session findings from the session's investigations.

## Carried forward

| Item | From handover |
|---|---|
| Cross-filesystem mount issue — utime/EPERM on 9p/virtiofs mounts nullifies `_ensure_harness_keys` fix | `20260522-04` — deferred items |
| M2.7 task: generic pre-flight validation (Proposal 3) | `20260522-04` — one subtask remaining |

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| Bind mount approach for settings.json invalidated on cross-filesystem hosts (macOS/Windows Docker Desktop). Pi bump to 0.75.4 did not resolve. Corrections added to 3 past documents. | bug — design invalidation | Mount redesign required for non-Linux hosts. |
| Governance Hardening and Dependency Security milestones were listed inline in roadmap.md — both stale. Moved to roadmap_future.md (Governance → M9 standalone, Dependency Security → subsection under M7). | stale milestones | Fixed this session. |
| Pi package moved from `@mariozechner/pi-coding-agent` to `@earendil-works/pi-coding-agent`. | package migration | Updated base.Dockerfile. Old references in closed docs remain as historical record. |
| M2.4 description references opencode; we use Pi now. Milestone is complete, description needs updating. | doc fix | Deferred to next session. |

## Completed this session

| File | Change |
|---|---|
| [`providers/pi/base.Dockerfile`](../../providers/pi/base.Dockerfile) | Bumped Pi from `@mariozechner/pi-coding-agent@0.70.6` to `@earendil-works/pi-coding-agent@0.75.4`; bumped Node from `20-slim` to `22.22.3-slim`; added `--ignore-scripts` flag |
| [`docs/devlog/roadmap.md`](../../docs/devlog/roadmap.md) | Removed Governance Hardening and Dependency Security sections (moved to roadmap_future.md); updated Milestone Summary to link M9 in roadmap_future |
| [`docs/devlog/roadmap_future.md`](../../docs/devlog/roadmap_future.md) | Added Governance Hardening as M9 standalone milestone; added Dependency Security as subsection under M7 |
| [`docs/devlog/discussions/design_provider_config_ownership_and_loading.md`](../../docs/devlog/discussions/design_provider_config_ownership_and_loading.md) | Updated correction block — bind mount invalidated for cross-fs; Pi bump didn't resolve; copy-in is favoured path |
| [`docs/devlog/handovers/20260512-02-design-provider_config_ownership_and_loading.md`](../../docs/devlog/handovers/20260512-02-design-provider_config_ownership_and_loading.md) | Added correction — bind mount approach failed on cross-fs mounts |
| [`docs/devlog/handovers/20260513-10-impl-settings_json_collision_fix.md`](../../docs/devlog/handovers/20260513-10-impl-settings_json_collision_fix.md) | Added correction — bind mount approach invalidated; revert to copy-in |

## Deferred items

| Item | Reason | Goes to |
|---|---|---|
| pnpm migration | No benefit until first first-party extension is added. Pi 0.75.4 ships shrinkwrapped. | When first extension is scoped |
| Mount strategy redesign — selective bind mounts + ephemeral config | New approach raised; needs design + implementation | Next session |
| Story for agent state persistence | Drafted but attribution deferred to next session | Next session |
| M2.4 description cleanup | Minor doc fix — update milestone description to reflect Pi | Next session |

## Next session

M2.7 — Session Identity and Harness Versioning. Mount strategy redesign.

**Design and implement** the selective bind mount approach: `prompts/`, `sessions/`, `skills/` as RW bind mounts; everything else ephemeral via copy-in. Includes:
- Generic `_provision_agent_home(source, target, mount_dirs...)` helper
- Update compose template
- Update entrypoint or pre-flight hook
- Auth.json ephemeral-by-design rationale
- Story document for agent state persistence

**Also:** M2.4 description cleanup (update to reflect Pi).

### Decision — stick with npm, defer pnpm

Stick with npm for now. Pi 0.75.4 ships shrinkwrapped — its transitive deps are already pinned by the Pi team. pnpm's strict dependency isolation provides value only when managing multiple first-party packages in the Dockerfile. Deferred indefinitely; criteria for non-deferral: first first-party Pi extension is added.
