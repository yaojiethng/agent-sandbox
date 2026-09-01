# Agent Handover

**Date:** 2026-06-22
**Milestone:** M2.6 — Session Resume and Mount Model Redesign
**Type:** Implementation
**Status:** Closed

## Objective

Add autosave and session-save behaviour checks to the capability layer dry-run, so Phase 2 (mount model redesign) regressions are detected at dry-run time.

## Scope

P1-A adjunct — add three new check groups to `scripts/dry_run_capability.sh`:

1. **`.export-status` verification** — after the existing `diff_export` test, assert `.export-status` exists with `STATUS=SUCCESS`
2. **Autosave infrastructure** — verify `CHANGES_DIR/autosave/` directory exists; verify `session_export_path` resolves correctly; verify `wait_git_lockfile` returns quickly when no lockfile
3. **No changes to compose overlay, orchestration, or test files**

## Completed this session

| File | Change |
|---|---|
| `scripts/dry_run_capability.sh` | Added 3 new checks: `.export-status` SUCCESS after diff pipeline, autosave dir existence + `session_export_path` resolution + `wait_git_lockfile` no-lockfile check |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | `.export-status` checked after diff pipeline test | grep for `.export-status` in `scripts/dry_run_capability.sh` | ✅ |
| 2 | Autosave directory existence checked | grep for "CHANGES_DIR/autosave/" in `scripts/dry_run_capability.sh` | ✅ |
| 3 | `session_export_path` resolution checked when env vars available | grep for "session_export_path" in `scripts/dry_run_capability.sh` | ✅ |
| 4 | `wait_git_lockfile` checked for clean-repo path | grep for "wait_git_lockfile" in `scripts/dry_run_capability.sh` | ✅ |
| 5 | `bash -n` passes on changed file | `bash -n scripts/dry_run_capability.sh` exits 0 | ✅ |
| 6 | Existing tests still pass | `bash scripts/run_tests.sh` exits 0 | ✅ |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Checks added to `dry_run_capability.sh` rather than a new file | Follows existing pattern for capability layer investigation checks | This handover |
| Autosave dir check is WARN not CRITICAL | Dir is created by entrypoint at startup, not by dry-run — absence indicates sequencing issue but doesn't block dry-run | This handover |

## Mid-session findings

None.

## Deferred items

None.

## Next session

**Milestone:** M2.6 — Session Resume and Mount Model Redesign

P1-B — Security model update: Rewrite `docs/architecture/security.md` invariants to reflect the user-choice mount model. Close `story_agent_state_persistence.md`, `story_agent_git_surface.md`, `security_delta_worktree_model.md`, and `story_container_layer_model.md` with Resolution sections.
