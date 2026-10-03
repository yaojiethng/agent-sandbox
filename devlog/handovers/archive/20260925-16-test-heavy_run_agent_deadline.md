# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Give the run-agent suite its own per-file deadline so the 5s default cannot fail a healthy file under parallel dispatch.

## Scope

One test file's header: the `TEST_DEADLINE` declaration the runner reads. No production code, no other test file.

## Carried forward

| Item | From handover |
|---|---|
| The heavy-file deadline item deferred by handover 10 | `20260925-10-fix-dry_run_single_probe_channel` |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| The runner reads a ten-second budget for this file | the runner's first-ten-lines parse | Agent [x] (reads `10`) |
| Two consecutive suite runs are green | `bash scripts/run_tests.sh` | Agent [x] (806 units, 0 failed, both runs) |
| Lint clean | `bash scripts/lint.sh` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`tests/test_run_agent.sh`](../../tests/test_run_agent.sh) | 33 units, most spawning a real `run_agent.sh` invocation; its honest runtime sits on the default |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Declare a ten-second budget for this file rather than raise the default | the default is the right budget for the other 63 files; the two existing heavy peers already declare their own | the file's header |
| State the measured runtime in the rationale | the declaration is a budget, not a licence, so the next reader can see the margin it buys | the file's header |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The flake is pre-existing, not a regression from the git-primitive refactor: the file's standalone runtime is 3.4s and peaks at 6.7s, and the refactor's own verification runs were green. It grew when it absorbed the trace-start family in the rectification campaign. | bug | current iteration |
| The timeout hides the file's whole unit count: the aggregate read 774 units instead of 806, and only the per-file line named the file. This is the reporting defect handover 10 records. | bug | next iteration |

## Completed

| File | Change |
|---|---|
| `tests/test_run_agent.sh` | declares `# TEST_DEADLINE: 10` with its measured runtime as the rationale, in the first ten lines the runner parses |

## Deferred items

None. The unit-count-hiding defect is recorded in Findings and belongs to the failure-signalling row.

## What's Next

M3.1 - Backpressure remains active: the coverage campaign, the verdict vocabulary and the mutation-suite decision.

**Conclusions from this iteration:** a per-file deadline declaration is the established remedy for a heavy suite file, and the runner already parses it from the first ten lines; the remaining defect is that a timeout still hides the file's unit count in the aggregate.
