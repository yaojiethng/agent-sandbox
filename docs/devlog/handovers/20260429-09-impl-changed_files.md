# Handover — 2026-04-29 — A.4: changed-files Separate Operation

## Status

Closed

## Scope

Extract the inline `changed-files/` copy logic from `libs/package_diff.sh` into a shared `write_changed_files` function in `libs/diff.sh`, parameterized by `SINCE_SHA`. Wire it into both the `package_branch` dispatcher (uses `INIT_SHA`) and `package_diff.sh` (uses `HEAD`). Update architecture docs. No operator-visible behaviour change.

## Outcome

All implementation complete and verified:

- `libs/diff.sh`: new `write_changed_files(SANDBOX_DIR, SINCE_SHA, OUTPUT_DIR)` — two-source file list, deduplication via `sort -u`, working tree copies preserving structure, deleted files skipped, empty cleanup
- `libs/package_branch.sh`: dispatcher now calls `write_changed_files` after `package_commits` + `write_uncommitted_diff` + `write_all_changes_diff`; sources `diff.sh` at top level
- `libs/package_diff.sh`: replaced inline 3-source copy logic with single `write_changed_files` call using `HEAD`
- `tests/test_package_branch.sh`: 4 new tests (manifest, copies, uncommitted, dedup) — all pass
- `tests/test_package_diff.sh`: 3 new tests (manifest, copies, untracked) — all pass
- Architecture docs: `execution_model.md`, `sandbox_lifecycle.md`, `design_diff_and_branch_packaging_workflow.md` updated to describe `changed-files/`
- `docs/devlog/roadmap.md`: A.4 marked complete
- `docs/devlog/changelog.md`: A.4 entry added

Test results: 241 passed, 0 failed, 1 skipped.

## Remaining Work

- **Session B — Interactive confirmation flag** (`docs/devlog/handovers/20260429-08-design-b_interactive.md` — Status: Active, deferred to next session)
  - Add `interactive_select_sessions` utility for `draft`
  - Add interactive confirmation prompt for `apply`
  - Wire `--interactive` into `agent-sandbox.sh`
  - Support pre-filled default from `SESSION=<name>`
  - Add `INTERACTIVE=1` Makefile flag
  - Tests for confirmation proceeds, rejection aborts, file list matches

## Files Changed

- `libs/diff.sh` — added `write_changed_files` function + updated function list in header
- `libs/package_branch.sh` — dispatcher calls `write_changed_files`; sources `diff.sh`
- `libs/package_diff.sh` — replaced inline copy logic with `write_changed_files` call
- `tests/test_package_branch.sh` — 4 new changed-files tests
- `tests/test_package_diff.sh` — 3 new changed-files tests
- `docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md` — documented `write_changed_files` contract
- `docs/architecture/execution_model.md` — added `changed-files/` to directory tree
- `docs/architecture/sandbox_lifecycle.md` — added `changed-files/` to output layout
- `docs/devlog/roadmap.md` — A.4 marked complete
- `docs/devlog/changelog.md` — A.4 entry added

## Handoff Notes

Session B (`--interactive`) is the next item in the M2.3 queue. The design document (`20260429-08-design-b_interactive.md`) is already created and active. The operator should confirm scope at next session open.
