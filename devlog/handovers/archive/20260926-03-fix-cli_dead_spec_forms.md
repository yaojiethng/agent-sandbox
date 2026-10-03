# Agent Handover

**Date:** 2026-09-26
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Close register row 42 (two dead spec forms in `src/libs/cli.sh`), running as unit U-42 of the m3.1 read-through rectification under the draft `/auto` dispatch template.

## Scope

`src/libs/cli.sh` and `tests/test_cli_lib.sh`. No other file. Production and test deletion in one unit; the roadmap row and the register update ride the same commit.

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| The three live spec forms still work | the suite plus a live probe | Primary [x] - clear probe + unit 21 in `test_cli_lib.sh` |
| No caller uses either deleted form | grep across `scripts/` and `src/` | Subagent [x] - 12 call sites, none uses the empty-var or literal form |
| A mutation of each live form fails the file that pins it | the value-form and boolean-form bites | Primary [x] - re-ran both, each fails `test_cli_lib.sh` at the pinning units |
| Suite green, lint clean | `bash scripts/run_tests.sh`, `bash scripts/lint.sh` | Primary [x] - 987 tests across 65 files, 0 failed; 3 gates, 0 findings |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Delete, per the operator's release | the finding's candidate was "delete the literal and empty-var forms with their doc text, or make the literal arm reachable"; the operator chose the deletion branch | this handover; the run plan in session chat |
| Delete the U9 unit that pinned the literal arm | it asserts the literal consumption the deletion removes; keeping it would fail the suite | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| `tests/test_parse_args_derived_name_value_flag` pinned the empty-var form (`--branch-from=`) that the deletion removes; the subagent deleted it together with the literal-arm unit | scope change | folded into this unit |
| `tests/mutations/bite_cli.sh` hard-codes `cli.sh` line numbers, so the released deletions shift its targets and its C6 mutation targets `${a##*=}` where the code uses `${a#*=}` | bug | flagged for a later pass, not touched |

## Completed

| File | Change |
|---|---|
| `src/libs/cli.sh` | deleted the literal spec arm (the compiler `*)` branch, the walker `literal` branch, and the doc line) and the empty-var fallback (the empty-`var` derive line and its two doc lines) |
| `tests/test_cli_lib.sh` | deleted `test_parse_args_derived_name_value_flag` and `test_collect_true_literal_spec_not_sinked` with their registrations; header updated; unit count 23 to 21 |
| `devlog/roadmap.md` | register row 42 updated to resolved |
| `devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl` | row 42 status flipped to resolved |
| this handover | written after verification, per `/auto` Step 5 |

## Deferred items

The `tests/mutations/bite_cli.sh` line-number and `${a##*=}` mismatch (registers as a bug finding above). The register's remaining open rows and the other rectification units (U-129, U-161) run in the same run.

## What's Next

U-129 (uninstall symlink guard) and U-161 (onboard partial-state warning) dispatch next in the same run; then the run review.

Read at iteration start: the `/auto` template, this handover, and the two sibling U-handovers.

**Conclusions from this iteration:** the deleted forms were documented but unreachable by any caller; the empty-var fallback had exactly one test pinning it, which is why the deletion needed the unit's consent. The `/auto` run shape held: the subagent's report named its own extra deletion before the primary verified it against the tree.
