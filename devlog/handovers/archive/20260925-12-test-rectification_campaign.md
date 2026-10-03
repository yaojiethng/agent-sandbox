# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Land the test-suite rectification campaign: apply the two rules the conventions edit wrote (a test file is named for its subject; one unit per case) to the ten register rows that named a placement or duplication defect, and create the suites the read-through found missing.

## Scope

The whole `tests/` tree plus two production-free surfaces: `tests/stubs/docker` (row 145) and `docs/development/test_harness_mechanism.md` (row 185). Rows 3, 52, 73, 79, 145, 147, 164, 172, 185, 248, 281 of `devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl`. No change to `src/` or `scripts/`, apart from the eight duplicate units the campaign deleted from the suites that held them.

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| Each campaign row is resolved | the register's `status` field for the eleven ids | Agent [x] |
| Each subject named in a row has its own file, or its units sit in the file named for it | the file list below | Agent [x] |
| No duplicate unit survives where a stronger one covered the case | the deletions listed under Completed | Agent [x] |
| The docker stub's label filters select | the new prune unit fails when the filter is disabled | Agent [x] |
| The new suites fail when their subject changes | seven bites, each naming a failing unit | Agent [x] |
| Lint clean | `bash scripts/lint.sh` | Agent [x] - 3 gates, 0 findings |
| Suite green | `bash scripts/run_tests.sh` | Agent [x] - 799 units, 64 files, 0 failed |

## Hot files

| File | Why in scope |
|---|---|
| [`tests/test_routing.sh`](../../tests/test_routing.sh) | lost three near-duplicate units and the appended block that re-covered them (row 52), and the five autosave units that read the save policy (row 3b) |
| [`tests/test_confirm_workflow.sh`](../../tests/test_confirm_workflow.sh) | two removed-design units replaced by one unit of today's guard (row 248) |
| [`tests/test_env.sh`](../../tests/test_env.sh) | gained four direct `env_load` units (row 73) |
| [`tests/test_session_env.sh`](../../tests/test_session_env.sh) | lost six units, four of them to the parser's suite (row 73) |
| [`tests/test_session_save_guard.sh`](../../tests/test_session_save_guard.sh) | gained the five autosave units; lost the `.export-status` units and the duplicate guard unit |
| [`tests/test_common_lib.sh`](../../tests/test_common_lib.sh) | lost the harness-helper units (row 3b) |
| [`tests/test_runner_selftest.sh`](../../tests/test_runner_selftest.sh) | gained them, with its header list extended |
| [`tests/test_interface_contract.sh`](../../tests/test_interface_contract.sh) | lost the three `_check_interface_contract` units (row 3b) |
| [`tests/test_trace_build.sh`](../../tests/test_trace_build.sh) | gained the missing-label unit, and the drift unit now names the ERROR marker |
| [`tests/test_diff_export.sh`](../../tests/test_diff_export.sh) | lost five `_write_export_status` units |
| [`tests/test_export_status.sh`](../../tests/test_export_status.sh) | new: the record's writer and readers |
| [`tests/test_run_agent.sh`](../../tests/test_run_agent.sh) | absorbed `tests/test_trace_start.sh` (row 172) |
| [`tests/test_dry_run_harness.sh`](../../tests/test_dry_run_harness.sh) | new: the check framework's counters, summary arms, and record writer (row 3a) |
| [`tests/test_resume_list.sh`](../../tests/test_resume_list.sh) | new: `resume_list.sh` had no unit anywhere (row 79) |
| [`tests/stubs/docker`](../../tests/stubs/docker) | `ps` and `volume ls` honour `--filter label=` against a label map (row 145) |
| [`docs/development/test_harness_mechanism.md`](../../docs/development/test_harness_mechanism.md) | names the guards the harness cannot observe (row 185) |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Three rows closed by deletion instead of by moving a unit | `tests/test_guards.sh` already asserted the guard's three verdicts and its silence, and `tests/test_env.sh` already asserted the parser's comments, trimming and invalid-key rules. Moving the weaker unit in would have created the duplicate pair Anti-Pattern 9 names. The one clause the survivor lacked folded into it. | the surviving units' comments |
| The parser's cases were rewritten against `env_load`, not carried across | the units in the session suite reached the parser through `session_env_common_init` and used `make_sandbox` fixtures; a verbatim move would have put consumer fixtures in the parser's suite | this handover |
| `test_apply_count.sh` became `test_apply_workflow.sh`, and `test_session.sh` became `test_session_state.sh` | a file is named for its subject: the first was named for a metric, the second for `libs/session.sh`, which does not exist | this handover |
| `tests/test_export_status.sh` was created for a lib two consumer suites were testing | the campaign's rule is one file per subject; leaving the units in the diff and save suites was the mixed-file defect the row named | this handover |
| The docker stub filters rather than only logs | the stub already logged its arguments, so presence and spelling were assertable; what no unit could catch was a query returning another project's resource. The label map makes the negative case testable, and an unset map keeps every existing suite's behaviour. | the stub's header |
| The misnamed trace family merged into `tests/test_run_agent.sh` rather than renamed | both of its helpers invoke `run_agent.sh`, so a rename would have left two files for one subject | the merged file's header |
| The five unattended-path guards are documented, not tested | the harness cannot present a TTY, a prompt, or stdin, so the failure they prevent is unobservable. The finding asked for the limitation to be named, and the note says a green suite is not evidence that removing one is safe. | `test_harness_mechanism.md` |
| One commit for the campaign | the campaign is one unit of approval: the rules, the moves, and the new suites answer one question, and the operator exports the branch once | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Eight of the campaign's units were duplicates of a stronger unit in the destination suite | duplication | the campaign deleted them; a placement row can end in a deletion, and checking the destination first is the cheap step |
| `tests/test_common_lib.sh` registered one block of units before the file's remaining unit definitions, under a `Run all` banner that read as the end of the file | layout | the registrations now form one block after the last definition |
| `tests/mutations/bite_diff.sh` names test files, so a rename breaks the corpus's evidence | record coupling | a rename now includes a grep of `tests/mutations/` |
| Rows 34 and 181 of the register point at `tests/test_trace_start.sh`, which this campaign removed | stale pointer | both rows stay open, and their work now reads the merged `tests/test_run_agent.sh` |
| `test_interface_contract.sh`'s drift unit asserted less than the unit it absorbed: the refusal's `ERROR` marker was unpinned | coverage gap | the marker is asserted in the surviving unit |

## Completed

| File | Change |
|---|---|
| `tests/test_routing.sh` | three duplicate units and a merge artefact removed; five autosave units leave for the save-policy suite; the save-policy source drops |
| `tests/test_confirm_workflow.sh` | two removed-design units become one guard unit |
| `tests/test_env.sh` | four units: the inline-comment pin, the whitespace-only-key and bare-CR regression, the indented-comment regression, and key whitespace with a CRLF ending |
| `tests/test_session_env.sh` | six units and their registrations removed; the Covers list points at the parser's suite |
| `tests/test_session_save_guard.sh` | five autosave units arrive with the libraries they read; four `.export-status` units leave; the duplicate guard unit goes; Covers lists the autosave cycle |
| `tests/test_common_lib.sh` | the harness-helper units leave; the run block moves after the last definition |
| `tests/test_runner_selftest.sh` | five harness-helper units arrive; the header's list gains item 14 |
| `tests/test_interface_contract.sh` | the `_check_interface_contract` section and the build source leave; the header names the new home |
| `tests/test_trace_build.sh` | the missing-label unit arrives; the drift unit asserts the ERROR marker |
| `tests/test_diff_export.sh` | the `_write_export_status` section leaves; Covers follows |
| `tests/test_export_status.sh` | new file, nine units |
| `tests/test_run_agent.sh` | the trace family (23 units) arrives and `tests/test_trace_start.sh` is removed |
| `tests/test_dry_run_harness.sh` | new file, ten units |
| `tests/test_resume_list.sh` | new file, fifteen units |
| `tests/test_prune.sh` | one unit: the container query selects only this project's containers |
| `tests/test_guards.sh` | the survivor checks both dirty shapes; the accepting arm gains a unit; Covers names six functions |
| `tests/test_apply_workflow.sh` | renamed, header and `test_done` follow |
| `tests/test_session_state.sh` | renamed; the header names its real subject |
| `tests/mutations/bite_diff.sh` | `FILES` follows the rename |
| `tests/stubs/docker` | `_labels_for`, `_label_filters`, `_filter_by_label`; `ps` and `volume ls` filter |
| `docs/development/test_harness_mechanism.md` | `## What the harness cannot observe` |
| `devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl` | eleven rows resolved |
| `devlog/roadmap.md` | the campaign row records the landing |
| `devlog/AGENT_FEEDBACK.md` | the wrong-site mutation form added to the false-survivor entry |

## Deferred items

| Item | Reason | Where it goes |
|---|---|---|
| Rows 34 and 181 | both are coverage gaps whose units read `run_agent.sh`, which this campaign has just re-homed | the campaign's next slice |
| The `apply_and_commit` unit's move from `tests/test_apply_workflow.sh` to `tests/test_diff_workflow.sh` | the source unit builds its fixture with a local `_make_repo`; the destination uses `make_committed_repo`. The move needs the fixture rewritten, not copied. | the campaign's next slice |
| `session_state.sh`'s remaining split: `container_contract_check` in `tests/test_reasoner_container_contract.sh` | the units there assert the reasoner's contract, and their fixtures are that contract's, not the library's | not planned; recorded here so a later reader does not re-open it |
| The `.env` parser's two remaining `ENV_REL` units in `tests/test_session_env.sh` | they drive `session_env_common_init` and assert the consumer's `ENV_FILE`, so their subject is the consumer | not planned |

## What's Next

The remaining test-class rows are coverage gaps in suites that already exist, not placement work: rows 21, 34, 181 and the mutation-testing placement row are the named ones in this sub-milestone.

Read at iteration start: this handover, the campaign row in the roadmap, and `docs/development/testing_policy.md` section Test Placement.

**Conclusions from this iteration:** eight of the campaign's units were deleted rather than moved, because the destination suite already covered the case with stronger assertions. The placement rule and Anti-Pattern 9 together make that the cheapest ending, but only if the destination is read first: two of the campaign's slices were planned as moves and finished as deletions.
