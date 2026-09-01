# Agent Handover

**Date:** 2026-05-28
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Impl
**Status:** Closed

## Objective

Add case-insensitive filesystem detection to the snapshot pipeline. When a file's tree-object name differs from its filesystem name in case only (common on Windows/macOS hosts that run case-sensitive Linux containers), the pipeline should warn the operator with the exact files and a fix command. This prevents the silent "dirty working tree on container start" issue diagnosed in Case 6 of `story-patch_application_failures.md`.

## Scope

- `src/capability/snapshot.sh` — add `snapshot_check_case_mismatch(SOURCE_DIR)` that compares `git ls-tree HEAD` filenames to filesystem filenames for tracked files with same blob hash but different case. Called from `snapshot_archive_head` (host-side, pre-tar) and `snapshot_init_git` (container-side, post-rsync). Writes findings to stderr with the fix command shown to the operator.
- `devlog/discussions/story-patch_application_failures.md` — update Case 6 status to note detection was added.

**Not in scope:**
- Switching `git archive HEAD` to filesystem-based tar (content integrity vs case — value judgment deferred)
- Any other pipeline changes

## Carried forward

None.

## Acceptance criteria

| # | Criterion |
|---|---|
| 1 | `snapshot_check_case_mismatch` warns stderr when a tracked file's tree name and filesystem name differ by case only, including the specific files and the fix command |
| 2 | `snapshot_archive_head` calls the check before producing `baseline.tar` |
| 3 | `snapshot_init_git` calls the check after the rsync overlay |
| 4 | Case 6 status updated to note detection was implemented |
| 5 | Existing tests pass — no regression |
| 6 | Warning is non-blocking — snapshot still proceeds |

## Decisions made this session

None.

## Mid-session findings

None.

## Completed this session

| File | Change summary |
|---|---|
| `src/capability/snapshot.sh` | Added `snapshot_check_case_mismatch()` — compares `git ls-tree HEAD` filenames to filesystem via `find -iname`, warns on case mismatch with same blob. Hooked into `snapshot_archive_head` (host-side) and `snapshot_init_git` (container-side). Non-blocking. |
| `devlog/discussions/story-patch_application_failures.md` | Updated Case 6 with detection being implemented. |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Keep `git archive HEAD` (not filesystem tar) | Filesystem tar would leak unstaged working tree changes into baseline.tar. `git archive` preserves committed content. Detection adds safety without compromising content integrity. | Chat (2026-05-28) |
| Detection is non-blocking (echo only) | The case mismatch is a visibility issue, not a data integrity issue. The content is correct. The warning educates the operator without halting the pipeline. | Chat (2026-05-28) |

## Deferred items

None.

## Next session

M2.7 — remaining M2.7 tasks.

**Conclusions from this session:**
- `snapshot_check_case_mismatch` added to detect case-only filename differences between git tree and filesystem
- Wired into both host-side and container-side snapshot pipeline stages
- Non-blocking warning with exact fix command shown to operator
- All 384 tests pass, 0 failed
