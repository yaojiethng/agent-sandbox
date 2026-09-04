# Handover 20260904-10 — fix draft rollback deletes the draft branch

**Milestone:** M2.6 - Session Persistence
**Type:** fix
**Status:** Closed
**Date:** 2026-09-04

## Objective

A failed `make draft` rolls back to the savepoint and restores the source branch, but leaves the partially-created `draft/*` branch behind. The next `make draft` then fails the collision guard (`draft_guard_no_collision`, src/libs/draft_state.sh:41). Fix: `_draft_rollback` deletes the draft branch.

## Diagnosis

`_draft_rollback` (scripts/workflows/draft.sh:375) resets to `draft-savepoint`, checks out the source branch, deletes the tag -- but never deletes the `draft/*` working branch created by `draft_create_and_init_branch` (`git checkout -b`). Subsequent `make draft` hits the collision guard and fails until the operator deletes the branch manually.

## Scope

| # | Item | Status |
|---|---|---|
| 1 | `_draft_rollback` deletes the exact `draft/*` branch `draft_run` created (name threaded via `DRAFT_WORKING_BRANCH`, guarded: exists + `draft/*` prefix) | done |
| 2 | Tests cover rollback branch deletion | done |
| 3 | Suite green; lint clean | done |

## Deferred

- None.

## Findings

| # | Finding | Status |
|---|---|---|

## Decisions

| # | Decision | Rationale | Source |
|---|---|---|---|
| D1 | The exact branch name is threaded from `draft_run` to `_draft_rollback` (caller-scope `DRAFT_WORKING_BRANCH`, same pattern as `COMPOSE_ARGS`), not inferred from HEAD at rollback time. | Operator correction: delete the branch the run made, not whatever `draft/*` branch HEAD happens to sit on. Follows the existing assign-to-caller convention for out-params. | This iteration |

## Acceptance criteria (pre-close)

| # | Criterion | Status |
|---|---|---|
| AC1 | After a failed draft apply, no `draft/*` branch remains | done |
| AC2 | Tests cover the rollback-cleanup path; suite green; lint clean | done -- suite 731/731 (new `test_draft_failure_deletes_draft_branch`), ShellCheck 0 warnings |
