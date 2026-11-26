---
date: 2026-11-22
milestone: M3.4.2 - The resolution model and record primitives
type: Implementation
status: Closed
---

# Handover - the suite's verdict is its last line, and an unreachable test is a finding

## Objective

A run whose gate failed cannot be read as green by anyone who looks at the end of its output, and a test function that can never execute is caught by the gate rather than by a review.

## Scope

The harness around the suite, opened by the review round: how `scripts/run_tests.sh` prints its verdict, and what `scripts/check_test_liveness.sh` treats as a defect. It writes no test and changes no subject under test.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A failed gate is visible in the last line | `bash tests/test_runner_contract.sh` case `test_gate_failure_is_the_last_line` | Agent [x] |
| A clean run ends on a pass verdict | the same file, case `test_clean_run_ends_on_the_pass_verdict` | Agent [x] |
| The count line names a failed gate | the same case asserts `GATE FAILED` on the count line | Agent [x] |
| A definition below `test_done` is a gate finding | `bash tests/test_runner_selftest.sh` case `test_runner_definition_after_epilogue_is_flagged` | Agent [x] |
| The suite and the gates pass | `bash scripts/run_tests.sh` (1684 tests), `bash scripts/lint.sh` (29 gates) | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The verdict is the last line of the run. | The gate's error printed *above* a green count, so a two-line tail read as a pass: that is how `2622d82d` landed with a liveness finding while its handover claimed 29 clean gates. | This table; `scripts/run_tests.sh` |
| A gate failure is named on the count line, separately from a test failure. | The counts stay true to the tests, and the gate's state still appears on the line a reader skims. | This table |
| Discovery was tried and reverted; the gate keeps registration as membership. | `test_done` was changed to run every defined `test_*()` so a misplaced registration could not hide a test. It broke a real pattern: `tests/test_dispatch.sh` guards six slow worker-fallback cases behind `WORKER_FALLBACK_CASES=1`, and "defined" is not "intended to run" -- the file went from 28s to over 120s. A conditional registration is a deliberate exclusion, so membership stays a statement the file makes on purpose. | This table |
| The unreachable case is a line-number check, not a membership one. | A test defined below `test_done` cannot run whatever its registration says, because the shell had not defined it when the epilogue ran. That is checkable without deciding which registered tests were meant to run. | This table; `scripts/check_test_liveness.sh` |

## Findings

| # | Finding | Triaged to |
|---|---|---|
| F1 | The runner's green count followed a failing gate's error, so the end of the output contradicted the run's state. | Applied here: the verdict line, and the gate named on the count line |
| F2 | A test function defined below `test_done` is unreachable and no check named it. | Applied here: `DEFINED-AFTER-EPILOGUE`, with a fixture |
| F3 | The discovery design I proposed is unsound, because a conditional `run_test` is an exclusion rather than an oversight. | Applied as a decision; the reverted change is recorded so the next reader does not re-derive it |

## Decisions pending

- Whether the liveness gate's registration scan should ignore `run_test` text inside heredoc fixtures. Today a fixture that writes the word counts as a registration, so a real dead registration could hide behind it. Reversing word: "make the scan heredoc-aware".

## Records

| File | Change |
|---|---|
| [`scripts/run_tests.sh`](../../scripts/run_tests.sh) | `GATE_FAILED` tracks a gate's own failure, the count line names it, and the run ends on `SUITE PASSED` or `SUITE FAILED`. |
| [`scripts/check_test_liveness.sh`](../../scripts/check_test_liveness.sh) | `DEFINED-AFTER-EPILOGUE` reports a test function the epilogue cannot reach. |
| [`tests/test_runner_contract.sh`](../../tests/test_runner_contract.sh) | Two cases: the gate failure is the tail, and a clean run ends on the pass verdict. |
| [`tests/test_runner_selftest.sh`](../../tests/test_runner_selftest.sh) | One case: a definition below the epilogue is a finding. |

## Completed

| File | Change |
|---|---|
| The verdict | A tail of the runner's output reports the run's state, whatever the counts say. |
| The gates | 29 clean; 1684 tests passing. |
