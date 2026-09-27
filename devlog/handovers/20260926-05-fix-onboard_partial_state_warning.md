# Agent Handover

**Date:** 2026-09-26
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Close register row 161 (the onboard partial-state warning is unpinned), running as unit U-161 of the read-through rectification under the draft `/auto` dispatch template. The campaign had recorded that this row needs a production change; the primary established that the change is `errtrace`.

## Scope

`scripts/onboard.sh` and `tests/test_onboard.sh`. No other file.

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| A failure after the first mkdir prints the partial-state warning and exits non-zero | the new subprocess unit | Primary [x] - `test_onboard_warns_partial_state_on_failure_after_first_mkdir` |
| The provider-hook failure attribution is not swallowed or duplicated | `test_provider_setup_hook_failure_aborts` | Primary [x] - still green under the trap |
| Success path unchanged | the existing fresh-onboard units | Primary [x] |
| The sourced path's option set is unchanged | no `set -E` at top level | Primary [x] - `set -E` sits inside `main()` only |
| Suite green, lint clean | `bash scripts/run_tests.sh`, `bash scripts/lint.sh` | Primary [x] - 990 tests across 65 files, 0 failed; 3 gates, 0 findings |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Enable `errtrace` (`set -E`) inside `main()` just before the trap | bash does not propagate an ERR trap into called functions without `errtrace`; scoping to `main()` keeps the sourced path's option set untouched (the test file sources onboard.sh per row 163) | this handover; the comment in `main()` |
| Drive the unit as a subprocess with `--yes` against a `.workspace`-as-file fixture | the second mkdir then fails after the first succeeded, which is the exact failure the warning exists for | this handover; the BDD block in the test |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The warning was not merely unpinned: without `errtrace`, the ERR trap installed in `main()` never fires inside `_run_onboard`/`_run_refresh`, so a mid-onboard failure printed nothing at all | correctness | the production change of this unit; the row was recorded as needing one with no detail |

## Completed

| File | Change |
|---|---|
| `scripts/onboard.sh` | `set -E` in `main()` before `trap '_maybe_cleanup' ERR`, with a comment naming the errtrace reason |
| `tests/test_onboard.sh` | `test_onboard_warns_partial_state_on_failure_after_first_mkdir` and its registration |
| `devlog/roadmap.md` | the rectification row records row 161 closed |
| `devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl` | row 161 status flipped to resolved |
| this handover | written after verification, per `/auto` Step 5 |

## Deferred items

The run review, per `/auto` Step 6.

## What's Next

The run review: sweep the cheap classes over `git diff <run-base>..HEAD`, then the bounded review loop.

Read at iteration start: the `/auto` template, this handover, and the two sibling U-handovers.

**Conclusions from this iteration:** the register was right that the row needed a production change but silent on what it was; the primary's isolation probe found it before dispatch, and the unit then pinned both halves of the contract - the trap fires and the warning names the sandbox dir.
