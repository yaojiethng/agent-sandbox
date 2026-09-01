# Agent Handover

**Date:** 2026-05-23
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Planning
**Status:** Closed

## Objective

Design a container layer model that consolidates shared harness plumbing across all providers (Pi, Hermes, Claude Code, OpenCode) without breaking the existing base/provider Dockerfile cache strategy, and that simplifies the UID Mapping implementation (M2.7 Track C, Phase 2) from 5 Dockerfile edits down to 1.

## Scope

**In scope:**
- Map the current 4-provider Dockerfile tree (base + provider) and sandbox Dockerfile
- Identify every line that is genuinely duplicated vs. provider-specific
- Evaluate a shared `harness-agent` layer against three criteria: build speed (Docker cache), maintenance burden, security surface
- Weigh tradeoffs of different regrouping strategies (e.g. harness libs in shared base vs. COPY-only layer vs. multi-stage)
- Produce a recommended layer architecture and a migration plan
- Update architecture docs (execution_model.md, tool_interface.md) if the model changes

**Out of scope:**
- Implementation of any Dockerfile changes
- UID Mapping implementation (Phase 1/2/3 of Track C)
- The sandbox Dockerfile (separate lifecycle, may be affected but not the primary focus)
- Non-Dockerfile changes (compose, build pipeline, start scripts)

## Carried forward

From session 09 (UID Mapping design): the roadmap Track C phases 1-3 remain the implementation target. This session's output may change how Phase 2 is executed (fewer Dockerfiles to edit).

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | Story document (`story_container_layer_model.md`) documents the decision (Option 2: two harness bases + sandbox independent) with rationale | `read` the story doc | Operator |
| 2 | Story document documents rejected options with reasons (Option 3: cross-distro `COPY --from` rejected due to native C extension risk) | `read` the story doc | Operator |
| 3 | Handover records the session's decisions and open questions | `read` the handover | Operator |
| 4 | The open questions from the story doc are resolved or assigned to a follow-up session | `read` story doc Open Questions + handover Next session | Operator |

## Recovery checks

| Check | Result |
|---|---|
| Trigger B pending | No — prior session (10) was onboard.sh refactor, closed cleanly. |
| Compaction | Not required. |

## Hot files

| File | Reason | Status |
|---|---|---|
| `docs/devlog/discussions/story_container_layer_model.md` | Story document — decision recorded, Option 2 selected | ✅ Updated |
| `docs/devlog/handovers/20260523-11-plan-container_layer_redesign.md` | This handover | ✅ Updated |
| `providers/*/base.Dockerfile` | Will be trimmed after this session | 🔒 Next session |
| `providers/*/provider.Dockerfile` | Will be trimmed after this session | 🔒 Next session |
| `libs/sandbox.Dockerfile` | Standalone (unchanged by layer consolidation) | — |

## Decisions made this session

| Decision | Rationale |
|---|---|
| **Selected Option 2** — two harness bases (node + python), sandbox independent | Option 3 (single Ubuntu base) rejected — cross-distro `COPY --from` breaks on native C extensions. Option 1 leaves 5 UID Mapping edits. Option 2 gives 3 edits, shared Node cache, no runtime fragility. |
| UID collision logic stays **inline** in each harness Dockerfile | The collision pattern is stable; a shared script adds traceability cost with no maintenance benefit. |
| Fast-changing harness libs stay on **provider layer**, not moved into harness base | Preserves current cache strategy (provider layer rebuilds every session; harness base is stable). |
| Claude Code migrates from `node:20-slim` to `node:22-slim` via node-harness | npm packages are backwards-compatible. Acceptable breakage risk for an unused provider. |
| OpenCode migrates from `ubuntu:24.04` + apt npm to `node:22.22.3-slim` | Node image ships npm; eliminates apt npm dependency. |
| `USER agentuser` stays at end of each provider base; `ENTRYPOINT` stays in provider layer | Provider bases need root for apt/npm installs. Harness base is infrastructure only — no behavioural directives. Docker resolves final metadata from nearest ancestor independently. |
| Universal system packages in both harness bases: `git`, `curl`, `ca-certificates`, `rsync`, `fd-find`, `ripgrep` | All providers need these for the harness workflow. `openbase` python3 dep was stale — not needed. |
| Hermes multi-stage: remove `WORKDIR /opt/hermes` from `hermes-base` | Triple WORKDIR override is fragile. `COPY --from=builder` uses absolute paths. Multi-stage stays (strips build tools). |
| Harness base `ENV PATH` does not need special handling | Docker `ENV $PATH` build-time interpolation appends, not replaces — provider base inherits harness PATH. |
| `build_context_harness()` function, `harness_image_name()` naming function | Harness base has no provider files — needs its own minimal build context. Matching naming convention. |
| Chore session before Dockerfile session | Harness Dockerfiles land in their final location directly, avoiding a path migration. |
| No provider compose overlay sets `user:` | Base compose template is the single source of truth for `user:`. Convention documented in spec. |

## Audit findings

A design audit (subagent running improve-codebase-architecture) identified 10 gaps. All were resolved during this session and documented in `spec_container_layer_redesign.md` rule 2.4:

| # | Finding | Severity | Resolution |
|---|---|---|---|
| 1 | `USER agentuser` not in harness base — entrypoint runs as root | Blocking | USER/ENTRYPOINT both stay at provider level. Harness base is infrastructure only. |
| 2 | OpenCode loses ubuntu packages | Major | Universal packages moved into both harness bases |
| 3 | PATH composition — harness base PATH overridden | Major | No change — Docker ENV $PATH appends |
| 4 | Hermes multi-stage WORKDIR triple override | Major | Remove WORKDIR from hermes-base |
| 5 | No harness build context function | Major | `build_context_harness()` added to plan |
| 6 | node-harness missing system packages | Major | Same as #2 — resolved |
| 7–10 | Minor items (unused copy, naming function, session ordering, compose overlay convention) | Minor | Convention notes, chore session scope |

## Completed this session

| File | Change |
|---|---|
| `docs/devlog/discussions/story_container_layer_model.md` | New story document — problem analysis, 3 options evaluated, Option 2 selected, rejection rationale for Option 3, open questions tagged by status. |
| `docs/devlog/discussions/story_container_layer_model.md` | New story document — problem analysis, 3 options evaluated, Option 2 selected, rejection rationale for Option 3. Updated Open Questions section with all 5 resolutions from audit. |
| `docs/devlog/discussions/spec_container_layer_redesign.md` | New spec document — proposal details, problems found, 10 audit findings resolved (rule 2.4), Design Decisions section, 5-session implementation sequence. |
| `docs/devlog/handovers/20260523-11-plan-container_layer_redesign.md` | This handover — all decisions and findings recorded. |
| `docs/devlog/roadmap.md` | Added link to container layer spec under Track C. |

## Deferred items

None.

## Next session (after this design session closes)

**1. Chore session** — structural cleanup of `libs/`, `scripts/`, and `agent/` into a `harness/` tree. No logic changes, purely mechanical path substitutions. Proposed target structure documented in story doc Open Questions — Resolved.

**2. Dockerfile refactoring session** — create the two harness Dockerfiles (`harness/reasoning/node.Dockerfile`, `harness/reasoning/python.Dockerfile`), trim the 4 provider base/provider Dockerfiles, update `build_agent()` in `containers.sh`. Paths recalibrated after the chore session lands.

**3. UID Mapping Phase 1** — build pipeline threading (can proceed independent of the layer refactoring).

**Pending operator action:** Confirm close of this design session.
