# Agent Handover

**Date:** 2026-09-22
**Milestone:** M3.1 - Backpressure
**Type:** Impl
**Status:** Open

## Objective

U4 of the unified test-harness improvement plan: resolve the benign-non-zero masks (`|| true`) so the suite does not rely on them incorrectly.

## Scope

- Audit the 96 `|| true` masks in `tests/test_*.sh`.
- Document the benign-non-zero rc convention in testing-conventions.
- Fix the stale `run_test`-`$1 || true` comments in test_routing.

## Decision recorded

An initial broad removal of every mask broke `test_confirm_workflow` and revealed the masks are load-bearing, not redundant. A test subshell exits with the test function's return status, and the strict rule -- a non-zero exit from the test subshell is a failed test -- means the last command of a test function is its verdict. A trailing cleanup or `git diff` rc-1-signal command must be masked or it flips an otherwise-passing test to a failure. The `git diff` (rc 1 = differences found) and `grep -c`/`grep`-chain (rc 1 = no match) masks carry a benign signal. The audit found no mask hid a would-be-asserted failure, so U4 is a documentation task: make the tolerance explicit so a future pass does not mis-clean it.

## Acceptance criteria

Suite green; lint Clean; the convention documented; stale comments corrected.

## Hot files

| File | Why in scope |
|---|---|
| `docs/development/testing-conventions.md` | The benign-non-zero rc convention. |
| `tests/test_routing.sh` | Corrected stale `run_test`-mechanics comments. |

## What's Next

U5 (assert-the-meaning labels), U6-U7.
