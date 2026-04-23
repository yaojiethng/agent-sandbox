# Agent Handover

**Session date:** 2026-04-23
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Closed

## Objective

Implement Unit D (`make apply` update) — add `DIFF=<path>` argument to allow applying a specific diff file.

## Scope

**Unit D tasks (from roadmap):**
- Add `DIFF=<path>` argument to `make apply`
- Remove pre-staging block (already removed in prior implementation)
- Preserve default resolution (latest `.diff` in `workspace/output/diffs/` by timestamp)

**Files to change:**
- `scripts/apply_workspace.sh` — add `--diff=` flag parsing and logic to use explicit diff path
- `libs/_templates/Makefile.template` — add `DIFF` variable to apply target
- `tests/test_apply_workspace.sh` — add tests for `DIFF=` argument and update existing tests for new `diffs/` structure

## Carried forward

None.

## Acceptance criteria

| Criterion | Status |
|---|---|
| `make apply DIFF=<path>` applies a specific diff file | ✓ Accepted |
| `make apply` (no args) finds and applies latest diff by timestamp | ✓ Accepted |
| Applied diff has no `index` lines | ✓ Accepted |
| Tests pass for Unit D changes | ✓ Accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/apply_workspace.sh`](scripts/apply_workspace.sh) | Add `--diff=` flag and explicit diff path logic |
| [`libs/_templates/Makefile.template`](libs/_templates/Makefile.template) | Add `DIFF` variable to apply target |
| [`tests/test_apply_workspace.sh`](tests/test_apply_workspace.sh) | Add tests for `DIFF=` argument |

## Decisions made this session

None.

## Completed this session

| File | Change summary |
|---|---|
| `scripts/apply_workspace.sh` | Added `DIFF_ARG` variable, `--diff=` flag parsing, and logic to use explicit diff path when provided |
| `libs/_templates/Makefile.template` | Added `DIFF` variable to apply target |
| `tests/test_apply_workspace.sh` | Added 3 new tests for Unit D; updated 8 existing APPLY tests for new `diffs/` structure |

## Deferred items

None.

## Next session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline.
**Session type:** Implementation — Unit E (`make draft` redesign).

Read `docs/devlog/roadmap.md` M2.3 pending section for Unit E tasks.

**Watch-outs:**
- `package_diff.sh` output now in `workspace/output/diffs/` — all subsequent units should use this path
- `diff_on_exit` now captures uncommitted changes to `workspace/session-diffs/<session-name>/changes.diff`
- Script naming: `package_diff.sh` and `package_branch.sh` (underscores); `package-diff` (dash) only in prompt template

**Grep to run:** `grep -r "DIFFS_DIR" scripts/apply_workspace.sh` — verify all paths updated to use `diffs/` subfolder.
