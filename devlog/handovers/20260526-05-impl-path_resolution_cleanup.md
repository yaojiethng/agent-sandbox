# Agent Handover

**Date:** 2026-05-26
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Implementation
**Status:** Closed

## Objective

Apply the path resolution convention from the spec: standardise all `_*_DIR` variable names to `_SCRIPT_DIR`, switch host-only libs from self-resolution to `$AGENT_SANDBOX_REPO`/`$REPO_ROOT`, and update Dockerfile COPY source paths. This is the mechanism cleanup — actual file moves to their target directories are deferred.

## Scope

**In scope:**
- Standardise `_DIFF_SH_DIR`, `_PB_SCRIPT_DIR`, `_PD_SCRIPT_DIR` → all to `_self_dir` in cross-context libs
- Remove self-resolution vars from host-only libs (`_DW_SCRIPT_DIR`, `_ISS_SCRIPT_DIR`, inline `$(cd...)` in draft_workflow); switch to `$AGENT_SANDBOX_REPO`
- Switch test files from relative `../libs/` paths to `$REPO_ROOT/libs/...`
- Move `scripts/checkpoint.sh` → `libs/checkpoint.sh` (it's a library, sourced by `start_agent.sh`)
- Update `start_agent.sh` source path for checkpoint

**Explicitly deferred:**
- File moves to `src/`, `build/`, `workflows/` directories — separate impl session
- Container-side path changes (entrypoints keep `/opt/sandbox/lib/`)
- Any test behaviour changes — only source path formatting updates
- Dockerfile COPY paths — sources haven't moved yet

**Question to resolve at Gate 1:** The migration table in the spec points to target directories that don't exist yet (`src/libs/session_state.sh`, `build/image.sh`, etc.). Do we:

A) Update paths to the current locations but using the new conventions only (e.g. `$AGENT_SANDBOX_REPO/libs/diff.sh` instead of `$_DIFF_SH_DIR/diff.sh` — same path, new mechanism)?

B) Update paths to the final target locations (e.g. `$AGENT_SANDBOX_REPO/src/libs/diff.sh`), which would require creating the target dirs and symlinks or stub files so nothing breaks until the moves happen?

C) Do the path updates AND the file moves in a single session?

## Carried forward

None.

## Acceptance criteria

Not yet defined.

## Hot files

| File | Change |
|---|---|
| `libs/diff.sh` | `_DIFF_SH_DIR` → `_SCRIPT_DIR` |
| `libs/diff_workflow.sh` | `_DW_SCRIPT_DIR` → remove; switch to `$AGENT_SANDBOX_REPO` |
| `libs/draft_workflow.sh` | inline `$(cd...)` (×3) → remove; switch to `$AGENT_SANDBOX_REPO` |
| `libs/interactive_session_select.sh` | `_ISS_SCRIPT_DIR` → remove; switch to `$AGENT_SANDBOX_REPO` |
| `libs/package_branch.sh` | `_PB_SCRIPT_DIR` → `_SCRIPT_DIR` |
| `libs/package_diff.sh` | `_PD_SCRIPT_DIR` → `_SCRIPT_DIR` |
| `libs/routing.sh` | Self-resolution variables → `_SCRIPT_DIR` |
| `libs/containers.sh` | build_context source paths → new target paths |
| `libs/sandbox.Dockerfile` | COPY source paths |
| `providers/pi/provider.Dockerfile` | COPY source paths |
| `scripts/agent-sandbox.sh` | Source paths → use `$AGENT_SANDBOX_REPO` consistently |
| `scripts/start_agent.sh` | Source paths → use `$REPO_ROOT` |
| `scripts/run_agent.sh` | Source paths → use `$REPO_ROOT` |
| `tests/test_*.sh` (all referencing `../libs/`) | Source paths → use `$REPO_ROOT` |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| `_self_dir` as canonical self-resolution variable name | Avoids ambiguity with `scripts/` directory vs `_SCRIPT_DIR` | Concept doc `context_resolution.md` |
| `AGENT_SANDBOX_REPO` set in test files when sourcing host libs | Tests run from repo checkout; `$AGENT_SANDBOX_REPO` not set by default, but host libs now depend on it | `test_diff_workflow.sh`, `test_draft_workflow.sh`, `test_interactive_session_select.sh` |

## Mid-session findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `checkpoint.sh` lives in `scripts/` but is a library (defines `worktree_id_derive()`, sourced by `start_agent.sh`) — resolved this session | Misplaced file | Moved to `libs/checkpoint.sh`; `start_agent.sh` source path updated | Resolved this session |

## Completed this session

| File | Change |
|---|---|
| `libs/diff.sh` | `_DIFF_SH_DIR` → `_self_dir` |
| `libs/routing.sh` | `SESSION_LIB`/`DIRS_LIB` → `_self_dir` |
| `libs/package_branch.sh` | `_PB_SCRIPT_DIR` → `_self_dir` |
| `libs/package_diff.sh` | `_PD_SCRIPT_DIR` → `_self_dir` |
| `libs/diff_workflow.sh` | Removed `_DW_SCRIPT_DIR`; switched to `$AGENT_SANDBOX_REPO` |
| `libs/draft_workflow.sh` | Removed inline `$(cd...)` (×3); switched to `$AGENT_SANDBOX_REPO` |
| `libs/interactive_session_select.sh` | Removed `_ISS_SCRIPT_DIR`; switched to `$AGENT_SANDBOX_REPO` |
| `scripts/checkpoint.sh` → `libs/checkpoint.sh` | Moved (library misplaced in scripts/) |
| `scripts/start_agent.sh` | Updated checkpoint.sh source path → `libs/checkpoint.sh` |
| `tests/test_checkpoint.sh` | Updated checkpoint.sh source path → `libs/` |
| `tests/test_diff_dispatch.sh` | Added `SCRIPT_DIR`+`REPO_ROOT`; switched from inline `$(cd...)` to `$REPO_ROOT` |
| `tests/test_diff_helpers.sh` | Same |
| `tests/test_diff_workflow.sh` | Added `REPO_ROOT`+`AGENT_SANDBOX_REPO`; switched from `$SCRIPT_DIR/../` to `$REPO_ROOT` |
| `tests/test_dirs.sh` | Added `REPO_ROOT`; switched from `$SCRIPT_DIR/../` to `$REPO_ROOT` |
| `tests/test_draft_workflow.sh` | Added `REPO_ROOT`+`AGENT_SANDBOX_REPO`; switched from `$SCRIPT_DIR/../` to `$REPO_ROOT` |
| `tests/test_interactive_session_select.sh` | Same |
| `tests/test_package_branch.sh` | Added `SCRIPT_DIR`+`REPO_ROOT`; switched from inline `$(cd...)` to `$REPO_ROOT` |
| `tests/test_package_diff.sh` | Same |
| `tests/test_provider_entrypoint.sh` | Added `REPO_ROOT`; switched from `$SCRIPT_DIR/../` to `$REPO_ROOT` |
| `tests/test_routing.sh` | Added `REPO_ROOT`; switched from `$SCRIPT_DIR/../` to `$REPO_ROOT` |
| `tests/test_session.sh` | Same |

## Deferred items

| Item | Reason |
|---|---|
| File moves to `src/`, `build/`, `scripts/workflows/` directories | Mechanism cleanup done; actual file moves deferred to a separate impl session |
| Container-side path changes | Container-side `/opt/sandbox/lib/` paths unchanged; will update COPY sources when files move |
| Dockerfile COPY paths | Sources haven't moved yet; COPY paths stay as-is |

## Next session

Sub-milestone: M2.7 — Session Identity and Harness Versioning

**Conclusions from this session:**
- All 6 self-resolution variable names standardised to `_self_dir` (was `_DIFF_SH_DIR`, `_PB_SCRIPT_DIR`, `_PD_SCRIPT_DIR`, `_DW_SCRIPT_DIR`, `_ISS_SCRIPT_DIR`, `SESSION_LIB`, `DIRS_LIB`)
- Host-only libs now source dependencies via `$AGENT_SANDBOX_REPO` (was self-resolution)
- All test files now use `$REPO_ROOT` to source libs (was mixed: `$SCRIPT_DIR/../libs/`, inline `$(cd...)`, `$REPO_ROOT`)
- `checkpoint.sh` moved from `scripts/` to `libs/` (was misplaced — it's a library)
- Final verification: 330 tests pass, 0 fail, 7 skipped
