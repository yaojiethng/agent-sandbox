# Agent Handover

**Session date:** 2026-07-21
**Milestone:** M2.6 — Session Resume and Mount Model Redesign
**Session type:** Implementation — Refactor draft apply logic to share core with apply
**Status:** Closed

## Objective

Unify `make draft`'s per-patch apply logic with `make apply`'s apply logic so that `make draft FORCE=1` works equivalently to `make apply FORCE=1` — applying with `--reject`, creating `.rej` files for conflicts, and pushing through errors instead of aborting on the first failed patch.

## Scope

This session targets the apply/draft unification refactoring — concrete implementation, not investigation (listed under M2.6.4 pre-design investigations as "Unify `make apply` and `make draft`?").

The work decomposes into 6 units:

**Unit 1 — Extract `_apply_patch_file` into `src/libs/diff.sh`**
Core `git apply` logic extracted from `apply_run` into a shared helper: handles normal, FORCE (`--reject`), and PERMISSIVE (`--recount`) modes. Strips index lines via `strip_index_lines` (already in `diff.sh`).

**Unit 2 — Add `apply_and_commit`**
Calls `_apply_patch_file`, then `git add -A && git commit`. Takes `AUTHOR` as parameter. Lives in `src/libs/diff.sh` alongside `_apply_patch_file`.

**Unit 3 — Refactor `apply_run` to delegate to `_apply_patch_file`**
No behavioural change for `make apply`. `apply_run` in `scripts/workflows/apply.sh` sources `diff.sh` and delegates the `git apply` call.

**Unit 4 — Decompose `draft_run` into branch-creation only**
`draft_run` becomes branch-creation + `.draft-state` only. No apply logic. `main()` in `draft.sh` orchestrates: collect patches → count → create branch → apply loop → apply uncommitted. Patch list collected once, fed to both `draft_run` (for count) and `draft_apply_patches` (for apply).

**Unit 5 — Refactor apply loop to use shared helpers**
`draft_apply_patches` and `draft_apply_uncommitted` call `apply_and_commit` instead of inline `git apply`, `git add`, `git commit`. Both gain `FORCE` and `PERMISSIVE` parameters.

**Unit 6 — Wire CLI and Makefile**
- `draft.sh` CLI parser: add `--force` and `--permissive` flags
- `Makefile.template` `draft` target: add `$(if $(FORCE),--force,)` and `$(if $(PERMISSIVE),--permissive,)`
- Update usage comments in both files
- Update `docs/development/cli-standards.md` if it documents `draft` options

Not in scope: the broader `make apply` vs `make draft` command unification question for the worktree model remains a design decision for the M2.6.4 design session.

## Carried forward

| Item | From handover |
|---|---|
| Policy file disambiguation pass (14 operation policy files) — M2.6.3 remaining task | `20260721-05-workflow-roadmap_system_audit.md` |
| Design policy extraction — M2.6.3 remaining task | `20260721-05-workflow-roadmap_system_audit.md` |

## Acceptance criteria

| # | Criterion | Verifiable by |
|---|---|---|---|
| 1 | `_apply_patch_file` defined in `src/libs/diff.sh` — handles normal, FORCE, PERMISSIVE | `grep -c '_apply_patch_file' src/libs/diff.sh` ≥ 1 | ✅ Agent |
| 2 | `apply_and_commit` defined in `src/libs/diff.sh` | `grep -c 'apply_and_commit' src/libs/diff.sh` ≥ 1 | ✅ Agent |
| 3 | `apply_run` delegates to `_apply_patch_file` | `grep -c '_apply_patch_file' scripts/workflows/apply.sh` ≥ 1 | ✅ Agent |
| 4 | `apply_run` without COMMIT_MSG does not commit — existing behaviour preserved | All 9 existing apply tests pass | ✅ Agent |
| 5 | `draft_run` no longer applies patches — branch creation only | `grep 'draft_apply_patches' scripts/workflows/draft.sh` only in `_run_draft_workflow`, not in `draft_run` | ✅ Agent |
| 6 | `draft_apply_patches` / `draft_apply_uncommitted` call `apply_and_commit` — no inline git apply | `grep -c 'apply_and_commit' scripts/workflows/draft.sh` ≥ 2 | ✅ Agent |
| 7 | `draft` CLI accepts `--force` and `--permissive` flags | Dispatch tests pass | ✅ Agent |
| 8 | FORCE=true applies with `--reject`, continues on conflict | `test_apply_patch_file_force` passes | ✅ Agent |
| 9 | PERMISSIVE=true retries with `--recount` | `_apply_patch_file` uses `--recount` in PERMISSIVE mode | ✅ Agent |
| 10 | All unit tests pass | `bash scripts/run_tests.sh` — 418 pass, 0 fail, 6 skipped | ✅ Agent |
| 11 | Knowledge tests pass for new API | Both knowledge tests updated and pass | ✅ Agent |
| 12 | Header comments describe system as built | Manual review | ⏳ Operator |

## Hot files

### Source

| File | Why in scope | Unit |
|---|---|---|
| [`src/libs/diff.sh`](../../src/libs/diff.sh) | Add `_apply_patch_file` and `apply_and_commit` | U1, U2 |
| [`scripts/workflows/apply.sh`](../../scripts/workflows/apply.sh) | Source `diff.sh`, delegate `apply_run` to `_apply_patch_file` | U3 |
| [`scripts/workflows/draft.sh`](../../scripts/workflows/draft.sh) | Decompose `draft_run`, refactor apply loop, add `--force`/`--permissive` CLI | U4, U5, U6 |
| [`scripts/templates/Makefile.template`](../../scripts/templates/Makefile.template) | Wire `FORCE`/`PERMISSIVE` into `draft` target + comment block; add `_validate_overrides` per-target variable guard for all 13 targets | U6 |

### Documentation — checked, no update needed

| File | Finding |
|---|---|
| [`docs/development/cli-standards.md`](../../docs/development/cli-standards.md) | Mentions `make draft` in examples only; no per-flag documentation to update |
| [`docs/development/quickstart.md`](../../docs/development/quickstart.md) | Only references apply in recovery section; no draft FORCE/draft docs to update |

### Tests — all updated

| File | Change |
|---|---|
| [`tests/test_diff_workflow.sh`](../../tests/test_diff_workflow.sh) | Added 6 new tests for `_apply_patch_file` (normal/force/missing) and `apply_and_commit` (basic/missing-args/force) |
| [`tests/test_draft_workflow.sh`](../../tests/test_draft_workflow.sh) | Added `_test_draft_run` backward-compat helper; all 25 call sites updated |
| [`tests/test_dispatch.sh`](../../tests/test_dispatch.sh) | Added `test_draft_with_force` and `test_draft_with_permissive` |
| [`tests/knowledge/workflow_draft_then_reject.sh`](../../tests/knowledge/workflow_draft_then_reject.sh) | Updated PHASE 1 to use decomposed collect→branch→apply flow |
| [`tests/knowledge/workflow_draft_then_confirm.sh`](../../tests/knowledge/workflow_draft_then_confirm.sh) | Updated PHASE 1 to use decomposed collect→branch→apply flow |

## Propagation checklist

| File | Change | Status |
|---|---|---|
| `src/libs/diff.sh` | Add `_apply_patch_file`, `apply_and_commit` | done |
| `scripts/workflows/apply.sh` | Delegate to `_apply_patch_file` | done |
| `scripts/workflows/draft.sh` | Decompose `draft_run`, refactor apply loop, add CLI flags | done |
| `scripts/agent-sandbox.sh` | Updated usage comment to document `--force` and `--permissive` for draft |
| `scripts/templates/Makefile.template` | Wire FORCE/PERMISSIVE + add per-target variable validation | done |
| `docs/development/cli-standards.md` | Check for draft FORCE docs — no update needed (no per-flag docs) | done |
| `docs/development/quickstart.md` | Check for FORCE/draft drift — no update needed | done |
| `tests/test_diff_workflow.sh` | Add `_apply_patch_file` + `apply_and_commit` tests | done |
| `tests/test_draft_workflow.sh` | Update `draft_run` call sites via `_test_draft_run` helper | done |
| `tests/test_dispatch.sh` | Add draft FORCE/PERMISSIVE dispatch test | done |
| `tests/knowledge/workflow_draft_then_reject.sh` | Update for new decomposed API | done |
| `tests/knowledge/workflow_draft_then_confirm.sh` | Update for new decomposed API | done |

## Decisions made this session

None.

## Mid-session findings

None.

## Completed this session

| File | Change |
|---|---|
| `src/libs/diff.sh` | Added `_apply_patch_file` (core apply logic with FORCE/PERMISSIVE) and `apply_and_commit` (apply+commit); updated header comment |
| `scripts/workflows/apply.sh` | Refactored `apply_run` to delegate to `_apply_patch_file`; fixed stale header comment |
| `scripts/workflows/draft.sh` | Decomposed `draft_run` to branch-creation-only; added `_run_draft_workflow` orchestrator; refactored `draft_apply_patches` and `draft_apply_uncommitted` to call `apply_and_commit`; added `--force` and `--permissive` CLI flags; updated usage |
| `scripts/agent-sandbox.sh` | Updated usage comment to document `--force` and `--permissive` for draft |
| `scripts/templates/Makefile.template` | Wired `FORCE`/`PERMISSIVE` into `draft` target; added `_validate_overrides` per-target variable validation for all 13 targets |
| `tests/test_diff_workflow.sh` | Added 6 new tests: `_apply_patch_file` normal/force/missing-diff, `apply_and_commit` basic/missing-args/force |
| `tests/test_draft_workflow.sh` | Added `_test_draft_run` backward-compat wrapper; replaced all 25 `draft_run` call sites with `_test_draft_run` |
| `tests/test_dispatch.sh` | Added `test_draft_with_force` and `test_draft_with_permissive` dispatch routing tests |
| `tests/knowledge/workflow_draft_then_reject.sh` | Updated to use decomposed flow (collect→branch→apply) |
| `tests/knowledge/workflow_draft_then_confirm.sh` | Updated to use decomposed flow (collect→branch→apply) |

## Deferred items

| Item | Reason | Destination |
|---|---|---|
| Policy file disambiguation pass | Not in scope for this session | M2.6.3 remaining task |
| Design policy extraction | Not in scope for this session | M2.6.3 remaining task |

## Next session

**M2.6.4 — Mount Model Design and Implementation** or **M2.6.3 remaining items** (policy disambiguation, design policy extraction), per operator preference.

Post-close bookkeeping: nothing pending (sub-milestone still in progress). The apply logic unification pre-design investigation is complete; the command-level unification question remains open for the M2.6.4 design session.

---

[CORRECTION — 2026-07-21]: Post-review fixes to `_run_draft_workflow` in `scripts/workflows/draft.sh`:
1. `exit 1` → `return 1` (four error paths) — prevents latent bug if called from sourced context
2. Added optional 9th param `PATCH_LIST` — interactive path collects once, passes pre-collected list, eliminating double directory enumeration
3. `echo "$PATCH_LIST"` → `printf '%s\n' "$PATCH_LIST"` for null-safe piping
4. Stripped empty `?=` declarations from `scripts/templates/Makefile.template` (redundant with `_validate_overrides`)

All 418 tests still pass.
