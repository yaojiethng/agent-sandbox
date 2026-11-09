---
date: 2026-11-08
milestone: T7 - Harness Specialization / Sandbox Persistence
type: Implementation
status: Closed
---

# Handover - The draft lifecycle transition model and its mutation gate

## Objective

Close the state-model audit gaps in the draft, confirm and reject lifecycle by giving every transition an id, a contract and test-and-mutation evidence, and file the cross-chart audit as the next T7 row.

## Scope

This iteration continues the T7 row **Git boundary and repository state**, after handovers `20261108-02` and `20261108-03`. It targets the two statecharts those iterations produced: the package chart and the confirm chart in `docs/reference/draft_branch_statechart.md`. It adds the transition contract, the mapping gate, the strict mutation gate, the control rows, and the reject and package mutation rows. The delivery commit is `c5f4492d`. The delivery folds the four review remediations and the accepted non-blocking notes: equal-separated gate value flags, the table-authority statement, the `kv_read` ownership note, `--help` coverage for draft and reject, one resolved branch-point line, the chart-prefix and canonical-edge scanner gates, and mutation coverage for `draft_state.sh` and `guards.sh`. Round 7 accepted the code range before those notes landed.

The broader run of the same workflow over the other existing statecharts is filed as an open T7 row; this iteration does not run it. The `parse_args` help failure was found while pinning `C24` and is fixed here because the test cannot pass without it. The unrelated mutation catalog rows outside the diff pipeline remain report-only and are out of scope.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every Mermaid edge carries a transition id and one table row naming its subject, guard, invariant, precondition, postcondition, test and mutation. | `bash scripts/check_draft_statechart.sh` reports `clean across 43 transition(s)`. | Agent [x] |
| Every product transition names a real test function and a real mutation catalog row whose subject matches; an operator or host action states `none: reason` instead. | The same gate rejects a missing test, a missing mutation, a mismatched subject, a missing subject, an edge without a row and a row without an edge. | Agent [x] |
| Two same-event transitions from one state are either merged or carry exclusive guards. | The gate's ambiguity check; the package and confirm charts carry unique ids on every edge. | Agent [x] |
| The nine earlier mutation survivors are pinned: `C9`, `C14`, `C15`, `C17`, `C20`, `C21`, `C24`, `D6`, `D37`. | The draft subset of `MUTATION=1 bash scripts/run_tests.sh`: 61 proven, 4 controls, 0 required findings. | Agent [x] |
| Reject and package transitions have mutation rows. | Catalog rows `255`-`262`; the required subset proves every product row. | Agent [x] |
| The mutation tier has control rows and a required-subject verdict. | `bash tests/test_mutations_runner.sh`; the draft subset reports 4 control rows green. | Agent [x] |
| The draft statechart gate is part of the lint umbrella. | `bash scripts/lint.sh` reports clean across 25 gates. | Agent [x] |
| The affected suites and gates are green. | `test_draft_statechart` 16, `test_statechart` 10, `test_mutations_runner` 10, `test_draft_state` 16, `test_confirm_workflow` 27, `test_reject_workflow` 11, `test_draft_workflow` 62, `test_guards` 9; `scripts/check_shell.sh`, `scripts/lint.sh` (25 gates) and `scripts/check_draft_statechart.sh` clean. Scoped mutation runs: the 33 draft-subject rows are 32 proven and 1 control; catalog rows 263-272 are 10 proven. The full suite was not rerun after the review remediation, per the operator's relevant-set rule. | Agent [x] |
| The cross-chart state-machine audit is filed as an open T7 row. | `rg` over `devlog/roadmap.md`. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The transition id is the key the tests and the mutation catalog name. | An edge without an id cannot be addressed by a test or a mutation row, which is the audit gap the model had. | `docs/reference/draft_branch_statechart.md` |
| Do not merge `s5`/`s6` or `s9`/`s10`; resolve the earlier ambiguity with guards instead. | The pairs carry different package provenance and broken rules, and the ambiguous pairs themselves had different downstream outcomes. The defect was the label and the missing guard, not a duplicate state. | `docs/reference/draft_branch_statechart.md` |
| An operator or host transition states `none: reason` rather than inventing a product invariant. | The suite cannot drive an operator `git switch` or a host rewrite, and a false invariant would make the table look complete when it is not. | `docs/reference/draft_branch_statechart.md` |
| Keep the broad mutation corpus report-only; make the draft lifecycle the required subset of the general mutation runner. | The corpus carries pre-existing survivors and stale rows in unrelated subjects. The audit's obligation is the draft lifecycle, so the runner marks its subjects as required and leaves the rest report-only. | `scripts/mutations_run.sh`, `scripts/run_tests.sh` |
| Fix `parse_args` with `\|\| rc=$?` in the three workflow entry points. | `set -e` exited with the parse result before `main` could turn the help verdict into exit 0. The `--help` test exposed the dead branch. | `scripts/workflows/confirm.sh` |
| Test the `set -e` lines at process level with a git shim. | `run_test` runs each test with `set +e`; a sourced function therefore cannot prove a line that relies on errexit. The shim runs the workflow script as a process. | `tests/test_confirm_workflow.sh` |
| The chart is the visual model and the transition table is the contract; `Event` and `Guard` are normalized there and are not compared to the chart labels. | The chart uses shorthand and outcome text such as `reject; the branch and record go`, so its labels are not the table's normalized event or guard. The table is the only statement of the subject, invariant, pre/postcondition, test and mutation. | `docs/reference/draft_branch_statechart.md` |
| Resolve the fork point once, in `_ingest_export_metadata`. | A ref such as `main` reached the hint unresolved and printed `Branch point: main`; resolving at ingest makes the branch name, record and hint carry one commit. | `scripts/workflows/draft.sh` |
| The scanner requires one id prefix per chart block and one block per prefix, and treats an unrecognized `-->` line as a finding. | A silently skipped alternate arrow is invisible to the gate; a prefix split across charts would make the ambiguity grouping cross charts. | `scripts/lint/draft_statechart.mjs` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The earlier ambiguous pairs were labels and missing guards, not duplicate states. `s4 -> s5` and `s4 -> s8` are success and failure, `s1 -> s4` and `s1 -> s7` are switch success and failure, and `s0 -> s3` and `s0 -> s6` split on whether the base is still the branch point. | model defect | A guard fixes the nondeterminism; a merge would delete the outcome the chart exists to show. | This iteration: exclusive guards on the chart and the table. |
| `C24` was dead code under `set -e`: `parse_args` exited 2 before `main` could map help to exit 0. | product defect | `confirm.sh --help`, `draft.sh --help` and `reject.sh --help` exited 2. | This iteration: capture the parse result and add the help test. |
| A sourced test cannot kill a line that depends on errexit, because `run_test` disables it. | test-harness defect | `C20`, `C21`, `C15` and `C07` survived the first source-level attempts. | This iteration: process-level git shim. |
| Round 4 found the strict gate had no entry point and the transition table accepted unrelated mutation subjects. | gate-honesty defect | The general runner now owns the required-subset verdict, and the statechart checks the subject and id-less edges. | This iteration: `scripts/mutations_run.sh`, `scripts/run_tests.sh`, `scripts/lint/draft_statechart.mjs`. |
| Round 6 found that the R5-2 guard consolidation had invalidated mutation rows 128, 129 and 262. | gate-honesty defect | The required subset would fail on arrival with three stale rows. | This iteration: repointed the three rows and added the required-stale runner test. |
| The branch point printed twice, once from `draft_run` and once from the hint; a ref base printed `Branch point: main`. | output defect | Two formats for one value left the operator reading the ref instead of the commit. | This iteration: resolve once at ingest and print only the hint line. |
| The scanner silently skipped Mermaid edges it did not recognize and grouped ambiguity by the one-letter id prefix. | gate-honesty defect | An alternate arrow form escaped the gate, and a prefix split across charts could suppress or merge a finding. | This iteration: reject non-canonical `-->` lines and require one prefix per block. |
| `draft_state.sh` and `guards.sh` had no subject-test map entry, so their helper bodies had no mutation coverage. | coverage defect | The mutation runner could not target the two modules. | This iteration: map entries and catalog rows 263-272. |
| The broad mutation corpus still carries findings outside the diff pipeline. | record drift | `MUTATION=1` runs all subjects; only the draft lifecycle subset is blocking. | Out of scope; those rows remain report-only. |

## Completed

| File | Change |
|---|---|
| `docs/reference/draft_branch_statechart.md` | Added transition ids, the `Subject` column, the package and confirm transition tables, exclusive guards, and the statement that the table is the contract. |
| `scripts/lint/draft_statechart.mjs` | Checks the edge-to-row mapping, subject match, test names, catalog ids, missing and empty labels, and same-event ambiguity; parses equal-separated value flags only; requires one id prefix per chart block and one block per prefix; rejects non-canonical `-->` lines. |
| `scripts/check_draft_statechart.sh` | New gate over the draft statechart with equal-separated `--doc=`, `--catalog=` and `--tests-dir=` seams. |
| `scripts/check_statechart.sh` | Uses the equal-separated `--doc=` seam and rejects the space-separated form. |
| `scripts/lint/statechart.mjs` | Parses `--doc=<path>` only and rejects unknown or empty value flags. |
| `scripts/lint.sh` | Added the draft statechart gate to the umbrella. |
| `scripts/run_tests.sh` | Runs the mutation tier as the entry point, requires the draft lifecycle subset, propagates its verdict, and clears `MUTATION` before the nested runner tests. |
| `scripts/mutations_run.sh` | Added required-subject strictness, control rows, the reject and package subject mappings, and the `scripts/guards.sh` and `src/libs/draft_state.sh` mappings. |
| `tests/mutations/catalog.jsonl` | Added control, reject/package, guard and draft-state rows; refreshed `C24` and the three rows R5-2 invalidated; rows 263-272 cover the helper bodies. |
| `tests/test_draft_statechart.sh` | New gate tests for clean, missing and empty labels, ghost row, missing test, missing mutation, subject, ambiguity, the space-separated refusal, non-canonical arrows, mixed prefixes and a split prefix. |
| `tests/test_statechart.sh` | Uses `--doc=<path>` and pins the space-separated refusal. |
| `tests/test_confirm_workflow.sh` | Added the process-level probes, the help test, the dirty-tree refusal and the missing-record ordering check. |
| `tests/test_draft_workflow.sh` | Added the branch-point, missing-patches, script-identity, dirty-tree, `--help` and one-resolved-branch-point tests. |
| `tests/test_reject_workflow.sh` | Added the `--help` entry test. |
| `tests/test_mutations_runner.sh` | Added strict-mode, control-row, required-first and required-stale tests. |
| `tests/test_lint_umbrella.sh` | Classified the new strict mutation gate as non-umbrella. |
| `scripts/workflows/confirm.sh` | Added the dirty-tree refusal, captured `parse_args` with `\|\| rc=$?`, and reads the validated source. |
| `scripts/workflows/draft.sh` | Captured `parse_args` with `\|\| rc=$?`, uses the shared dirty-tree refusal, records that the package `.branch-point` borrows `kv_read`, resolves the fork point once, and prints only the hint's branch-point line. |
| `src/libs/export_status.sh` | Records that the package `.branch-point` borrows `kv_read` until the roadmap KV pair lands. |
| `scripts/workflows/reject.sh` | Captured `parse_args` with `\|\| rc=$?` and reads the validated source. |
| `scripts/guards.sh` | Added `refuse_dirty_tree`, the single dirty-tree refusal. |
| `src/libs/draft_state.sh` | Returns the source branch as output and sets no globals. |
| `tests/test_guards.sh` | Pins the clean, dirty and unreadable refusals. |
| `tests/test_draft_state.sh` | Pins the source output and the empty-stdout failure path. |
| `devlog/roadmap.md` | Filed the cross-chart state-machine audit as an open T7 row. |
| `devlog/handovers/T7/20261108-04-impl-draft_lifecycle_transition_model.md` | This handover. |
