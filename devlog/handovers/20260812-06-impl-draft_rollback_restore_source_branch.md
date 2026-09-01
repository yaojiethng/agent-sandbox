# Agent Handover

**Date:** 2026-08-12
**Milestone:** M2.6 — Session Persistence (general CLI/infra track)
**Type:** Implementation
**Status:** Closed

> This is **sub-task 1 (of an operator-orchestrated 3-way split)** of session
> `20260812-05`. **This handover's scope is only Task 1 — fix the run-1 rollback
> bug.** Task 3 (tidy `.rej`) is handover `20260812-05`; Task 2 (whitespace
> round-trip hardening) is handover `20260812-07`.

## Objective (Task 1)

Fix the draft-workflow rollback path so that, when patch application fails, the
operator is returned to the **source branch** — not left stranded on the (now
empty) `draft/*` branch.

## The bug (confirmed)

`scripts/workflows/draft.sh`, rollback path on patch-apply failure (`_run_draft_workflow`):

```bash
echo "Rolling back to savepoint..."
git -C "$PROJECT_DIR" reset --hard draft-savepoint
git -C "$PROJECT_DIR" tag -d draft-savepoint
return 1
```

`git reset --hard draft-savepoint` moves **HEAD** to the savepoint commit but
**never checks back out to the source branch** that was current before
`draft_create_and_init_branch` did `git checkout -b draft/...`. `SOURCE_BRANCH`
is captured (in `draft_create_and_init_branch` / `_run_draft_workflow`) and written
into `.draft-state`, but the rollback path does not use it. Net effect: after a
clean rollback, HEAD points at the fork base but the branch is still the (empty)
`draft/*` branch — observed by the operator as "* draft/9f8cdc-... " (bad branch
afterwards).

## Files in scope

| File | Role |
|---|---|
| `scripts/workflows/draft.sh` | the rollback path (both the patch-apply and the uncommitted-diff failure branches) |
| `tests/...` | a regression test asserting the operator is returned to the source branch after a failed draft |

## Constraints / context

- Same rollback block appears **twice** in `_run_draft_workflow` (once for
  `draft_apply_patches` failure, once for `draft_apply_uncommitted` failure) — fix both consistently.
- The restore must be robust: capture the branch that was current **before**
  `git checkout -b` (prefer it), and guard against restoring to a branch that no
  longer exists.
- The guard at the top of `draft_create_and_init_branch` rejects drafting from an
  existing `draft/*` branch (`CURRENT_BRANCH == draft/*`), so a correct rollback
  must not leave the operator on a `draft/*` branch.
- FORCE-mode behavior (commit `.rej` + partial hunks rather than halt) is
  deliberate and must NOT change — this task is only about the failure *rollback*
  branch.
- Follow the repo's `return`/`|| rc=$?` idioms (`docs/development/bash-coding-conventions.md`); shellcheck-clean.

## Acceptance criteria (Task 1)

- [x] Root cause confirmed & documented in this handover
- [x] On patch-apply failure, the operator is returned to the source branch (not left on `draft/*`)
- [x] Regression test added and passing (simulates a failed draft, asserts final branch is the source branch)
- [x] Full test suite green
- [x] No unrelated changes

## Deferred

- Tidy `.rej` → Task 3 (handover `20260812-05`)
- Whitespace round-trip hardening → Task 2 (handover `20260812-07`)

## Mid-session findings

- **Root cause confirmed.** `SOURCE_BRANCH` is not captured in `_run_draft_workflow`
  itself as the objective assumed — it is computed as a `local` inside `draft_run`
  (line ~313) and only passed downward into `draft_create_and_init_branch` for the
  `.draft-state` record. `_run_draft_workflow` never had it in scope for the
  rollback. Fix: capture `SOURCE_BRANCH` in `_run_draft_workflow` **before** the
  `draft_run` call (which is when HEAD is still on the source branch, before
  `git checkout -b draft/...`), and pass the value to a new `_draft_rollback`
  helper used by both failure sites. `draft_run` keeps its own identical local for
  the `.draft-state` record — separate scope, unchanged behavior.
- **Both rollback sites fixed identically.** The patch-apply and the uncommitted-diff
  failure blocks both now call `_draft_rollback "$PROJECT_DIR" "$SOURCE_BRANCH"`
  instead of the bare `reset --hard` + `tag -d`.

## Completed this session

- [x] Root cause confirmed and documented (see Mid-session findings)
- [x] `_draft_rollback` helper: resets to savepoint, checks out `SOURCE_BRANCH`,
      then deletes the tag; guards (via `git rev-parse --verify refs/heads/<br>`)
      against restoring to a branch that no longer exists (falls back to a detached
      HEAD at the savepoint commit)
- [x] `SOURCE_BRANCH` captured in `_run_draft_workflow` before the `draft_run` call
- [x] Both failure rollback sites (`draft_apply_patches` and `draft_apply_uncommitted`
      in `_run_draft_workflow`) restore the source branch — operator is not left on
      `draft/*`
- [x] Regression test `test_draft_failure_returns_to_source_branch` added to
      `tests/test_draft_workflow.sh`; verified discriminating (fails when checkout
      is artificially reverted)
- [x] Full suite green: 475 tests / 28 files, 469 passed, 0 failed, 6 skipped
      (`bash scripts/run_tests.sh` = `make test`)
- [x] Shellcheck clean on the new code (only pre-existing SC1091/SC2028/SC2034
      infos remain, none introduced by this change)
- [x] `src/libs/diff.sh` FORCE-mode untouched; whitespace round-trip (Task 2) and
      `.rej` tidy (Task 3) not touched
