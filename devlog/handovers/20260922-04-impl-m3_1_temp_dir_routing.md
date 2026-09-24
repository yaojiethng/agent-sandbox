# Agent Handover

**Date:** 2026-09-22
**Milestone:** M3.1 - Backpressure
**Type:** Impl
**Status:** Open

## Objective

U3 of the unified test-harness improvement plan: route strays `mktemp -d` sites to the per-test allocator so every test-created directory is torn down with the test.

## Scope

- Route the 56 per-test `mktemp -d` calls in checkpoint, diff_export, provider_entrypoint, providers_pi_preflight, session_save_guard, and trace_compose_gen to `get_fixture_dir`; drop the now-dead `fail "mktemp failed"` guards.
- Route dispatch's file-scope `MOCK_SCRIPTS_DIR` mock tree to `FIXTURE_ROOT/mocks` (cleaned by the file EXIT trap).
- Update the stale `mktemp` wording in a trace_dry_run probe-hygiene comment.

## Acceptance criteria

Suite green; lint Clean; no `mktemp` (build) calls left in `tests/test_*.sh`.

## Hot files

| File | Why in scope |
|---|---|
| `tests/libs/test_common.sh` | `get_fixture_dir` (already landed, U1) is the routing target. |
| 6 per-test `mktemp` users + `test_dispatch.sh` | The routed sites. |

## Verification

710/710; lint Clean; greps confirm no stray `mktemp` remains.

## What's Next

U4 (benign-non-zero cleanup), U5-U7.
