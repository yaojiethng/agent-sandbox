# Agent Handover

**Date:** 2026-08-23
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Two-part unit of work: (1) record the operator's decided empty-diff behavior on the roadmap (done pre-compaction, sits in the working tree), (2) implement it. Rolled into one iteration after operator review ruled the standalone registration too thin to be an iteration ("not a reasonable unit of work") -- recorded as a mid-session finding below.

## Decided behavior (operator 2026-08-23)

1. Empty `uncommitted.diff`: **skip** applying, print a warning.
2. Empty member diffs **inside a bundle** that carry associated commit messages: still create the commit with `--allow-empty` (message preserved), print a warning.

## Code map (verified this session)

| Site | File:line | Current behavior | Required change |
|---|---|---|---|
| Bundle member apply+commit | [`src/libs/diff.sh`](../../src/libs/diff.sh) `apply_and_commit()` (~153) | Zero-header diff -> `_apply_patch_file` -> git apply fails ("No valid patches") -> whole bundle aborts | Detect zero `^diff --git` headers first: warn, then `git commit --allow-empty -m "$COMMIT_MSG" --author="$AUTHOR"` WITHOUT `git add -A` (an empty member means no intended change; do not sweep unrelated working-tree noise into it) |
| uncommitted.diff in draft flow | [`scripts/workflows/draft.sh`](../../scripts/workflows/draft.sh) `draft_apply_uncommitted()` (~178) | Already skips empty/nonexistent via `[[ ! -s ]]` return 0, but SILENTLY | Add the warning on the exists-but-empty case (keep silent-skip for nonexistent) |
| Standalone `apply` workflow | [`scripts/workflows/apply.sh`](../../scripts/workflows/apply.sh) `apply_run()` (~55) | Empty diff hard-fails at git apply | Zero-header diff -> warn "empty diff; nothing to apply" -> return 0 |
| Preview/listing sites | draft.sh ~411/465/546 | Treat empty as absent, silent | Leave as-is (display paths; silence acceptable) |

Shared detection helper candidate: a tiny `diff_is_empty <file>` (zero `diff --git` headers) in `src/libs/diff.sh` so all three sites share one definition.

## Test plan

Extend [`tests/test_apply_count.sh`](../../tests/test_apply_count.sh) (or sibling):
1. `apply_run` + empty diff -> rc=0, warning present, no "Files changed" garbage (supersedes the "-12 found the branch unreachable" caveat -- this iteration MAKES it reachable)
2. `apply_and_commit` + empty diff -> rc=0, exactly one new empty commit whose message equals COMMIT_MSG, author preserved, warning present
3. `draft_apply_uncommitted` + exists-but-empty -> warning, tree unchanged, rc=0
4. Non-empty regressions stay green (existing tests)

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | Bundle empty members land as message-bearing empty commits with warning | unit test (`test_apply_count`) | accepted |
| AC2 | Empty `uncommitted.diff` skips with warning in both draft and standalone-apply paths | unit tests (`test_apply_count`, `test_diff_workflow`) | accepted |
| AC3 | Non-empty behavior unchanged everywhere | existing suites green | accepted |
| AC4 | Suite green and deterministic x2 | 634 tests / 39 files / 0 failed x2 | accepted |

## Verification notes from scoping

- Modern git accepts `git apply --allow-empty` on empty input; but the cleaner implementation never invokes git apply on a zero-header diff at all (detect-then-commit-empty), avoiding reliance on flag availability.
- This container's git rejects `/dev/null`-source hunks without index metadata; tests use modifications of tracked files (see test_apply_count.sh comment).
- `confirm.sh` reuses the draft functions, so the fix propagates there automatically.

## Findings

| Finding | Type | Impact |
|---|---|---|
| A standalone handover was cut for a two-line roadmap registration (originally `20260823-13`, deleted) -- below the threshold of a reasonable unit of work. Operator ruled it a problem at review | process, mid-session | Rolled into this iteration. Threshold for future iterations: a handover must carry implementation, investigation, or a decision of substance -- pure record-keeping rides along with the next real unit of work. GOTCHAS candidate |
| The `-11` ASCII sweep covered docs only; the live code tree (`scripts/ src/ tests/ Makefile`) still carries ~1258 non-ASCII lines | scoping discovery, close-out | Deferred: full second sweep as its own iteration |
| Old test in `test_diff_workflow.sh` pinned the removed reject-empty-diff behavior; my targeted grep missed it, the suite caught it | contract residue | Test rewritten; validates GOTCHAS propagation-sweep entry -- when behavior flips sign, greps alone are insufficient, run the suite |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | Decision recorded, then bullet closed on delivery |
| [`src/libs/diff.sh`](../../src/libs/diff.sh) | New shared `diff_is_empty` helper; `apply_and_commit` empty-member branch: warn + `git commit --allow-empty` with message/author, deliberately NO `git add -A` (empty member means no intended change; unrelated working-tree noise must not be swept in) |
| [`scripts/workflows/apply.sh`](../../scripts/workflows/apply.sh) | `apply_run`: empty diff skips `_apply_patch_file` with warning; count tail reports `Files changed: 0` naturally |
| [`scripts/workflows/draft.sh`](../../scripts/workflows/draft.sh) | `draft_apply_uncommitted`: exists-but-headerless -> warn + skip; also fixed an em-dash survivor in the "Applying uncommitted.diff" string (missed by the -11 sweep) |
| [`tests/test_apply_count.sh`](../../tests/test_apply_count.sh) | +3 tests: apply_run skip+warning; allow-empty commit pins message, author, tree-equality-with-parent; draft skip+warning. Header note about unreachable zero-count branch removed -- branch is reachable now |
| [`tests/test_diff_workflow.sh`](../../tests/test_diff_workflow.sh) | Contract residue: old test pinned "apply_run must reject empty diff"; rewritten to pin the new skip contract. Caught by the suite after my close-out grep missed it -- validates the GOTCHAS propagation-sweep entry |
| [`docs/architecture/tool_interface.md`](../../docs/architecture/tool_interface.md) | `make apply` and `make draft` sections now state the empty-diff semantics (operator-approved wording) -- the only two doc sites that specify apply behavior |

Implementation delivered as a single squashed commit (the WIP registration content folded in per git policy).



## Deferred items

- **ASCII sweep of the live code tree** (discovered at close-out): the `-11` sweep covered docs only; ~1258 non-ASCII lines remain across `scripts/ src/ tests/ Makefile`. Full second sweep -- own iteration, flagged to operator.
- Naming/header contradictions one-liners (roadmap, 4 items incl. apply.sh header-vs-guard).
- Shellcheck cleanup -> flip lint gate blocking (baseline 31 warnings).
- Start/serve/dry-run interface refactor (roadmap line ~153, large).
- confirm.sh savepoint rollback bug (still needs operator decision).
