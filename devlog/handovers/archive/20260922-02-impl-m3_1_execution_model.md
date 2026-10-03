# Agent Handover

**Date:** 2026-09-22
**Milestone:** M3.1 - Backpressure
**Type:** Impl
**Status:** Closed

## Objective

U1 of the unified test-harness improvement plan: replace the in-process, shared-shell execution model with per-test isolation. Each test runs in its own subshell; assertions fail fast; accounting counts one unit per test; fixtures come from an untyped per-test allocator; teardown is unified behind the allocator. `FIXTURE_DIR` becomes the per-test default root; a file-scope `FIXTURE_ROOT` carries shared scaffolds.

## Scope

- `tests/libs/test_common.sh`: subshell-per-test `run_test`, fail-fast assertions, per-test-unit accounting, `get_fixture_dir`/`get_test_dir` allocator, `FIXTURE_DIR` per-test compat, `FIXTURE_ROOT` file-scope scaffold, unified teardown.
- Migrate the shared-scaffold test files that consume file-scope `$FIXTURE_DIR` paths from inside tests.
- Fix cross-test dependencies (smells) surfaced by isolation.

## Carried forward

| Item | From handover |
|---|---|
| Two-branch re-port + harness decision (deferred). | 20260921-13/14, 20260922-01 |
| U2-U7 (capture-and-assert; temp-dir routing; benign-non-zero; assert labels; order probe; final sweep). | 20260922-01 plan, design doc |

## Acceptance criteria

Suite green at 1042 units-equivalent isolation baseline; lint Clean; order-independence probe (U6) later proves no cross-test coupling. Runner, selftest, and docs updated for the per-test-unit accounting contract.

## Hot files

| File | Why in scope |
|---|---|
| `tests/libs/test_common.sh` | New execution model (subshell, allocator, accounting). |
| `scripts/run_tests.sh` | Unit-marker accounting contract. |
| `tests/test_runner_selftest.sh` | Rebuilt for the per-test-unit contract. |
| `tests/test_macos_bootstrap.sh`, `tests/test_install.sh`, `tests/test_guards.sh`, `tests/test_session_log.sh`, `tests/test_diff_workflow.sh` | File-scope shared scaffolds under per-test `FIXTURE_DIR`; cross-test `test.diff`. |
| `docs/development/testing-conventions.md` | Per-test fixture and accounting conventions. |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Shared command shims built at file scope into `$FIXTURE_DIR` are consumed from inside tests (macos_bootstrap, install, guards, session_log, diff_workflow). Migrated to a file-scope `FIXTURE_ROOT` that tests reach by name, because the per-test subshell shadows `FIXTURE_DIR`. | execution-model consequence | current iteration |
| The per-test allocator cannot register via an array: `get_fixture_dir` is called inside command substitution, whose array writes go to a lost sub-subshell. It journals to a file instead. | implementation bug (fixed) | current iteration |
| An EXIT trap's final command overrides the shell's exit status. The per-test trap must capture `$?` and re-exit with it, or a `fail()` exit 1 flips the unit to PASS. | implementation bug (fixed) | current iteration |
| `set -e` inherited from a sourced script (start_agent.sh runs `set -euo pipefail`) aborts `out=$(cmd)` captures. The test subshell runs `set +e`: fail-fast is `fail()`'s controlled exit, not errexit. | implementation bug (fixed) | current iteration |
| Accounting moved to per-test units (710 units) from per-assertion markers; the unit count now matches the bats branch's 696-test-function census. | contract change | current iteration |
| A catch-all mask (23 assertions using the `cmd or true` idiom) was left intact for U4; cross-test-written fixtures (`test.diff`) were the first smell fixed. | scope change | U2/U4 pending |

## What's Next

U2-U7 from the design doc. Suite at 710/710, lint Clean.
