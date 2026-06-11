# Agent Handover

**Session date:** 2026-04-23
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Closed

## Objective

Implement Unit E (`make draft` redesign) — replace checkpoint-tag-based draft workflow with branch-name-based diff application using `git apply`, add `FROM` and `DIFFS` arguments.

## Scope

**Unit E tasks (from roadmap M2.3 pending section):**
- Remove checkpoint tag lookup from `draft` command
- Add `BRANCH_FROM=<hash>` argument (default: `HEAD`)
- Replace session-name folder resolution with branch-name folder resolution under `session-diffs/`
- Add `DIFFS=<start>..<end>` range argument for selective diff application
- Replace `git am` loop with sequential `git apply` loop (index lines stripped), staging and committing each diff
- Update `Makefile.template` to pass `BRANCH_FROM` and `DIFFS` variables to `draft` target
- Update `tests/test_apply_workspace.sh` to reflect new `draft` behaviour (branch-name folders, `.diff` files, `git apply`, no checkpoint tags)

**Explicitly out of scope:**
- Unit F (`make confirm` simplification + `make sync` removal) — depends on E
- Unit G (`.skills/package-diff.md` update) — depends on E; also the `.skills/` directory does not exist yet

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | `make draft` creates a working branch and applies all `.diff` files from the latest branch-name folder under `session-diffs/` using `git apply` (index lines stripped), staging and committing each one | ✓ Accepted |
| 2 | `make draft BRANCH_FROM=<hash>` creates the draft branch from the specified commit instead of `HEAD` | ✓ Accepted |
| 3 | `make draft DIFFS=2..4` applies only diffs `0002-*` through `0004-*` from the branch folder | ✓ Accepted |
| 4 | `make draft SESSION=<branch-name>` resolves the branch-name folder explicitly under `session-diffs/` | ✓ Accepted |
| 5 | `make draft` rejects if a draft is already in progress (guard preserved) | ✓ Accepted |
| 6 | Tests pass: `./tests/test_apply_workspace.sh` exits 0 with no failures | ✓ Accepted |
| 7 | Architecture documents in scope describe the system as built | ✓ Accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/apply_workspace.sh`](scripts/apply_workspace.sh) | Redesign `draft` command: remove checkpoint tags, add `BRANCH_FROM`/`DIFFS`, switch from `git am` to `git apply` |
| [`libs/_templates/Makefile.template`](libs/_templates/Makefile.template) | Add `BRANCH_FROM` and `DIFFS` variables to `draft` target |
| [`tests/test_apply_workspace.sh`](tests/test_apply_workspace.sh) | Update draft tests for branch-name folders, `.diff` files, `git apply`, no checkpoint tags |
| [`libs/package_branch.sh`](libs/package_branch.sh) | Source of truth for numbered `.diff` file format and directory structure |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| `--from` renamed to `--branch-from` | Operator request for clarity | This handover |
| `SESSION` variable retained in Makefile | Backwards compatibility — now maps to branch-name lookup | `libs/_templates/Makefile.template` |

## Completed this session

| File | Change summary |
|---|---|
| `scripts/apply_workspace.sh` | Redesigned `draft` command: removed checkpoint tag logic; added `--branch-from` and `--diffs` flags; switched from `git am --3way` to `git apply` with index-line stripping; branch-name folder resolution under `session-diffs/` |
| `scripts/agent-sandbox.sh` | Added `--branch-from` and `--diffs` to `parse_flags`; passed through to `draft` subcommand |
| `libs/_templates/Makefile.template` | Added `BRANCH_FROM` and `DIFFS` variables to `draft` target |
| `tests/test_apply_workspace.sh` | Replaced `make_session_with_patches` with `make_session_with_diffs`; removed checkpoint tag setup; updated all draft/confirm/reject tests; added `test_draft_uses_branch_from` and `test_draft_uses_diffs_range`; all 37 tests pass |

## Deferred items

None.

## Next session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline.
**Session type:** Implementation — Unit F (`make confirm` simplification + `make sync` removal).

Read `docs/devlog/roadmap.md` M2.3 pending section for Unit F tasks.

**Watch-outs:**
- `make confirm` currently rebases + fast-forward merges + deletes draft branch. Unit F removes rebase and merge, leaving only branch deletion + draft-state cleanup.
- `SYNC=1` handling and `make sync` target are removed entirely.
- `make confirm` must still respect `TARGET_BRANCH` for the branch to return to, but no longer performs any git history manipulation.

**Grep to run:** `grep -n "rebase\|SYNC\|sync" scripts/apply_workspace.sh` — verify all rebase/SYNC/sync logic is removed from confirm.
