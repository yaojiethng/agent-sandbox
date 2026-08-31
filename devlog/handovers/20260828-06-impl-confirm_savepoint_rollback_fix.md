# Agent Handover

**Date:** 2026-08-28
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Fix the latent confirm-savepoint rollback bug in `scripts/workflows/confirm.sh` (open campaign-findings bullet: "confirm.sh savepoint rollback latent bug"). This iteration runs IN PARALLEL with handover `20260828-02` (dry-run container startup, Active in the other container): the working tree starts from a reset of that iteration's uncommitted changes, my hot files do not overlap theirs, and the operator rebases the two deliveries at a later time.

## Scope

In scope:
- `scripts/workflows/confirm.sh` rollback path: the `git reset --hard confirm-savepoint` calls must never run against a tag not created by the current run, and must never land on a stale leftover tag from a prior run. (delivered)
- The exact end-state behavior is an operator decision (see Decisions); implementation follows that call. (delivered)
- Unit tests in `tests/test_draft_workflow.sh` (existing confirm flow tests) + new tests pinning the fixed behavior. (delivered; extended below)
- Roadmap checkbox for the campaign-findings bullet. (delivered)
- **Part A (reopened, operator):** fix the contradictory conflict message in confirm.sh's step-3 block — it tells the user to "resolve and --continue" / "--abort" a rebase that confirm has already aborted and reset. Align the message to the auto-rollback behavior.
- **Part B (reopened, operator):** close the drop-step (`rebase --onto`) rollback test gap — same `SAVEPOINT_COMMIT` mechanism, no coverage; add a regression test forcing the drop-step to fail and asserting the savepoint restore.

Deferred / not in scope (unchanged): Bug D (RESUME semantics), Bug E (stop template, operator on it), `.compose` stale-file pruning, prune-command redesign, mount-worktree full-history clone, git_policy "session branch" OOS terms, any file in the `20260828-02` hot-file set (`compose.sh`, docker-compose files, entrypoints, provider dockerfiles, dry-run scripts/tests, dry-run docs).

## Carried forward

| Item | From handover |
|---|---|
| "confirm.sh savepoint rollback latent bug - rebase-conflict rollback runs `git reset --hard confirm-savepoint` on a path where the tag was never created; a stale tag from a prior run lands the reset on the wrong commit. Behavior change - operator decision required." (roadmap bullet, campaign findings 2026-08-21) | roadmap |

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| AC1 | Stale-tag hazard eliminated: the rollback can never reset to a `confirm-savepoint` tag not created by the current run | met (agent) |
| AC2 | No-draft-state conflict path exits cleanly with a descriptive error (no git "fatal: ambiguous argument") | met (agent) |
| AC3 | Operator-chosen behavior option (Option 2: local-variable savepoint) implemented exactly per the call | met (agent) |
| AC4 | Suite green on the reset baseline, new tests pass, lint 0 | met - 660/0/0, lint 0 |
| AC5 | No overlap with the `20260828-02` file set (parallel-safe; rebase stays conflict-free) | met - confirm.sh + test_draft_workflow.sh only |
| AC6 | New regression tests genuinely fail on the OLD code (not vacuous) | met - reverting to HEAD made both new tests FAIL |
| AC7 | Part A: conflict message aligned to the auto-rollback (no dead "--continue"/"--abort" text); draft-branch-unchanged remediation shown | met - message updated; existing `test_confirm_conflict_recovery` still passes on "Conflict rebasing" |
| AC8 | Part B: drop-step (`rebase --onto`) rollback path covered by a test (previously untested) | met - `test_confirm_drop_step_failure_restores_savepoint` PASS |

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/workflows/confirm.sh`](../../scripts/workflows/confirm.sh) | savepoint creation/rollback sites (both rebase-failure paths) |
| [`tests/test_draft_workflow.sh`](../../tests/test_draft_workflow.sh) | existing confirm behavior tests + new savepoint tests |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | campaign-findings checkbox (single bullet, minimal diff for rebase) |

## Decisions

| Decision | Status |
|---|---|
| Behavior option for the savepoint rollback: chosen **Option 2 - local-variable savepoint** (capture `SAVEPOINT_COMMIT$(rev-parse HEAD)` in a same-process var; `git reset --hard "$SAVEPOINT_COMMIT"` on failure; no git tag at all). Kills both reproduced vectors (missing-tag crash A, stale-tag data loss B) by construction; preserves the defensive checkpoint; minimal behavior change | CONFIRMED (operator, parallel-session chat) |
| Parallel-operation commit protocol: reset uncommitted tree; exclude `20260828-02`'s untracked files (their handover + e2e doc) from my commit; add only my files + my handover explicitly | CONFIRMED (operator) |
| Part A conflict-message behavior: **option (a) - align the help text to the auto-rollback** (draft stays unchanged on conflict; no misleading "--continue"/"--abort" dead text). Rejected (b) leave-the-conflict and (c) drop-message | CONFIRMED (operator) |
| Part B drop-step rollback test: agreed; and the operator asked to bundle Part A + Part B into the ALREADY-CLOSED delivery commit rather than open a new iteration -> reopen `20260828-03`, amend the delivery commit, rewrite the misleading commit message | CONFIRMED (operator) |

## Findings

- **Latent bug (roadmap bullet EMPIRICALLY CONFIRMED; reproduction performed in a throwaway scratch repo outside the tracked tree, since discarded; no docker needed - confirm.sh is git-only).** `confirm_run` creates the `confirm-savepoint` tag ONLY inside the `[[ -n "${DRAFT_STATE_COMMIT:-}" ]]` drop-step branch. Both rebase-failure paths (drop-rebase failure and step-2 target rebase failure) unconditionally run `git reset --hard confirm-savepoint`. Two reproduced failure modes on a rebase CONFLICT:
  - **A - missing tag (rc 128, hard abort, no descriptive error):** with `DRAFT_STATE_COMMIT` empty (a NORMAL outcome - `draft_validate_branch` itself warns "Skipping drop step" because the recomm-commended `git rebase -i` shaping drops the `.draft-state` commit), a conflict runs `git reset --hard confirm-savepoint` -> `fatal: ambiguous argument 'confirm-savepoint': unknown revision` under `set -e`, script aborts raw at 128, never reaching the descriptive "Error: failed..." path.
  - **B - stale tag (SILENT DATA LOSS, rc 1):** a `confirm-savepoint` tag left by a prior crashed run (process died between `rebase --abort` and `tag -d`) -> on the next conflict `git reset --hard confirm-savepoint` SUCCEEDS and rewinds the draft branch to the stale tag's OLD commit. Reproduced: `draft/foo` reset from "work 1" back to base; `work.txt` and the drafted `file.txt` edit gone from the branch; the "work 1" commit absent from `git log --all`; branch left (not deleted) at the rewound pointer. Confirm fails AND the authored draft work is destroyed.
  - The tag name is fixed, so "this run" vs "prior run" is indistinguishable by existence alone - the root cause is using a mutable global git tag as a same-process savepoint.
- **No test covered this - why the bug was invisible:** `tests/test_draft_workflow.sh` confirm tests only drive clean/happy paths (`deletes_draft_branch`, `merges_changes`, `target_branch`, `rejects_non_draft_branch`, `after_branch_advances`). There is NO test that drives a rebase CONFLICT, so neither the missing-tag abort nor the stale-tag reset was ever exercised. The roadmap bullet originated from the 2026-08-21 campaign (registered at `20260823-04`); the campaign report itself is not retained in this container (`output/` empty).
- **Related oddity (flagged, NOT fixed without operator call - scope discipline):** the step-2 conflict path prints "Resolve conflicts, then run 'git rebase --continue', then 'make confirm'." and then immediately runs `rebase --abort` + the savepoint reset, discarding any manual resolution. The help text is unreachable debris from an older flow. Not part of the savepoint fix unless the operator wants it folded in.

## Completed

| File | Change |
|---|---|
| [`scripts/workflows/confirm.sh`](../../scripts/workflows/confirm.sh) | savepoint moved from a fixed-name git tag to a same-process `SAVEPOINT_COMMIT` local var (captured once, up front); both rebase-failure rollbacks `reset --hard "$SAVEPOINT_COMMIT"`; all `confirm-savepoint` tag create/delete ops removed; success-path tag cleanup removed; steps renumbered |
| [`tests/test_draft_workflow.sh`](../../tests/test_draft_workflow.sh) | `_make_no_state_commit_conflict_draft` builder + 2 regression tests (no-savepoint-tag clean abort; stale-tag preserves draft + leaves tag). Both verified to FAIL on the old tag-based code and PASS on the fix |
| [`scripts/workflows/confirm.sh`](../../scripts/workflows/confirm.sh) | Part A: step-3 conflict help text aligned to the auto-rollback (dead "resolve and --continue" / "--abort" lines replaced with accurate draft-unchanged remediation) |
| [`tests/test_draft_workflow.sh`](../../tests/test_draft_workflow.sh) | Part B: `_make_state_commit_draft_with_dirty_tree` builder + `test_confirm_drop_step_failure_restores_savepoint` (forces the drop-step `rebase --onto` to fail via a dirty tree, asserts savepoint restore, clean rc, no fatal) |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | campaign-findings bullet "confirm.sh savepoint rollback latent bug" checked |
| This handover | scope, findings (empirical reproduction), decision, ACs |

## Deferred items

- Bug D (RESUME semantics, `20260828-02` finding) - its own investigation; touches files near the dry-run set, retained for a non-parallel slot.
- Bug E (stop template, `20260828-02` finding) - operator is already on it.
- Campaign-findings remainder: `.compose` stale-file pruning, prune-command redesign, mount full-history clone, git_policy "session branch" OOS terms - unchanged.
- The "resolve and continue then abort" message oddity in confirm.sh (see Findings) - only if the operator folds it into the AC-carrying fix.

## What's Next

M2.6 - Session Persistence. Post-close bookkeeping: roadmap checkbox for the campaign-findings bullet.
After operator scope + behavior confirmation: reset the uncommitted tree (`git reset --hard`; untracked `20260828-02` files left in place, excluded from my commit), implement the chosen option in `confirm.sh`, extend `tests/test_draft_workflow.sh`, run the full suite + lint, commit only my file set, present the AC table, close.
Watch-outs: AGENT_FEEDBACK bash traps (`local VAR=$(cmd)` swallows rc, `|| true` on failure-tolerant checks, empty-vs-unset defaults); GOTCHAS close-out greps sweep `src/ scripts/ tests/ docs/ Makefile` in full; parallel-iteration hygiene (never `git add -A` over the other iteration's untracked files).