# Agent Handover

**Date:** 2026-07-22
**Milestone:** M2.6 — Session Resume and Mount Model Redesign
**Type:** Chore — Fix stale `docs/discussions/` and `docs/devlog/` path references after directory restructuring
**Status:** Closed

## Objective

After the `docs/` → `devlog/` directory restructuring (M2.6.3), several current operational docs still reference the old paths `docs/discussions/` (now `devlog/discussions/`) and `docs/devlog/` (now `devlog/`). These are stale path references and broken links that need correction.

No structural changes — path fixes only.

## Scope

Update all stale `docs/discussions/` and `docs/devlog/` path references in current (non-handover) files to point to the correct locations.

**Not in scope:**
- Closed handover files (`devlog/handovers/`) — historical records, not modified per policy
- Superseded discussion files under `devlog/discussions/` that self-reference in their superseded header — historical records
- Policy content changes (this is a path-cleanup chore only)

## Stale reference inventory

### `docs/discussions/` → `devlog/discussions/` (6 files)

| File | Stale text | Fix |
|---|---|---|
| `docs/operations/story_policy.md:17` | `` `docs/discussions/` `` | `` `devlog/discussions/` `` |
| `docs/operations/iteration_policy.md:77` | `` in `docs/discussions/` `` | `` in `devlog/discussions/` `` |
| `docs/operations/milestone_policy.md:36` | `` in `docs/discussions/` `` | `` in `devlog/discussions/` `` |
| `docs/operations/study_policy.md:17` | `` `docs/discussions/` `` | `` `devlog/discussions/` `` |
| `docs/development/project_index.md:51` | `### Discussions (`docs/discussions/`)` | `### Discussions (`devlog/discussions/`)` |
| `docs/development/project_index.md:173` | `` `docs/discussions/story_obsidian_vault_onboarding.md` `` | `` `devlog/discussions/story_obsidian_vault_onboarding.md` `` |

### `docs/discussions/` stale link targets in `devlog/roadmap.md` (6 references)

| Line | Current | Fix |
|---|---|---|
| 48 | `(docs/discussions/20260522-story-active-prompt_eval_infrastructure.md)` | `(./discussions/20260522-story-active-prompt_eval_infrastructure.md)` |
| 99 | `(../discussions/20260622-study-settled-security_delta_worktree_model.md)` | `(./discussions/20260622-study-settled-security_delta_worktree_model.md)` |
| 106 | `(../discussions/20260622-study-settled-security_delta_worktree_model.md)` | `(./discussions/20260622-study-settled-security_delta_worktree_model.md)` |
| 107 | `(../discussions/story_agent_git_surface.md)` | `(./discussions/story_agent_git_surface.md)` |
| 108 | `(../discussions/20260522-story-settled-agent_state_persistence.md)` | `(./discussions/20260522-story-settled-agent_state_persistence.md)` |
| 109 | `(../discussions/story_container_layer_model.md)` | `(./discussions/story_container_layer_model.md)` |

### `docs/devlog/` references in live discussion docs and roadmap_future.md (9 references)

**Discussion docs that are not superseded:**
- `devlog/discussions/investigation_harness_sig_requirements.md:6` — `docs/devlog/roadmap.md` → `devlog/roadmap.md` (or `../roadmap.md`)
- `devlog/discussions/20260428-story-active-sequencing_and_knowledge_persistence.md:67` — path description
- `devlog/discussions/design_settings_permissions_group_bind.md:131` — relative path to resolved story
- `devlog/discussions/story_windows_filesystem_incompatibilities.md:31,161` — path references
- `devlog/roadmap_future.md:170,186` — `docs/devlog/discussions/` → `./discussions/`

**Superseded docs (just headers, may not need fixing):**
- `devlog/discussions/20260523-design-active-container_layer_redesign.md` (superseded)
- `devlog/discussions/20260416-study-superseded-git_worktrees.md` (superseded)
- `devlog/discussions/story_linux_filesystem_uid_mismatch.md` (resolved, superseded)
- `devlog/discussions/story_obsidian_vault_onboarding.md` (superseded)

**Superseded docs are excluded — their path references are historical and not expected to resolve.**

## Completed this session

| File | Change |
|---|---|
| `devlog/roadmap.md` | Marked deferred item "Docs directory restructuring" as done; fixed 6 link targets + 5 display text refs + 1 `../discussions/` target |
| `docs/operations/story_policy.md` | `docs/discussions/` → `devlog/discussions/` |
| `docs/operations/iteration_policy.md` | `docs/discussions/` → `devlog/discussions/` |
| `docs/operations/milestone_policy.md` | `docs/discussions/` → `devlog/discussions/` |
| `docs/operations/study_policy.md` | `docs/discussions/` → `devlog/discussions/` |
| `docs/development/project_index.md` | `docs/discussions/` → `devlog/discussions/` (2 spots) |
| `devlog/discussions/20260428-story-active-sequencing_and_knowledge_persistence.md` | `docs/devlog/` → `devlog/` |
| `devlog/discussions/design_provider_config_ownership_and_loading.md` | `docs/devlog/discussions/` + `docs/devlog/handovers/` → `devlog/...` |
| `devlog/discussions/investigation_harness_sig_requirements.md` | 3 display text refs `docs/devlog/` → `devlog/` |
| `devlog/discussions/story_windows_filesystem_incompatibilities.md` | 3 refs `docs/devlog/` → `devlog/` |
| `devlog/roadmap_future.md` | 2 refs `docs/devlog/discussions/` → `devlog/discussions/` + link targets |
| `devlog/discussions/design_settings_permissions_group_bind.md` | `docs/devlog/discussions/` → `devlog/discussions/` |
| `AGENTS.md` | 4 refs `docs/devlog/` → `devlog/` |
| `src/reasoning/agent/prompts/new-session.md` | 2 refs `docs/devlog/` → `devlog/` |
| `src/reasoning/agent/drafts/roadmap-audit.skill.md` | `docs/devlog/roadmap.md` → `devlog/roadmap.md` |
| `src/reasoning/agent/drafts/roadmap-management.skill.md` | `docs/devlog/roadmap.md` + `docs/devlog/changelog.md` → `devlog/...` |
| `workflow/knowledge-vault/README.md` | 2 refs `docs/devlog/roadmap.md` → `devlog/roadmap.md` + link targets |
| `workflow/knowledge-vault/changelog.md` | `docs/devlog/roadmap.md` → `devlog/roadmap.md` |
| `src/reasoning/providers/pi/docker-compose.pi.yml` | Removed stale `DESIGN: devlog/roadmap.md M2.4` comment |

## Acceptance criteria — verified

| # | Criterion | Result |
|---|---|---|
| 1 | All `docs/discussions/` references in current policy docs and project_index.md corrected to `devlog/discussions/` | ✅ CLEAN — `grep -rn "docs/discussions" docs/operations/ docs/development/` returns zero |
| 2 | All `docs/discussions/` link targets and display text in `devlog/roadmap.md` corrected to `./discussions/` or `devlog/discussions/` | ✅ CLEAN — grep returns zero |
| 3 | All `docs/devlog/` references in live (non-superseded) discussion docs, `roadmap_future.md`, AGENTS.md, agent prompts/skills, workflow docs, and compose files corrected | ✅ CLEAN — grep returns zero |
| 4 | Superseded discussion docs left untouched | ✅ Confirmed — 3 superseded docs (`story_obsidian_vault_onboarding`, `20260416-study-superseded-git_worktrees`, `story_linux_filesystem_uid_mismatch`, `20260423-design-active-session_identity_hash_based`, `20260523-design-active-container_layer_redesign`) left with intentional historical refs |

## Hot files

| File | Change |
|---|---|
| `docs/operations/story_policy.md` | `docs/discussions/` → `devlog/discussions/` |
| `docs/operations/iteration_policy.md` | `docs/discussions/` → `devlog/discussions/` |
| `docs/operations/milestone_policy.md` | `docs/discussions/` → `devlog/discussions/` |
| `docs/operations/study_policy.md` | `docs/discussions/` → `devlog/discussions/` |
| `docs/development/project_index.md` | `docs/discussions/` → `devlog/discussions/` (2 spots) |
| `devlog/roadmap.md` | 6 stale link targets → `./discussions/` |
| `devlog/discussions/investigation_harness_sig_requirements.md` | `docs/devlog/roadmap.md` → correct path |
| `devlog/discussions/20260428-story-active-sequencing_and_knowledge_persistence.md` | `docs/devlog/` path description |
| `devlog/discussions/design_settings_permissions_group_bind.md` | `docs/devlog/discussions/` → correct path |
| `devlog/discussions/story_windows_filesystem_incompatibilities.md` | 2 stale `docs/devlog/` paths |
| `devlog/roadmap_future.md` | 2 stale `docs/devlog/` paths |

## Dependencies

None. Isolated path-cleanup chore.

## Next session

After handover close, the next work is M2.6.4 implementation (Tier 2 enablement, Tier 3 compose changes, worktree lifecycle, command adaptation) per the design session output in `20260722-01-design-m2_6_4_mount_model_design.md`.
