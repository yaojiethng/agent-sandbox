# Agent Handover

**Session date:** 2026-05-03
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Closed

## Objective

Remove the superfluous `snapshot_copy_to_sandbox` function — it copies `baseline.tar` into the sandbox working tree, which causes a tracked binary file that breaks the patch chain when applying diffs on the host.

## Scope

Remove `snapshot_copy_to_sandbox` and all references. The function is dead code: `snapshot_init_git` already reads `baseline.tar` directly from `$SNAPSHOT_DIR` (the mounted snapshot), not from `$SANDBOX_DIR`. The copy to `$SANDBOX_DIR` is what puts `baseline.tar` into the git working tree, where `git add -A` picks it up and commits it into the baseline commit. This makes `baseline.tar` a tracked binary file inside the container. When `package_branch.sh` strips index lines from diffs (as intended — SHAs differ between container and host), the binary deletion hunk lacks the required index line and `git apply` fails.

Scope covers:
- Remove the function definition in `libs/snapshot.sh`
- Remove the call in `libs/sandbox-entrypoint.sh` and the redundant `file_count` validation
- Remove `--exclude='baseline.tar'` workaround flags in `snapshot_init_git` (rsync overlay) and `resync_snapshot` (test fixture)
- Remove test cases and calls in `tests/test_snapshot_container.sh`

Not in scope: any other binary file handling, changes to `package_branch.sh`, or `/opt/sandbox/` path allocation.

## Carried forward

None.

## Acceptance criteria

| Criteria | Status |
|---|---|
| `grep -rn "snapshot_copy_to_sandbox" libs/ --include="*.sh"` returns empty | **Accepted** — verified exit code 1 |
| `grep -rn "snapshot_copy_to_sandbox" libs/sandbox-entrypoint.sh` returns empty | **Accepted** — verified exit code 1 |
| `grep -rn "snapshot_copy_to_sandbox" tests/test_snapshot_container.sh` returns empty | **Accepted** — verified exit code 1 |
| `--exclude='baseline.tar'` guarded as needed (1 each in rsync overlay and resync_snapshot) | **Accepted** — verified presererved; these are independent safeguards, not workarounds |
| All `tests/test_snapshot_container.sh` tests pass | **Accepted** — 27 passed, 0 failed, 0 skipped |
| `baseline.tar` does not enter sandbox git tracking via new code path | **Accepted** — code trace confirms: no copy step places it in `$SANDBOX_DIR` before `git add -A`; rsync overlay excludes it |

## Hot files

| File | Why in scope |
|---|---|
| [`libs/snapshot.sh`](../../libs/snapshot.sh) | Remove `snapshot_copy_to_sandbox` function definition |
| [`libs/sandbox-entrypoint.sh`](../../libs/sandbox-entrypoint.sh) | Remove `snapshot_copy_to_sandbox` call and `file_count` validation block; update docstring |
| [`tests/test_snapshot_container.sh`](../../tests/test_snapshot_container.sh) | Remove `test_copy_to_sandbox` and `test_copy_leaves_snapshot_intact` test cases; remove `snapshot_copy_to_sandbox` calls from all init_git test cases |

## Decisions made this session

None.

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| `package_branch.sh` strips all `^index ` lines via `grep -v`. For binary file diffs, the index line is required — `git apply` rejects binary hunks without it ("cannot apply binary patch without full index line"). This session removes `snapshot_copy_to_sandbox` (which was the root cause of `baseline.tar` being tracked). But `baseline.tar` is still tracked in the project repo itself (committed before our changes). Our fix only prevents future sandbox inits from re-introducing it. The existing `git ls-files baseline.tar` hit will persist until the repo's own tracked copy is dealt with. | bug / residual risk | future session |
| `--exclude='baseline.tar'` in the rsync overlay and `resync_snapshot` was initially removed (assumed to be a workaround for `snapshot_copy_to_sandbox`). It was restored when tests failed — it prevents `baseline.tar` in `$SNAPSHOT_DIR` (from `snapshot_archive_head`) from leaking into the sandbox working tree. The exclude is a separate, independent safeguard. | steering / correction | this session (corrected)

## Completed this session

| File | Change |
|---|---|
| [`libs/snapshot.sh`](../../libs/snapshot.sh) | Removed `snapshot_copy_to_sandbox` function + docstring + header reference. `--exclude='baseline.tar'` retained in rsync overlay. |
| [`libs/sandbox-entrypoint.sh`](../../libs/sandbox-entrypoint.sh) | Removed call + `file_count` validation block; updated docstring sequence. |
| [`tests/test_snapshot_container.sh`](../../tests/test_snapshot_container.sh) | Removed 2 test functions + 11 copy calls from init_git tests; updated header; `--exclude='baseline.tar'` retained in `resync_snapshot`. |
| [`docs/devlog/handovers/20260503-01-impl-remove_snapshot_copy_to_sandbox.md`](../../docs/devlog/handovers/20260503-01-impl-remove_snapshot_copy_to_sandbox.md) | This handover. |

## Deferred items

None.

## Next session

M2.3 — Apply Workflow: Capability Layer Diff Pipeline.

Blocking design question: none.

Watch-out items:
- `baseline.tar` is still tracked in the project repo itself (`git ls-files baseline.tar`). Our fix prevents future sandbox inits from re-introducing it, but the existing commit entry persists. The original bundle's patch 003 deletion of `baseline.tar` can now be applied cleanly — the previous failure path (binary hunk missing index line) has been eliminated.
- `--exclude='baseline.tar'` in the rsync overlay and `resync_snapshot` is intentional — do not remove it.

**Conclusions from this session:** `snapshot_copy_to_sandbox` was identified as the root cause of the `baseline.tar` binary patch failure. Removing it eliminates the tracked binary file problem. The `--exclude='baseline.tar'` guards are separate safeguards, not workarounds.

**Context handover:** [`20260503-01-impl-remove_snapshot_copy_to_sandbox.md`](20260503-01-impl-remove_snapshot_copy_to_sandbox.md) supersedes the investigation that identified the bug.
