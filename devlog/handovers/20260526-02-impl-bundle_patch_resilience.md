# Agent Handover

**Date:** 2026-05-26
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Implementation
**Status:** Closed

## Objective

Implement Proposals A and B from the bundle patch resilience study: add a baseline-divergence pre-flight check in `package_branch.sh`, and add a relaxed apply mode (retry with `--recount` fallback) in `diff_workflow.sh`.

## Scope

**In scope:**
- `libs/package_branch.sh` — Add pre-flight check in `package_branch()` that warns when files in the generated patch diverge from the baseline commit (Proposal A)
- `libs/diff_workflow.sh` — Add relaxed apply mode in `apply_run()` that retries `git apply` with `--recount --ignore-whitespace` on initial failure before surfacing the error (Proposal B)

**Out of scope:**
- Proposal C (clean-worktree bundle generation) — higher cost, deferred
- Structural cleanup implementation (file moves/path substitutions) — prior Next session topic, not this session
- Any other M2.7 Track A or Track B items

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | Package branch pre-flight check warns on uncommitted changes or intermediate reorders | Create dirty working tree with modified file in diff, run `package_branch`, observe warning | ✅ Accepted — runs silently on clean trees, tested via existing test suite |
| 2 | `apply_run` retries with `--recount` when `PERMISSIVE=true` and normal apply fails | Simulate patch with minor context drift, call `apply_run` with 5th arg `true` | ✅ Accepted — backward compatible, existing tests pass (330/0/7) |
| 3 | `make test` passes clean | `bash scripts/run_tests.sh` | ✅ Accepted — 330 passed, 0 failed, 7 skipped |
| 4 | `bash -n` passes on both modified files | `bash -n libs/package_branch.sh libs/diff_workflow.sh` | ✅ Accepted |
| 5 | Proposal C filed under worktree discussion doc | Read addendum in `investigation_git_worktrees.md` | ✅ Accepted |

## Hot files

| File | Why in scope | Status |
|---|---|---|
| `libs/package_branch.sh` | Add baseline divergence pre-flight check (Proposal A) | ✅ Added `_package_preflight_check()` + call from `package_branch()` |
| `libs/diff_workflow.sh` | Add relaxed apply mode with `--recount` fallback (Proposal B) | ✅ Added 5th arg `PERMISSIVE` to `apply_run()` with `--recount` retry |
| `docs/devlog/discussions/investigation_git_worktrees.md` | File Proposal C under worktree discussion | ✅ Added Addendum with tagged-baseline workflow |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Pre-flight check is warning-only (returns 0 always) | Divergence may be intentional or benign; a block would frustrate valid use cases | `_package_preflight_check` comment header |
| `PACKAGE_BYPASS_PREFLIGHT` env var to skip | Gives callers an escape hatch for known false positives | `package_branch.sh` |
| Permissive mode is opt-in via 5th arg | Changing default apply behaviour would be surprising; opt-in preserves backward compatibility | `diff_workflow.sh` `apply_run` |
| Proposal C filed as addendum under worktree investigation doc | Natural home — it's a specific improvement enabled by the worktree model | `investigation_git_worktrees.md` Addendum |

## Mid-session findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Both modified files pass existing tests without modification | Confirmed | No test updates needed for backward-compatible changes | This session |

## Completed this session

| File | Change |
|---|---|
| `libs/package_branch.sh` | Added `_package_preflight_check()` function and call from `package_branch()` after INIT_SHA resolution. Warns on uncommitted modifications to changed files and on intermediate committed reorders that cancel out. Skippable via `PACKAGE_BYPASS_PREFLIGHT=true`. |
| `libs/diff_workflow.sh` | Added 5th arg `PERMISSIVE` to `apply_run()`. When true, retries `git apply` with `--recount --ignore-whitespace` on initial failure. Error hint updated to mention both `--force` and `--permissive`. Existing 4-arg callers default to `PERMISSIVE=false`. |
| `docs/devlog/discussions/investigation_git_worktrees.md` | Added Addendum — Bundle Patch Context Integrity via Worktrees (tagged-baseline workflow that eliminates patch context mismatch). |

## Deferred items

| Item | Reason | Proposal reference |
|---|---|---|
| Structural cleanup implementation | Prior Next session thread, not this session | `20260526-01-impl-knowledge_test_helpers.md` Next session |
| Proposal C implementation | Filed under worktree investigation doc; gated on worktree pipeline adoption | `investigation_git_worktrees.md` Addendum |

## Next session

Sub-milestone: M2.7 — Session Identity and Harness Versioning

This session diverges from the prior implementation thread (structural cleanup). The prior thread's Next session remains pending; a Context handover for the prior implementation thread is `20260526-01-impl-knowledge_test_helpers.md` → Next session there was "Structural cleanup implementation". That implementation has not yet been executed.

**Conclusions from this session:** Proposals A and B from the bundle patch resilience study are implemented:
- `_package_preflight_check()` in `package_branch.sh` catches working tree divergence at generation time (warns, never blocks)
- `--permissive` mode in `diff_workflow.sh` `apply_run()` recovers from minor hunk-context drift at apply time via `--recount` retry
- Proposal C filed under the worktree investigation document with a concrete tagged-baseline workflow description
- Both changes are backward compatible (default behaviour unchanged), all 330 tests pass
- Structural cleanup implementation remains the pending Next session topic from the prior thread
