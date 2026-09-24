# Agent Handover

**Date:** 2026-09-22
**Milestone:** M3.1 - Backpressure
**Type:** Impl
**Status:** Open

## Objective

U2 of the unified test-harness improvement plan: a capture-and-assert helper and the migration of the rc-only, output-discarding assertion sites to it.

## Scope

- `tests/libs/test_common.sh`: rename `assert_subshell_rc` -> `assert_run`; capture combined output into `RUN_OUT` (never discard); name output on a mismatch so a failure is not blind.
- `tests/test_git_hook.sh` and `tests/test_common_lib.sh`: migrate call sites and the self-test to `assert_run`; update the self-test's marker expectation.
- `docs/development/testing-conventions.md`: document the capture-and-assert pattern.

## Acceptance criteria

Suite green; lint Clean; `assert_run` used by >1 file (not dead code).

## Hot files

| File | Why in scope |
|---|---|
| `tests/libs/test_common.sh` | The capture-and-assert helper. |
| `tests/test_git_hook.sh`, `tests/test_common_lib.sh` | Migrated call sites. |
| `docs/development/testing-conventions.md` | Pattern documentation. |

## What's Next

U3 (temp-dir routing), U4-U7.
