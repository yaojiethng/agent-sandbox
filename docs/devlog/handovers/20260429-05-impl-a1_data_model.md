# Agent Handover

**Session date:** 2026-04-29
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Closed

## Outcome

All acceptance criteria met. `scripts/run_tests.sh` exits 0 (245 passed, 0 failed, 1 skipped — Docker-unavailable skip in `test_capability_layer.sh`).

## Completed this session

| File | Change |
|---|---|
| `libs/session.sh` | Added `session_state_write` function for in-place SESSION_STATE updates |
| `libs/snapshot.sh` | `snapshot_init_git` writes `session_ts` + `init_sha` to `SESSION_STATE`; dropped `.git/INIT_SHA` file creation |
| `libs/sandbox-entrypoint.sh` | Removed `BASELINE_SHA` variable; updated trap/autosave calls to match new signatures |
| `libs/diff.sh` | Removed `diff_commit_pending` and sweep commit logic; added `write_uncommitted_diff` (git diff HEAD with untracked staging) and `write_all_changes_diff` (git diff INIT_SHA with untracked staging); renamed `BASELINE_SHA` → `since_sha`; rewrote `diff_on_exit` and `diff_on_autosave` as thin dispatchers calling `package_branch` |
| `libs/package_branch.sh` | Extracted `package_commits` from old `package_branch` logic; rewrote `package_branch` as dispatcher orchestrating `package_commits` + `write_uncommitted_diff` + `write_all_changes_diff`; reads `init_sha` from `SESSION_STATE` |
| `libs/package_diff.sh` | Renamed `changes.diff` → `uncommitted.diff`; removed `--baseline` flag and `resolve_baseline` function; simplified to `git diff HEAD` |
| `tests/test_diff.sh` | Updated 41 tests: removed `diff_commit_pending` tests, renamed assertions for `uncommitted.diff`/`all-changes.diff`, added `SESSION_STATE` setup, verified `patches/` subfolder, verified no sweep |
| `tests/test_snapshot_container.sh` | Replaced `INIT_SHA` test with `SESSION_STATE` test (verifies `init_sha`, `session_ts`, and absence of `INIT_SHA` file) |
| `tests/test_package_branch.sh` | Updated 13 tests for dispatcher pattern: `patches/` subfolder, `uncommitted.diff`, `all-changes.diff`, `package_commits` extraction |
| `tests/test_package_diff.sh` | Updated 12 tests for `uncommitted.diff` rename and `SESSION_STATE` fallback |

## Decisions made this session

- **Confirmed A.1 boundary:** No CLI changes, no user-visible behaviour change. Output paths changed under the hood only.
- **Untracked file handling in all-changes.diff:** Both `write_uncommitted_diff` and `write_all_changes_diff` stage untracked files via `git add -N` before generating diff, then restore staged state after. Ensures untracked files appear in output without permanently staging them.
- **`git diff INIT_SHA` not `INIT_SHA..HEAD`:** `all-changes.diff` uses `git diff INIT_SHA` (not range syntax) so uncommitted changes are included alongside committed changes.

## Mid-session findings

- `test_diff.sh` initially failed because `git diff INIT_SHA..HEAD` does not include untracked files even after `git add -N`. Root cause: `INIT_SHA..HEAD` range syntax compares two explicit refs; untracked files are not reachable from either ref. Fixed by using `git diff INIT_SHA` (diff between ref and working tree) instead.

## Acceptance criteria verification

| # | Criterion | Status |
|---|---|---|
| 1 | `scripts/run_tests.sh` exits 0 | ✅ 245 passed, 0 failed |
| 2 | `SESSION_STATE` contains `session_ts` and `init_sha` | ✅ `test_snapshot_container.sh` |
| 3 | `INIT_SHA` file not created | ✅ `test_snapshot_container.sh` |
| 4 | `diff_on_exit` produces correct files, no sweep | ✅ `test_diff.sh` |
| 5 | `diff_on_autosave` produces correct files | ✅ `test_diff.sh` |
| 6 | `package_branch` dispatcher writes unified format | ✅ `test_package_branch.sh` |
| 7 | `package_diff.sh` writes `uncommitted.diff` | ✅ `test_package_diff.sh` |

## Objective

Execute the A.1 design: unify packaging output format, consolidate SESSION_STATE, remove sweep commit, and update tests.

## Scope

A.1 implementation — data model and output format unification. All tasks completed.

## Carried forward

| Item | From handover |
|---|---|
| Interactive confirmation flag (`--interactive` for `make apply` and `make draft`) | 20260429-03-design-command_shape_and_contract.md |

## Acceptance criteria

1. `scripts/run_tests.sh` exits 0. All tests pass including updated assertions for the new output format.
2. `sandbox/.git/SESSION_STATE` contains `session_ts` and `init_sha` keys after `snapshot_init_git` runs.
3. `sandbox/.git/INIT_SHA` is not created by `snapshot_init_git`.
4. `diff_on_exit` produces `session/uncommitted.diff`, `session/all-changes.diff`, and `session/patches/*.diff` — no `session/changes.diff`, no `session/staged.diff`, no sweep commit.
5. `diff_on_autosave` produces `autosave/uncommitted.diff`, `autosave/patches/*.diff` — no `autosave/changes.diff`.
6. `package_branch` dispatcher writes `patches/*.diff` under a `patches/` subfolder, plus `uncommitted.diff` and `all-changes.diff` at the parent level.
7. `package_diff.sh` writes `uncommitted.diff` (not `changes.diff`).

## Hot files

| File | Why in scope |
|---|---|
| [`libs/snapshot.sh`](libs/snapshot.sh) | `snapshot_init_git` — add SESSION_STATE write |
| [`libs/sandbox-entrypoint.sh`](libs/sandbox-entrypoint.sh) | Drop BASELINE_SHA variable |
| [`libs/diff.sh`](libs/diff.sh) | `diff_on_exit`, `diff_on_autosave`, new helpers, param rename |
| [`libs/package_branch.sh`](libs/package_branch.sh) | Dispatcher rewrite |
| [`libs/package_diff.sh`](libs/package_diff.sh) | Rename `changes.diff` → `uncommitted.diff` |
| [`libs/session.sh`](libs/session.sh) | Add `session_state_write` |
| [`tests/test_diff.sh`](tests/test_diff.sh) | Remove `diff_commit_pending` tests |
| [`tests/test_snapshot_container.sh`](tests/test_snapshot_container.sh) | Update INIT_SHA assertions |
| [`tests/test_package_branch.sh`](tests/test_package_branch.sh) | Update for `patches/` subfolder |
| [`tests/test_package_diff.sh`](tests/test_package_diff.sh) | Update for `uncommitted.diff` rename |

## Decisions made this session

None yet.

## Mid-session findings

None yet.

## Completed this session

None yet.

## Deferred items

| Item | Reason | Next destination |
|---|---|---|
| A.2 implementation | Blocked on A.1 | Session after A.1 closes |
| A.3 implementation | Blocked on A.1 + A.2 | Session after A.2 closes |
| Session B: `--interactive` | Blocked on A.1 + A.2 + A.3 | Session after A.3 closes |

## Next session

TBD at session close.
