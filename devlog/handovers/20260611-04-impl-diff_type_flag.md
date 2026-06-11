# Agent Handover

**Session date:** 2026-06-11
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Implementation
**Status:** Active

## Objective

Add `--diff-type` CLI flag to `agent-sandbox apply` (and corresponding `DIFF_TYPE` Makefile variable) so non-interactive apply can select between `uncommitted.diff` and `all-changes.diff`.

## Scope

1. Add `--diff-type=uncommitted|all-changes` to `apply.sh` flag parser
2. Update non-interactive path in `apply.sh` to use the resolved session dir + diff type
3. Add `DIFF_TYPE` to Makefile template's `apply` target
4. Update usage docs

## Hot files

| File | Reason |
|---|---|
| `scripts/workflows/apply.sh` | Add `--diff-type` flag, update non-interactive path |
| `scripts/templates/Makefile.template` | Add `DIFF_TYPE` to apply target |

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | `--diff-type` is parsed in apply.sh | grep for `diff-type` in apply.sh | |
| 2 | Non-interactive apply uses `DIFF_TYPE.resolve` path | grep for `DIFF_TYPE\|diff_type` in apply non-interactive path | |
| 3 | Makefile template passes `DIFF_TYPE` to apply | grep for `DIFF_TYPE` in Makefile.template | |
| 4 | `bash -n` on both files | syntax check | |
| 5 | Tests pass | `bash scripts/run_tests.sh` | |
