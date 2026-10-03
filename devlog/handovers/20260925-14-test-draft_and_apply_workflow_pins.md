# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Pin the rules the draft and apply workflow rows name: the interactive branches, the guard verdicts, the rollback and uncommitted-only source legs, and the two scripts' entry points.

## Scope

Unit U2 of the coverage campaign (roadmap row 83), test files only. Register rows 225, 228, 229, 231, 232, 233, 235, 236, 238, 239, 241 (the draft workflow), 209, 210, 211, 215, 216, 217, 265 (the apply workflow), and the two suites' own defects 224, 227, 230, 213, 220.

## Carried forward

| Item | From handover |
|---|---|
| The coverage campaign, unit U2 | [20260925-13-test-pin_hint_selection_and_health_gate](20260925-13-test-pin_hint_selection_and_health_gate.md) |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| The draft workflow's named rules are each pinned by a unit that fails when the rule is removed | the bites | Agent [x] - fifteen units, thirteen bites proven |
| The apply workflow's named rules are each pinned | the bites | Agent [x] - six units, five bites proven |
| The suites' own defects are corrected: the scripts are driven as scripts, the divergence warning is asserted by the unit named for it, the fork point is pinned, and the `_apply_patch_file` calls pass the three arguments the function takes | the units | Agent [x] |
| Row 239's rule, an unparseable export-directory name yielding an empty branch identity, is pinned | a unit | Agent [ ] - not pinned, because the line it names decides nothing; recorded as register row 313 |
| Production files are unchanged | `git diff --name-only -- scripts/ src/` | Agent [x] - empty |
| Lint clean and the suite green | `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | Agent [x] - clean; 823 units, 64 files, 0 failed |

## Hot files

| File | Why in scope |
|---|---|
| [`tests/test_draft_workflow.sh`](../../tests/test_draft_workflow.sh) | fifteen units added, including the script entry point and the error paths |
| [`tests/test_diff_workflow.sh`](../../tests/test_diff_workflow.sh) | six units added, and the `_apply_patch_file` call sites corrected |
| [`scripts/workflows/draft.sh`](../../scripts/workflows/draft.sh), [`scripts/workflows/apply.sh`](../../scripts/workflows/apply.sh) | mutation subjects, unmodified |
| [`devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl`](../discussions/20260924-design-active-test_suite_readthrough.jsonl) | twenty-two rows resolved, two rows added |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A surviving bite whose target line decides nothing is recorded as a code finding, not chased as a test gap | no test can fail on a redundant line; the correct end is the deletion | register rows 313 and 314 |
| `tests/test_draft_workflow.sh` declares `# TEST_DEADLINE: 15` | the new units drive the workflow scripts as subprocesses and need more than the suite default | the file header |

## Findings

| Finding | Type | Impact |
|---|---|---|
| `main`'s `CHANNEL_ARG` default in `draft.sh` is shadowed by `resolve_source_for_draft`'s own default, so the line decides nothing and no unit can fail on it. | bug | next iteration |
| `apply_run`'s `exit $?` is unreachable with a non-zero value under errexit, so the line decides nothing. | bug | next iteration |
| A bite tripped `tests/test_seed_volume.sh`, which does not source the workflow under test. A file failing while not under test is the load-sensitive phantom-report class the liveness gate already records, and it is the reason the campaign runs one suite at a time. | contradiction | roadmap |

## Completed

| File | Change |
|---|---|
| `tests/test_draft_workflow.sh` | fifteen units: the interactive branch with both channel and bundle, the metadata refusals, the base-resolves check, force forwarding, the uncommitted-failure rollback, the uncommitted-only source, the presence check, both patch-collection error paths, the source and patch guards, the required count, and the clean-tree force case; plus the script entry point, the divergence warning, and the fork point |
| `tests/test_diff_workflow.sh` | six units: the required-argument guard, the diff-not-found guard, the project-directory refusal, the interactive confirm and abort, branch and force forwarding, the checkout arm, and the empty-diff count under errexit |
| `devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl` | twenty-two rows resolved; rows 313 and 314 added for the two redundant lines |
| `devlog/roadmap.md` | row 83 records the slice |

## Deferred items

None beyond the register. Row 239 stays open, unpinned; rows 313 and 314 are code deletions.

## What's Next

Unit U3: the confirm, reject and interactive workflows.

Read at iteration start: this handover, register rows 239, 313 and 314, and roadmap row 83.

**Conclusions from this iteration:** a coverage-gap row whose rule survives every mutation because the line is redundant is a code finding wearing a test row's clothes; the two found here are deletions, not pins.
