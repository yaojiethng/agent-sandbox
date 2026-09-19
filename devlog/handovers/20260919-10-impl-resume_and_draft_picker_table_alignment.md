# 20260919-10-impl-resume_and_draft_picker_table_alignment

- **Handover:** 20260919-10
- **Type:** Implementation
- **Milestone:** M2.6 / M2.6.7 (Interface Contract Compatibility)
- **Dates:** 2026-09-19
- **Status:** Closed

## What this iteration does

Reworks the `resume --interactive` picker and the draft bundle picker so they
share one table convention: index, current branch, AGE (wall-clock) and STATE
(commit distance).

## What changed

- `project_current_branch()` never returns empty -- branch name, `<short-sha>
  (detached)`, or `(absent)`.
- Resume picker aligns to a fixed table layout with a 1-based zero-padded index
  column (`01:`..`10:`) and an AGE column.
- Draft bundle picker gains the same STATE/AGE/current-branch columns.
- AGE/STATE values swapped by language meaning: STATE carries commit distance
  (`1 commit ago`), AGE carries wall-clock (`4M ago`) -- consistent across BOTH
  the resume table and the draft picker.
- Draft AGE cell reads `exported N ago`, reflecting the export moment (the
  `.export-status TIMESTAMP`), never the container or session start. A bare
  `---` cell stays bare.

## Files in scope

- `src/libs/session_inventory.sh` -- shared `project_branch_age`,
  `project_current_branch`.
- `src/libs/resume_list.sh` -- `_resume_branch_age` thin delegate; table layout.
- `scripts/workflows/interactive.sh` -- `interactive_pick` index/alignment; AGE
  cell text.
- `scripts/workflows/draft.sh` -- draft picker STATE/AGE/current-branch columns.
- `tests/test_resume.sh`, `tests/test_interactive_session_select.sh`,
  `tests/test_draft_workflow.sh` -- coverage for the new columns and values.

## Acceptance criteria

| # | Criterion |
|---|---|
| AC1 | `project_current_branch()` returns a non-empty value for branch, detached, and absent cases |
| AC2 | Resume and draft tables both show STATE=commit-distance and AGE=wall-clock |
| AC3 | Draft AGE cell reads `exported N ago` and reflects the export timestamp |
| AC4 | Index column is 1-based and zero-padded to fixed width in both pickers |
| AC5 | Suite green (892/892 at end of iteration) |

## Operator gate

Visual confirmation of the picker layout is operator-run on the host (the
pickers render in an interactive terminal).