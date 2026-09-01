# Agent Handover

**Session date:** 2026-08-01
**Milestone:** M2.6.5 — Copy Model: Volume-backed Sandbox
**Session type:** Implementation — Confirm savepoint and atomic reject
**Status:** Closed

**Note:** This commit closes M2.6.5 (Copy Model: Volume-backed Sandbox). Will reopen if issues surface during live use. Preliminary testing OK.

## Objective

Add rollback safety to `make confirm` and make `make reject` atomic. `confirm` uses a savepoint tag (same pattern as `draft.sh`) to recover from mid-rebase failures. `reject` uses `&&` chaining so checkout+delete is all-or-nothing.

## Scope

Two units:

1. **`confirm` savepoint tag** — Tag `confirm-savepoint` before dropping `.draft-state` commit. On failure at either rebase step, reset to savepoint and clean up. On success, delete tag.

2. **`reject` atomic** — Chain `git checkout && git branch -D` with `&&` instead of sequential commands. No savepoint needed.

## Design

Both mechanisms use the same savepoint tag pattern proven in `draft.sh`: local tags created before the risky operation, rolled back to on failure, deleted on success. Local tags are never pushed by default git push — no remote pollution.

### confirm savepoint

```
confirm_run:
  1. git tag confirm-savepoint              # savepoint — tag current HEAD
  2. Drop .draft-state commit (rebase --onto)
     on failure: git reset --hard confirm-savepoint && git tag -d confirm-savepoint && return 1
  3. Rebase onto target
     on failure: git rebase --abort && git reset --hard confirm-savepoint && git tag -d confirm-savepoint && return 1
  4. Fast-forward merge
  5. Delete draft branch
  6. git tag -d confirm-savepoint           # success — clean up
```

### reject atomic

`reject` doesn't need a savepoint. The two operations (`checkout` + `branch -D`) are chained with `&&` — if checkout fails, nothing changed. If checkout succeeds, branch delete is guaranteed (the branch exists by prior validation). No partial state possible.

```
reject_run:
  1. git checkout "$source_branch" && git branch -D "$CURRENT_BRANCH"
```

## Acceptance criteria

| 1 | `confirm` tags savepoint, resets on rebase failure at either step, deletes tag on success | Manual: trigger rebase conflict, verify rollback | |
| 2 | `confirm` cleans up savepoint tag on success (tag not left behind) | Manual: successful confirm, verify no `confirm-savepoint` tag | |
| 3 | `reject` checkout failure leaves user on draft branch (no partial state) | Manual: create dirty working tree, run reject, verify still on draft | |
| 4 | `reject` success deletes draft branch and returns to source | Manual: clean reject, verify on source branch, draft deleted | |

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/workflows/confirm.sh`](../../scripts/workflows/confirm.sh) | Add savepoint tag logic |
| [`scripts/workflows/reject.sh`](../../scripts/workflows/reject.sh) | Make checkout+delete atomic with `&&` |

## Decisions made this session

None.

## Mid-session findings

None.

## Completed this session

| File | Change |
|---|---|
| [`devlog/discussions/design_apply_draft_workflow.md`](../../devlog/discussions/design_apply_draft_workflow.md) | New — unified design doc: export pipeline, channels, commands, file map |
| [`docs/adr/diff_packaging.md`](../../docs/adr/diff_packaging.md) | New — ADR: command rationale, package-diff removal, savepoint rollback |
| `devlog/discussions/design_apply_workflow_and_baseline_advancement.md` | Deleted — superseded |
| `devlog/discussions/design_diff_and_branch_packaging_workflow.md` | Deleted — superseded |
| `devlog/discussions/design_remove_package_diff.md` | Deleted — absorbed into ADR |
| [`docs/concepts/sandbox_host_correspondence_model.md`](../../docs/concepts/sandbox_host_correspondence_model.md) | Updated design doc references |
| [`docs/development/project_index.md`](../../docs/development/project_index.md) | Updated design doc reference |

## Deferred items

None.

## Next session

**Sub-milestone:** M2.6.5 — Copy Model: Volume-backed Sandbox (close after testing)

**Conclusions from this session:** TBD
