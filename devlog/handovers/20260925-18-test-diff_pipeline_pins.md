# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Pin the rules the diff pipeline rows name: the diff library, diff_export, package_branch and the draft-state record.

## Scope

Unit U6 of the coverage campaign (roadmap row 83), test files only. Register rows 57, 58, 59, 60, 61, 63-66, 68-71, 82-85, 39, 40.

## Carried forward

| Item | From handover |
|---|---|
| The coverage campaign, unit U6 | [20260925-17-test-host_leaf_pins](20260925-17-test-host_leaf_pins.md) |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| The seven test-class rows are pinned by a unit that fails when their rule is removed | the bites | Agent [x] |
| The rows whose `action_kind` is none or code stay open | the register | Agent [x] - twelve rows: the note rows and the two code rows |
| Production files are unchanged and byte-identical after every mutation | `git diff` and `cmp` | Agent [x] |
| Lint clean and the suite green | `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | Agent [x] - clean; 906 units, 64 files, 0 failed |

## Hot files

| File | Why in scope |
|---|---|
| [`tests/test_diff_helpers.sh`](../../tests/test_diff_helpers.sh) | the untracked-staging restore and the whitespace policy |
| [`tests/test_diff_export.sh`](../../tests/test_diff_export.sh) | the export status record |
| [`tests/test_package_branch.sh`](../../tests/test_package_branch.sh) | the preflight, the dispatcher per-patch record, the subject sanitising, the baseline refusal |
| [`tests/test_draft_state.sh`](../../tests/test_draft_state.sh) | the state record's fields and key normalisation |
| `src/libs/diff.sh`, `diff_export.sh`, `package_branch.sh`, `draft_state.sh` | mutation subjects, unmodified |
| [`devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl`](../discussions/20260924-design-active-test_suite_readthrough.jsonl) | seven rows resolved |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The note and code rows in this group are not campaign work | their `action_kind` is none or code: they are inputs to a design decision or a production fix | the register |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The grouping by subject file pulled twelve non-test rows into this unit, the third time a batch's row list needed filtering by `action_kind` before dispatch. The campaign's remaining units must filter first. | contradiction | roadmap |

## Completed

| File | Change |
|---|---|
| `tests/test_diff_helpers.sh` | units for the untracked-staging restore and the context-whitespace tolerance |
| `tests/test_diff_export.sh` | the export status success and error-summary units |
| `tests/test_package_branch.sh` | the preflight, per-patch record, subject sanitising, empty-message and baseline-refusal units |
| `tests/test_draft_state.sh` | the state record's field-completeness and key-normalisation units |
| `devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl` | seven rows resolved |
| `devlog/roadmap.md` | row 83 records the slice |

## Deferred items

None beyond the register: the twelve non-test rows stay open for the design lane or a `fix:` unit.

## What's Next

Unit U7: the entry points (agent-sandbox, run_agent, start_agent), filtered to `action_kind: test`.

Read at iteration start: this handover and roadmap row 83.

**Conclusions from this iteration:** the campaign's grouping must be recomputed from `action_kind: test` rows alone; the file-based grouping overstates every unit's size.
