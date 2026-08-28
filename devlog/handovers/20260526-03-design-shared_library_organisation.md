# Agent Handover

**Session date:** 2026-05-26
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Design
**Status:** Closed

## Objective

Analyse all shared library files in `libs/` — catalogue every function, identify its deployment target (host, capability container, reasoning container), and propose better file groupings than the current interleaved structure.

## Scope

**In scope:**
- Catalogue all 10+ files in `libs/` with function-level granularity
- Map each function to its deployment target(s) — host, reasoning, capability
- Identify cross-target dependencies (functions in one target that call functions in another)
- Propose alternative file groupings based on deployment target and responsibility boundaries

**Out of scope:**
- Implementing any proposed grouping — design-only session
- The `src/` tree restructuring from the structural cleanup spec (separate thread)
- Any code changes

## Carried forward

None.

## Acceptance criteria

Not yet defined.

## Hot files

| File | Why in scope |
|---|---|
| `libs/containers.sh` | Primary file cited in the prompt — interleaved responsibilities |
| `libs/diff.sh` | Shared diff utilities |
| `libs/diff_workflow.sh` | Apply workflow — crosses host/container boundary |
| `libs/dirs.sh` | Path resolution |
| `libs/draft_workflow.sh` | Draft workflow |
| `libs/interactive_session_select.sh` | Interactive session selection |
| `libs/package_branch.sh` | Branch packaging |
| `libs/package_diff.sh` | Diff packaging |
| `libs/routing.sh` | Output path routing |
| `libs/session.sh` | Session state management |
| `libs/snapshot.sh` | Snapshot pipeline |
| `libs/provider-entrypoint.sh` | Provider entrypoint |
| `libs/sandbox-entrypoint.sh` | Sandbox entrypoint |
| `libs/sandbox.Dockerfile` | Sandbox Dockerfile |
| `docs/architecture/execution_model.md` | Deployment model reference |
| `docs/architecture/sandbox_lifecycle.md` | Sandbox lifecycle reference |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Two-dimensional grouping: deployment target × lifecycle stage | Build-time files separate from runtime; host-only separate from container-deployed | Design doc Principles |
| Packaging pipeline symmetrical | diff.sh, package_branch.sh, package_diff.sh all deployed to both containers (fix current asymmetry) | Design doc Deployment matrix |
| session_state.sh separate from routing.sh | K/V store orthogonal to path layout conventions | Design doc Key decisions 2 |
| draft_workflow.sh → 3 files (draft/confirm/reject) | Each workflow stage is independent with separate state | Design doc Key decisions 3 |
| containers.sh → build/image.sh + build/context.sh + libs/host/build.sh | Image naming (pure), context prep (file ops), and build orchestration are distinct responsibilities | Design doc Key decisions 4 |
| Dash convention for multi-word filenames | Consistent with docker-compose.yml | Design doc Key decisions 5 |

## Mid-session findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Agent does not pause at Gates 1 and 2 to ask for operator approval — tends to jump the gun and close prematurely | Process | Must explicitly wait for operator release before implementing, closing, or advancing to the next step | This session |
| session_state is NOT container-only — used by package_branch.sh, package_diff.sh, dry_run scripts on host side | Correction | session_state.sh belongs in libs/shared/ (deployed to both) not in a container-only dir | Design doc Proposed structure |
| draft_clear_stale_lock always paired with validate_project_dir at all 4 call sites | Confirmed | They belong together in guards.sh — correct call | Design doc Current state — session.sh |
| Path resolution is wildly inconsistent across files — 6 different patterns with different variable names: `$AGENT_SANDBOX_REPO`, `$REPO_ROOT`, `$_PB_SCRIPT_DIR`, `$_DW_SCRIPT_DIR`, `$_PD_SCRIPT_DIR`, `$_ISS_SCRIPT_DIR`, `$_DIFF_SH_DIR`, inline `$(cd $(dirname ...))`, hardcoded `/opt/sandbox/lib/` | Technical debt | Must choose one convention and apply it consistently during the libs/ move, or at minimum ensure every source path gets updated correctly for its new target location | This session — design must specify the convention |

## Completed this session

| File | Change |
|---|---|
| `devlog/discussions/20260526-design-shared_library_organisation.md` | Full design document: current-state analysis, pain points, proposed structure, deployment matrix, file mapping, key decisions, open questions |

## Deferred items

| Item | Reason |
|---|---|
| Implementation of the libs/ file moves and splits | Design complete; scoped to an impl session |
| Path resolution convention (spec + refactor) | Deferred to a dedicated design session — 6 inconsistent patterns must be unified before the moves |

## Next session

Sub-milestone: M2.7 — Session Identity and Harness Versioning

Design session. Context handover for the prior implementation thread: `20260526-02-impl-bundle_patch_resilience.md` → Next session there was "Structural cleanup implementation" (still pending).

**Conclusions from this session:**
- Current libs/ organisation has genuine pain points: containers.sh mixes 4 responsibilities, session.sh mixes git guards with K/V store, draft_workflow.sh bundles 3 workflows, packaging pipeline deployment is asymmetric
- The two-dimensional grid (deployment target × lifecycle stage) resolves all of them cleanly
- The libs/ refactor is a self-contained stage of the greater structural cleanup (spec_container_layer_redesign.md) — takes over just the libs/ file moves and splits
- `build/` captures build-time files (image naming, context prep, compose)
- `scripts/` gets build orchestration (build_image, build_agent, build_sandbox, preflight) as `scripts/build.sh`
- `src/libs/` captures shared runtime + packaging pipeline (symmetrical deployment)
- `src/scripts/workflows/` captures host-only workflow files (draft/confirm/reject split)
- `src/capability/` + `src/reasoning/` for container-specific files
- Path resolution is wildly inconsistent (6 patterns) — deferred to a dedicated spec + refactor session before the moves
