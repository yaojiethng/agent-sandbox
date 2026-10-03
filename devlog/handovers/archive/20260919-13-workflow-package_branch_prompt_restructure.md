# 20260919-13-workflow-package_branch_prompt_restructure

- **Handover:** 20260919-13
- **Type:** Workflow
- **Milestone:** M2.6 / M2.6.7 (Interface Contract Compatibility)
- **Dates:** 2026-09-19
- **Status:** Closed

## What this iteration does

Restructures the `package-branch` prompt template
(`src/reasoning/agent/prompts/package-branch.md`) to fix the stale-summary
failure and align the migration-guide section with the documentation policy.

## Root cause

The template handed the agent a runnable command with a hardcoded literal
`--bundle-summary=add_format_patch_support`. An agent copying the block verbatim
exported every bundle under that same summary regardless of content -- the "10
prior bundles, all identical summaries" pattern. Code cannot generate a summary;
only the agent can, and the template was actively supplying a copyable wrong
value.

## Fix

- Step order: **1** state the summary guidelines and require the agent to
  propose the summary (and draft the guide-content sections) BEFORE running the
  script; **2** run the packaging script with the summary chosen in step 1;
  **3** write the migration guide as assembly of the earlier draft.
- Removed the copyable literal and the stale `add_format_patch_support` "good
  summary" example. The summary must be derived from the export's own commits.
- Migration-guide template: reordered sections (`What changed and why`, `API
  breaking changes`, `Changed files`, `Verification`, `How to apply`), each with
  a content rule. `Deleted code` and the stale `Snapshot invariant` sections
  were dropped.
- `Verification` states the operator runs the unit test suite, adding only
  host-only checks such as `make dry-run`.
- Applied the documentation-policy line-wrapping rule (one paragraph per
  physical line) to the template prose.

## Files in scope

- `src/reasoning/agent/prompts/package-branch.md` -- full restructure.

## Acceptance criteria

| # | Criterion |
|---|---|
| AC1 | The prompt no longer contains the `add_format_patch_support` literal or any copyable summary |
| AC2 | Step 1 requires the agent to state the summary and draft the guide-content sections before running packaging |
| AC3 | The migration guide template follows the reordered section layout with content rules |
| AC4 | Template prose uses one paragraph per physical line |

## Notes

This is the delivery commit for the template restructure only. The code-level
guard (rejecting known placeholder literals or detecting label reuse) was
considered and rejected -- it would add redundant literals and test burden for
no benefit. Template-only fix.
