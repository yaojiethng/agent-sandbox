# Agent Handover

**Date:** 2026-09-22
**Milestone:** M3.1 - Backpressure
**Type:** Impl
**Status:** Open

## Objective

U6 of the unified test-harness improvement plan: the order-independence verification probe (reversed-run gate) proving per-test isolation.

## Scope

- `tests/libs/test_common.sh`: `REVERSE_RUN=1` defers `run_test` registrations into a queue; `test_done` flushes them in reverse registration order. Normal runs are unchanged.
- Convert the 13 test files with inline footers (or none) to the `test_done` template, which the conventions doc already marks as retired; `test_done` now also hosts the reversed flush.
- Add `scripts/check_test_order.sh`: per file, compare registration-order and reversed unit tallies; exit non-zero on any mismatch.
- Document the gate in testing-conventions.

## Verification

58/58 test files green under the gate; full suite 710/710; lint Clean; gate script passes the ShellCheck gate.

## Hot files

| File | Why in scope |
|---|---|
| `tests/libs/test_common.sh` | `REVERSE_RUN` deferred-reverse flush. |
| `scripts/check_test_order.sh` | The reversed-run gate. |
| 13 test files | Inline footers converted to `test_done`. |

## What's Next

U7 (final full per-assertion fresh-subagent sweep).
