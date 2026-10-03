# Agent Handover

**Date:** 2026-09-20
**Milestone:** M2.6 - Session Persistence (M3 backpressure group)
**Type:** refactor
**Status:** Closed

## Objective

Resolve inventory item 2 in two parts. Part 1: make the `run_test` `$1 || true` `set -e` suppression harmless by reworking the one inert regression test into the fresh-`bash`-probe pattern and recording the rule where the feedback entry names (`testing_policy.md`). Part 2: split `tests/test_draft_workflow.sh` (1102 lines, the repository's only file over 1000) into per-family files with a shared fixture lib.

## Scope

Operator directive: "After that, next item: run_test set -e suppression + Split tests/test_draft_workflow.sh". Scope approved at Step 2, one iteration, type `refactor` (test restructure + test fix land as one delivery).

## Carried forward

The deferred `tests/test_draft_workflow.sh` split from handover `20260919-19`.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | The inert autosave-loop test observes the guard: dropping the tick-status guard from `autosave_loop` turns it red (mutation verified, then restored) | `bash tests/test_routing.sh` | accepted |
| AC2 | The `set -e` suppression rule is documented in `testing_policy.md` under `run_test` | `grep -n "suppresses" docs/development/testing_policy.md` | accepted |
| AC3 | Draft file split: three files, registrations preserved (29 + 9 + 4 = 42), no duplicated functions, all under 1000 lines | `bash scripts/check_test_liveness.sh`; line counts | accepted |
| AC4 | Cross-family helpers live in `tests/libs/draft_fixtures.sh` per the shared-fixtures rule | review | accepted |
| AC5 | Full suite green, liveness clean, lint gate clean | `bash scripts/run_tests.sh`; `scripts/check_test_liveness.sh`; `scripts/lint.sh` | accepted |
| AC6 | AGENT_FEEDBACK `run_test` entry closed; the split's M3 backpressure roadmap row added and checked | `grep "run_test" devlog/AGENT_FEEDBACK.md`; `grep "test_draft_workflow" devlog/roadmap_future.md` | accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`tests/test_routing.sh`](tests/test_routing.sh) | Inert `test_autosave_loop_survives_failing_ticks` rework (AC1) |
| [`docs/development/testing_policy.md`](docs/development/testing_policy.md) | `set -e` suppression rule (AC2) |
| [`tests/test_draft_workflow.sh`](tests/test_draft_workflow.sh) | Draft family after split (AC3) |
| [`tests/test_confirm_workflow.sh`](tests/test_confirm_workflow.sh) | New confirm family file (AC3) |
| [`tests/test_reject_workflow.sh`](tests/test_reject_workflow.sh) | New reject family file (AC3) |
| [`tests/libs/draft_fixtures.sh`](tests/libs/draft_fixtures.sh) | New shared fixture lib (AC4) |
| [`devlog/AGENT_FEEDBACK.md`](devlog/AGENT_FEEDBACK.md) | `run_test` entry closed (AC6) |
| [`devlog/roadmap_future.md`](devlog/roadmap_future.md) | Split row under M3 backpressure (AC6) |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `run_test` itself stays as-is | Removing the tick-status absorption would abort the suite on the first failing test; the property is documented, not changed | this handover |
| Split by workflow family (draft / confirm / reject), helpers by the 2+ files rule | Testing-policy shared-fixtures boundary | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The suite count 930 -> 1002 across the certified check-in stems from test additions in the review-findings fix commits before this iteration, not from the split (42 == 42 registrations) | observation | no code impact |
| The 20260919-19 deferred item named "M3 backpressure group" as the split's destination; no roadmap_future row existed for it (discrepancy 5) | steering | this handover -- row added and checked |

## Completed

| File | Change |
|---|---|
| `tests/test_routing.sh` | `test_autosave_loop_survives_failing_ticks` -> fresh-`bash`-probe pattern (marker file, real `set -euo pipefail`); mutation-verified |
| `docs/development/testing_policy.md` | `run_test` docs: suppression consequence + observable-outcome / fresh-probe rule |
| `tests/test_draft_workflow.sh` | 1102 -> 632 lines; draft/ingest/resolve family |
| `tests/test_confirm_workflow.sh` | New, 303 lines; confirm family + conflict fixtures |
| `tests/test_reject_workflow.sh` | New, 101 lines; reject family |
| `tests/libs/draft_fixtures.sh` | New; `draft_branch`, `_test_draft_run`, `_current_branch`, `_branch_exists` |
| `devlog/AGENT_FEEDBACK.md` | `run_test` entry -> `state: closed` |
| `devlog/roadmap_future.md` | M3 backpressure: split row added and checked `[x]` |

## Deferred items

| Item | Reason | Destination |
|---|---|---|
| ShellCheck as a git hook | not this iteration | M3 backpressure group |

## What's Next

The M3 backpressure group holds two open rows: mount-delivery hooks (constraint change) and ShellCheck as a git hook. Either is a small-to-medium next iteration with offline verification.
