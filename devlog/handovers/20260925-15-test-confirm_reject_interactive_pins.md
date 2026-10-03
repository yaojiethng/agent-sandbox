# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Pin the rules the confirm, reject and interactive workflow rows name: the pre-work guards, the failure arms, both script entry points, the display contract, the autosave channel and the non-tty warning.

## Scope

Unit U3 of the coverage campaign (roadmap row 83), test files only. Register rows 243, 244, 245, 250, 251, 252, 260, 261, 263.

## Carried forward

| Item | From handover |
|---|---|
| The coverage campaign, unit U3 | [20260925-14-test-draft_and_apply_workflow_pins](20260925-14-test-draft_and_apply_workflow_pins.md) |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| All nine rows are pinned, each by a unit that fails when the rule is removed | the bites | Agent [x] - nine pinned, no mutation survived |
| Both scripts are exercised as scripts, not only as sourced functions | the entry-point units | Agent [x] |
| The autosave channel's two ordering mechanisms are observable | the two ordering units | Agent [x] |
| Production files are unchanged and byte-identical after every mutation | `git diff` and `cmp` | Agent [x] |
| Lint clean and the suite green | `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | Agent [x] - clean; 839 units, 64 files, 0 failed |

## Hot files

| File | Why in scope |
|---|---|
| [`tests/test_confirm_workflow.sh`](../../tests/test_confirm_workflow.sh) | the three guards, the target-exists check, the failure arm, the script entry point, the non-tty warning |
| [`tests/test_reject_workflow.sh`](../../tests/test_reject_workflow.sh) | the two guard verdicts, the branch-already-absent arm, the script entry point |
| [`tests/test_interactive_session_select.sh`](../../tests/test_interactive_session_select.sh) | the display contract, the autosave channel, both ordering mechanisms |
| [`scripts/workflows/confirm.sh`](../../scripts/workflows/confirm.sh), [`scripts/workflows/reject.sh`](../../scripts/workflows/reject.sh), [`scripts/workflows/interactive.sh`](../../scripts/workflows/interactive.sh) | mutation subjects, unmodified |
| [`devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl`](../discussions/20260924-design-active-test_suite_readthrough.jsonl) | nine rows resolved, one added |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The branch-override surface is recorded as a new row rather than fixed here | it is a production key-injection concern, and this unit is test-only | register row 315 |

## Findings

| Finding | Type | Impact |
|---|---|---|
| A `.draft-state` key can override the caller's own variables: `draft_validate_branch` parses every key with `printf -v`, so a crafted `CURRENT_BRANCH` makes `reject_run` act on a branch that is not checked out. Discovered while reaching the branch-already-absent arm. | bug | next iteration |
| The non-tty warning was a documented behaviour with no unit; the message on the unattended path is now asserted. | bug | current iteration |

## Completed

| File | Change |
|---|---|
| `tests/test_confirm_workflow.sh` | units for the three pre-work guards, the target-exists check, the NEW-mode rollback, the script entry point, and the non-tty warning |
| `tests/test_reject_workflow.sh` | units for the two guard verdicts, the branch-already-absent arm, and the script entry point |
| `tests/test_interactive_session_select.sh` | units for the display contract, the autosave channel, and both ordering mechanisms |
| `devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl` | nine rows resolved; row 315 added |
| `devlog/roadmap.md` | row 83 records the slice |

## Deferred items

None beyond the register: row 315 is a production fix for a later unit.

## What's Next

Unit U4: the session family (inventory, env, save policy, routing, resume).

Read at iteration start: this handover, register row 315, and roadmap row 83.

**Conclusions from this iteration:** every one of the nine rows was a thin fixture, not a code defect, and the two script entry-point rows were the largest gaps: a suite that sources a workflow never exercises `main`.
