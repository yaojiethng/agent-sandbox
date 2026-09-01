# Agent Handover

**Date:** 2026-05-30
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Impl
**Status:** Closed

## Objective

Streamline the dispatch layer (Phase 2 of the design). Reduce `parse_flags` to 3 universal flags. Remove `rebuild_flags()` and `require_provider_args()` from the dispatch level. All subcommand-specific flags pass through via `PASSTHROUGH` — no parse-and-re-serialize.

## Completed this session

| File | Change summary |
|---|---|
| `scripts/agent-sandbox.sh` | `parse_flags` reduced to 3 universal flags. Removed `require_provider_args()`, `rebuild_flags()`. Removed 14 unused local variable declarations. All dispatch cases now use `"${PASSTHROUGH[@]}"` pattern. `build` is the only case with flag transformation (legacy `--target` → `--targets`). |
| `tests/test_start_agent.sh` | Updated `test_agent_sandbox_has_rebuild_flags_function` to assert absence instead of presence. |

## Next session

Phase 3 — Cleanup: update dispatch tests, verify full suite.
