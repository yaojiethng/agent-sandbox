# Agent Handover

**Session date:** 2026-04-28
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Closed

## Objective
Execute Changes 1, 2, 3, and 4 from the apply_workspace refactor spec on top of current repo state.

## Scope
Changes 1–4 from `docs/devlog/discussions/spec_apply_workspace_refactor.md`:

- **Change 1** — Extract shared test fixtures (`tests/libs/git_fixtures.sh`, `tests/libs/session_fixtures.sh`); update `tests/test_package_branch.sh` and `tests/test_package_diff.sh` to source them.
- **Change 2** — Write `libs/session.sh` with `validate_project_dir` and `resolve_session_dir`; write `tests/test_session.sh` with cases for both functions.
- **Change 3** — Write `libs/draft_workflow.sh` (absorb `libs/draft.sh`; implement `draft_run`, `confirm_run`, `reject_run`); write `tests/test_draft_workflow.sh` covering the full draft/confirm/reject pipeline.
- **Change 4** — Write `libs/diff_workflow.sh` with `apply_run`; write `tests/test_diff_workflow.sh` covering the full apply pipeline.

No changes to existing entry points (`agent-sandbox.sh`, `apply_workspace.sh`).

## Execution plan — Tasks A through E

### Task A — Recreate shared test fixtures (Change 1)
1. Write `tests/libs/git_fixtures.sh` — canonical `make_committed_repo`, `get_init_sha`, `commit_change`
2. Write `tests/libs/session_fixtures.sh` — `make_export_with_diffs`, `make_diffs_session`, `make_changes_session`
3. Update `tests/test_package_branch.sh` — source `git_fixtures.sh`, remove local `make_sandbox`
4. Update `tests/test_package_diff.sh` — source `git_fixtures.sh`, remove local `make_sandbox`
5. Verify both test files pass with unchanged baselines

### Task B — Write `libs/session.sh` + tests (Change 2)
1. Write `libs/session.sh` with `validate_project_dir` and `resolve_session_dir`
2. Write `tests/test_session.sh` with 12 cases (4 validate + 8 resolve)
3. Run `test_session.sh` clean

### Task C — Write `libs/draft_workflow.sh` (Change 3, part 1)
1. Read `libs/draft.sh` and draft/confirm/reject blocks in `scripts/apply_workspace.sh`
2. Write `libs/draft_workflow.sh` absorbing all `libs/draft.sh` functions
3. Implement `draft_run`, `confirm_run`, `reject_run` matching current behaviour
4. Syntax-check the file

### Task D — Write `tests/test_draft_workflow.sh` (Change 3, part 2)
1. Write test file sourcing `git_fixtures.sh`, `session_fixtures.sh`, `draft_workflow.sh`
2. Use **synthetic diffs** (`make_export_with_diffs`) for all cases except:
   - `test_draft_resets_author_to_operator` — needs `make_real_session` with distinct sandbox identity
   - `test_draft_commit_messages` — needs `make_real_session` to verify exact commit messages
3. Do **not** test session resolution in workflow tests — `resolve_session_dir` unit tests in `test_session.sh` cover that
4. Port draft/confirm/reject cases from `test_apply_workspace.sh` and `test_apply.sh`
5. Run `test_draft_workflow.sh` clean

### Task E — Write `libs/diff_workflow.sh` + `tests/test_diff_workflow.sh` (Change 4)
1. Read apply block in `scripts/apply_workspace.sh`
2. Write `libs/diff_workflow.sh` with `apply_run` matching current behaviour
3. Write `tests/test_diff_workflow.sh` covering all 18 apply cases from `test_apply_workspace.sh`
4. Run `test_diff_workflow.sh` clean

## Carried forward
None.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | `tests/libs/git_fixtures.sh` exists with `make_committed_repo` | ✓ Accepted |
| 2 | `tests/libs/session_fixtures.sh` exists with session-structure helpers | ✓ Accepted |
| 3 | `test_package_branch.sh` sources `git_fixtures.sh`, no local `make_sandbox`, all tests pass | ✓ Accepted |
| 4 | `test_package_diff.sh` sources `git_fixtures.sh`, no local `make_sandbox`, baseline preserved | ✓ Accepted |
| 5 | `libs/session.sh` exists with `validate_project_dir` and `resolve_session_dir` per spec | ✓ Accepted |
| 6 | `tests/test_session.sh` exists covering all required cases for both functions | ✓ Accepted |
| 7 | `bash -n` passes on all new files; `test_session.sh` passes clean | ✓ Accepted |
| 8 | `libs/draft_workflow.sh` exists with all `libs/draft.sh` functions plus `draft_run`, `confirm_run`, `reject_run` | ✓ Accepted |
| 9 | `tests/test_draft_workflow.sh` exists covering full draft/confirm/reject pipeline | ✓ Accepted |
| 10 | `test_draft_workflow.sh` passes clean | ✓ Accepted |
| 11 | `libs/diff_workflow.sh` exists with `apply_run` matching current apply block behaviour | ✓ Accepted |
| 12 | `tests/test_diff_workflow.sh` exists covering full apply pipeline | ✓ Accepted |
| 13 | `test_diff_workflow.sh` passes clean | ✓ Accepted |

## Hot files
| File | Why in scope |
|---|---|
| [`scripts/apply_workspace.sh`](scripts/apply_workspace.sh) | Read-only — source of truth for extraction |
| [`libs/draft.sh`](libs/draft.sh) | Read-only — source of truth for absorption |
| [`scripts/agent-sandbox.sh`](scripts/agent-sandbox.sh) | Read-only — verify current source calls |
| [`tests/test_apply.sh`](tests/test_apply.sh) | Read-only — coverage map baseline |
| [`tests/test_apply_workspace.sh`](tests/test_apply_workspace.sh) | Read-only — coverage map baseline |
| [`docs/devlog/discussions/spec_apply_workspace_refactor.md`](docs/devlog/discussions/spec_apply_workspace_refactor.md) | Spec reference |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| `draft_workflow.sh` sources `session.sh` via inline path, not `SCRIPT_DIR` variable | Avoids `SCRIPT_DIR` variable collision with test file | `libs/draft_workflow.sh` line 8 |
| `diff_workflow.sh` sources `session.sh` via inline path, same pattern as `draft_workflow.sh` | Consistency; avoids `SCRIPT_DIR` collision | `libs/diff_workflow.sh` line 8 |
| Synthetic diffs for all draft tests except author rewrite and commit messages | Operator guidance: only those two cases need real git-generated diffs | This handover — Task D |
| Session resolution not tested in workflow tests | Operator guidance: `resolve_session_dir` unit tests cover that; workflow tests pass explicit paths | This handover — Tasks D/E |
| `make_real_session` defined locally in `test_draft_workflow.sh` | Only used by 2 tests; keeps `session_fixtures.sh` focused on synthetic helpers | `tests/test_draft_workflow.sh` |
| Test fixture directory renamed `tests/lib/` → `tests/libs/` | `.gitignore` has `lib/` for Linux executable convention; `libs/` avoids silent ignore | This handover |
| Closed handover `20260427-04-design` edited for rename | Operator explicitly overrode handover policy to propagate rename to all docs | This handover |

## Completed this session

| File | Change |
|---|---|
| `tests/libs/git_fixtures.sh` | New — canonical `make_committed_repo`, `get_init_sha`, `commit_change` |
| `tests/libs/session_fixtures.sh` | New — `make_export_with_diffs`, `make_diffs_session`, `make_changes_session` |
| `tests/test_package_branch.sh` | Sources `git_fixtures.sh`; local `make_sandbox`/`get_init_sha`/`commit_change` removed |
| `tests/test_package_diff.sh` | Sources `git_fixtures.sh`; local `make_sandbox`/`get_init_sha` removed |
| `libs/session.sh` | New — `validate_project_dir`, `resolve_session_dir` per spec |
| `tests/test_session.sh` | New — 12 test cases, all passing (4 validate + 8 resolve) |
| `libs/draft_workflow.sh` | New — absorbs `libs/draft.sh` functions; implements `draft_run`, `confirm_run`, `reject_run` |
| `tests/test_draft_workflow.sh` | New — 23 test functions, 29 assertions, all passing |
| `libs/diff_workflow.sh` | New — `apply_run` with session resolution, flat/session/autosave fallback, branch checkout, force mode |
| `tests/test_diff_workflow.sh` | New — 18 test cases, 19 assertions, all passing |

## Deferred items

| Item | Reason | Next destination |
|---|---|---|
| Change 5 — Switch `agent-sandbox.sh` to call workflow libs | Depends on Changes 2–4 | Next session |
| Change 6 — Patch remaining `apply_workspace.sh` callers | Depends on Change 5 | Following session |
| Change 7 — Delete old files | Depends on Change 6 | Following session |
| `SESSION_STATE` file / `$SESSION_TS` persistence bug | Not in scoped task group | M2.3 roadmap — pending |
| `package-branch` skill amendments | Depends on `SESSION_STATE` | M2.3 roadmap — pending |
| Interactive confirmation flag | Not in scoped task group | M2.3 roadmap — pending |

## Next session

**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Task:** Change 5 — Switch `agent-sandbox.sh` to call workflow libs directly

Read `scripts/agent-sandbox.sh` before editing — specifically the `source` calls at the top and the `apply`, `draft`, `confirm`, `reject` case branches. Add source calls for `libs/draft_workflow.sh` and `libs/diff_workflow.sh`. Replace each case branch with a direct call to the corresponding `*_run` function. Do not change flag parsing.

**Files to read at session start:**
- `scripts/agent-sandbox.sh` — source calls and case branches
- `docs/devlog/discussions/spec_apply_workspace_refactor.md` — Change 5 spec

**Watch-outs:**
- Confirm every flag each branch currently passes to `apply_workspace.sh` is present in the corresponding `*_run` parameter list
- `apply_workspace.sh` must remain functional as rollback path
- Manual end-to-end verification of each subcommand required before Change 5 is considered complete
