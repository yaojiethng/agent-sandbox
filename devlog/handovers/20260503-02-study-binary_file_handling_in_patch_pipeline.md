# Agent Handover

**Date:** 2026-05-03
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Type:** Implementation
**Status:** Closed

## Objective

Investigate and resolve the binary file handling gap in `package_branch.sh` and `package_diff.sh`: when a binary file is tracked, the `grep -v '^index '` filter strips the required index line from binary diffs, causing `git apply` to fail. Fix implemented: `git diff --binary` + selective index-line stripping via awk.

## Scope

Investigate and fix the binary file handling gap in `package_branch.sh` and `package_diff.sh`.

Carried from previous session ([`20260503-01-impl-remove_snapshot_copy_to_sandbox.md`](20260503-01-impl-remove_snapshot_copy_to_sandbox.md), Mid-session findings).

## Carried forward

| Item | From handover |
|---|---|
| Binary file handling in `package_branch.sh`/`package_diff.sh` — `grep -v '^index '` strips required metadata for binary diffs | `20260503-01-impl-remove_snapshot_copy_to_sandbox.md` |

## Acceptance criteria

Not yet defined.

## Hot files

| File | Why in scope |
|---|---|
| [`libs/package_branch.sh`](../../libs/package_branch.sh) | Line 78: `grep -v '^index '` filter strips binary index lines |
| [`libs/package_diff.sh`](../../libs/package_diff.sh) | Line 193: same pattern as package_branch.sh |
| [`tests/knowledge/knowledge_binary_diff_apply.sh`](../../tests/knowledge/knowledge_binary_diff_apply.sh) | Knowledge test documenting git's binary diff/apply behaviour |
| [`docs/development/testing_policy.md`](../../docs/development/testing_policy.md) | Updated to document knowledge test conventions | |

## Decisions made this session

None.

## Mid-session findings

None.

## Completed this session

| File | Change |
|---|---|
| [`tests/knowledge/knowledge_binary_diff_apply.sh`](../../tests/knowledge/knowledge_binary_diff_apply.sh) | Created — 5 sections, 12 assertions documenting git binary diff/apply behaviour |
| [`docs/development/testing_policy.md`](../../docs/development/testing_policy.md) | Added Knowledge Tests section — conventions, purpose, exclusion from test runner |
| [`libs/package_branch.sh`](../../libs/package_branch.sh) | `git diff` → `git diff --binary`; `grep -v '^index '` → selective awk filter (keeps index for binary, strips for text) |
| [`libs/package_diff.sh`](../../libs/package_diff.sh) | Same change as package_branch.sh |
| [`docs/devlog/handovers/20260503-02-study-binary_file_handling_in_patch_pipeline.md`](../../docs/devlog/handovers/20260503-02-study-binary_file_handling_in_patch_pipeline.md) | This handover | |

## Deferred items

None.

## Next session

M2.3 — Apply Workflow: Capability Layer Diff Pipeline.

Blocking design question: none.

Watch-out items:
- The awk filter in `package_branch.sh` and `package_diff.sh` assumes `GIT binary patch` always follows the index line for binary diffs. If git's diff format changes, the knowledge test will catch it.
- `baseline.tar` is still tracked in the project repo itself (pre-existing — see previous session handover). The package pipeline can now handle its deletion correctly.

**Knowledge test created:** `tests/knowledge/knowledge_binary_diff_apply.sh` — 12 assertions, all pass. Documents:
1. Default `git diff` does not produce applyable binary patches (even with index line)
2. `git diff --binary` produces applyable binary patches
3. Index line SHAs can differ between container and host — `git apply` without `--index` ignores them
4. Selective index stripping (keep for binary, strip for text) produces valid patches
5. Binary addition, deletion, and modification all work with this approach

**Context handover:** [`20260503-02-study-binary_file_handling_in_patch_pipeline.md`](20260503-02-study-binary_file_handling_in_patch_pipeline.md) supersedes the residual finding from [`20260503-01-impl-remove_snapshot_copy_to_sandbox.md`](20260503-01-impl-remove_snapshot_copy_to_sandbox.md).

**Conclusions from this session:** (to be filled)
