# Agent Handover

**Date:** 2026-09-26
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Close the production-change half of register row 129 (uninstall removes whatever sits at the CLI path without checking it is the harness symlink), running as unit U-129 of the read-through rectification under the draft `/auto` dispatch template.

## Scope

`scripts/install.sh` and `tests/test_install.sh`. No other file.

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| A real file at the CLI path is refused with rc 1, left untouched, and the error names the path (sourced and standalone) | `tests/test_install.sh` | Primary [x] - the new refusal unit, both invocation shapes |
| The harness symlink is still removed with rc 0 | the removal units | Primary [x] - `test_install_uninstall_removes_symlink`, `test_install_standalone_entry_point_uninstalls` |
| An absent target is a silent success | the new absent-target unit | Primary [x] |
| A mutation of the refusal guard fails the refusal unit; a mutation of the target match fails the removal units | the two bites | Primary [x] - re-ran both, each restores byte-identical |
| Suite green, lint clean | `bash scripts/run_tests.sh`, `bash scripts/lint.sh` | Primary [x] - 989 tests across 65 files, 0 failed; 3 gates, 0 findings |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Refuse unless the path is a symlink whose readlink target is exactly `$REPO_ROOT/scripts/agent-sandbox.sh` | that is the link `do_install` creates; an absent target stays a silent success | this handover |
| Silence means no output on an absent target | a reading the subagent flagged; the old code printed "Removed" on an absent target, the new code prints nothing | this handover; noted for the operator |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The standalone-entry-point test half of row 129 had already landed in the U4 slice; only the refusal guard and its unit were owed here | none | covered by this unit |

## Completed

| File | Change |
|---|---|
| `scripts/install.sh` | `do_uninstall` refuses a path that is not the harness symlink (real file or foreign symlink), naming the path on stderr and returning 1; absent target is silent; header and function docs state the contract |
| `tests/test_install.sh` | two units: `test_install_uninstall_refuses_real_file` (sourced and standalone) and `test_install_uninstall_absent_target_succeeds`; Covers list and registrations updated |
| `devlog/roadmap.md` | the rectification row records row 129's production change landed; the register row flips in the same commit |
| `devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl` | row 129 status flipped to resolved |
| this handover | written after verification, per `/auto` Step 5 |

## Deferred items

U-161 (onboard partial-state warning) dispatches next in the same run, then the run review.

## What's Next

U-161 dispatch; then the run review over `git diff <run-base>..HEAD`.

Read at iteration start: the `/auto` template, this handover, and the sibling U-handovers.

**Conclusions from this iteration:** the row split cleanly across the already-landed test half and the guard half; the subagent read the "silent success" phrase its own way and flagged the reading, which the unit now pins - one term, one meaning, asserted.
