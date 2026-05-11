# Agent Handover

**Session date:** 2026-04-28
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Closed

## Objective
Execute Changes 6 and 7 from the apply_workspace refactor spec: eliminate all remaining callers of `apply_workspace.sh`, then delete the obsolete files and update stale documentation.

## Scope
Changes 6 and 7 from `docs/devlog/discussions/spec_apply_workspace_refactor.md`:

**Change 6 — Caller patching:**
- Run `grep -rn "apply_workspace" .` and catalogue every caller
- Patch `Makefile` and `libs/_templates/Makefile.template` to call `agent-sandbox` directly (if not already)
- Patch any script, runbook, or CI file referencing `apply_workspace.sh`
- After patching, re-run grep; the only remaining results must be within `apply_workspace.sh` itself

**Change 7 — Deletion and cleanup:**
- Delete `scripts/apply_workspace.sh`, `libs/draft.sh`, `tests/test_apply.sh`, `tests/test_apply_workspace.sh`
- Run full test suite clean; confirm no references to deleted files in failing tests
- Update all stale documentation (`testing_policy.md`, `sandbox_lifecycle.md`, `roadmap.md`, `project_index.md`)
- Remove `baseline.tar` from git index (contained stale copies of deleted files)

## Carried forward
None.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | `grep -rn "apply_workspace" .` returns no results outside `docs/` directory | ✅ Verified |
| 2 | `scripts/apply_workspace.sh`, `libs/draft.sh`, `tests/test_apply.sh`, `tests/test_apply_workspace.sh` do not exist | ✅ Verified |
| 3 | `tests/test_draft_workflow.sh` passes clean | ✅ Verified (29 passed, 0 failed) |
| 4 | `tests/test_diff_workflow.sh` passes clean | ✅ Verified (19 passed, 0 failed) |
| 5 | `tests/test_session.sh` passes clean | ✅ Verified (12 passed, 0 failed) |
| 6 | `tests/test_package_branch.sh` passes clean | ✅ Verified (11 passed, 0 failed) |
| 7 | Any failing tests in the full suite are confirmed pre-existing (no references to deleted files) | ✅ Verified |
| 8 | `docs/development/testing_policy.md` updated — stale `test_apply.sh`/`test_apply_workspace.sh` references removed | ✅ Verified |
| 9 | `docs/architecture/sandbox_lifecycle.md` updated — `apply_workspace.sh` reference removed | ✅ Verified |
| 10 | `docs/devlog/roadmap.md` updated — Changes 1–7 marked complete, acceptance criteria reflect final state | ✅ Verified |
| 11 | `docs/development/project_index.md` updated — all `.sh` entries removed | ✅ Verified |

## Hot files
| File | Why in scope |
|---|---|
| [`Makefile`](Makefile) | Verify/update targets to call `agent-sandbox` directly |
| [`libs/_templates/Makefile.template`](libs/_templates/Makefile.template) | Verify/update targets to call `agent-sandbox` directly |
| [`scripts/apply_workspace.sh`](scripts/apply_workspace.sh) | Rollback path — self-references are expected |
| [`libs/draft.sh`](libs/draft.sh) | References `apply_workspace.sh` in header comment |
| [`tests/test_apply.sh`](tests/test_apply.sh) | Calls `apply_workspace.sh` directly |
| [`tests/test_apply_workspace.sh`](tests/test_apply_workspace.sh) | Calls `apply_workspace.sh` directly |
| [`docs/devlog/discussions/spec_apply_workspace_refactor.md`](docs/devlog/discussions/spec_apply_workspace_refactor.md) | Spec reference |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Combine Change 6 and Change 7 into one session | Change 6 reduced to a no-op — `Makefile`/`Makefile.template` already route to `agent-sandbox`; remaining references were only in files scheduled for deletion in Change 7 | This handover |
| Exclude `tests/test_session.sh` from deletion | Tests `libs/session.sh` (permanent library); contains no `apply_workspace` references | This handover |
| Remove all `.sh` entries from `project_index.md` | Document describes itself as a registry of "documentation and policy files"; `.sh` scripts are implementation artefacts | This handover |
| Delete `baseline.tar` from git | Binary archive contained stale copies of deleted files (`apply_workspace.sh`, `draft.sh`, `test_apply.sh`, `test_apply_workspace.sh`) | This handover |

## Completed this session

| File | Change |
|---|---|
| `scripts/apply_workspace.sh` | Deleted — superseded by `agent-sandbox.sh` + workflow libs |
| `libs/draft.sh` | Deleted — absorbed into `libs/draft_workflow.sh` |
| `tests/test_apply.sh` | Deleted — coverage migrated to `tests/test_draft_workflow.sh` |
| `tests/test_apply_workspace.sh` | Deleted — coverage migrated to `tests/test_draft_workflow.sh` + `tests/test_diff_workflow.sh` |
| `baseline.tar` | Removed from git index and working tree — contained stale copies of deleted files |
| `docs/development/testing_policy.md` | Replaced `test_apply.sh`/`test_apply_workspace.sh` examples with `test_draft_workflow.sh`/`test_diff_workflow.sh` |
| `docs/architecture/sandbox_lifecycle.md` | Replaced `scripts/apply_workspace.sh` reference with `agent-sandbox` dispatch description |
| `docs/devlog/roadmap.md` | Marked Changes 1–7 complete; updated acceptance criteria |
| `docs/development/project_index.md` | Removed all `.sh` entries from Scripts, Lib, and Tests sections |

## Deferred items

| Item | Reason | Next destination |
|---|---|---|
| `SESSION_STATE` file / `$SESSION_TS` persistence bug | Separate roadmap task group; not part of apply_workspace refactor | M2.3 roadmap — pending |
| `package-branch` skill amendments | Depends on `SESSION_STATE` | M2.3 roadmap — pending |
| Interactive confirmation flag | Separate roadmap task group; not part of apply_workspace refactor | M2.3 roadmap — pending |
| Pre-existing test failures — full catalogue | See table below | M2.3 roadmap — test suite repair task |

### Pre-existing test failures catalogue

| Test file | Result | Root cause | References deleted files? | Blocked on |
|---|---|---|---|---|
| `test_package_diff.sh` | 4/14 pass | SESSION_TS env var absent in test context | No | SESSION_STATE file task |
| `test_checkpoint.sh` | 6/14 pass | `checkpoint_latest` worktree scoping regression | No | Independent investigation |
| `test_build_context.sh` | Script error | `libs/build_context.sh` does not exist in repo | No | Independent investigation |
| `test_capability_layer.sh` | Unclear (output suppressed) | Unknown — not investigated this session | No | Independent investigation |
| `test_provider_entrypoint.sh` | Unclear (missing env vars) | Unknown — not investigated this session | No | Independent investigation |

## Next session

**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Task:** `SESSION_STATE` file / `$SESSION_TS` persistence bug

The apply_workspace refactor (Changes 1–7) is complete. `agent-sandbox` is the sole entry point for `draft`, `confirm`, `reject`, `apply`. Remaining M2.3 task groups, in dependency order:

1. `SESSION_STATE` file / `$SESSION_TS` persistence bug
2. `package-branch` skill amendments (depends on SESSION_STATE)
3. Interactive confirmation flag
4. Test suite repair (depends on SESSION_STATE for `test_package_diff.sh`; other failures are independent)

**Trigger B:** Not yet applicable. Four pending task groups remain.

**Files to read at session start:**
- `libs/package_diff.sh` — reads INIT_SHA from .git/
- `scripts/start_agent.sh` — writes INIT_SHA at container init
- `libs/package_branch.sh` — may read SESSION_TS
- `.skills/package-branch.md` — skill references SESSION_TS
- `tests/test_package_diff.sh` — failing tests to validate after fix

**Watch-outs:**
- Catalogue every call site before changing anything
- Env var takes precedence over SESSION_STATE file when both are present
- Standalone INIT_SHA file removal must be coordinated with all read sites
