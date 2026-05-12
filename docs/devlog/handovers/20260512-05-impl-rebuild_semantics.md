# Agent Handover

**Session date:** 2026-05-12
**Milestone:** M2 — Reasoning/Capability Layer Separation
**Session type:** Implementation
**Status:** Closed

## Objective

Clarify the REBUILD flag semantics — resolve the mismatch between documentation (which promised "full rebuild from scratch") and implementation (which skipped the base image), and align flag names with actual behaviour.

## Scope

- Rename `--rebuild` to `--refresh` (rebuild sandbox + provider, base skipped if exists).
- Rename `--rebuild-base` to `--rebuild` (rebuild everything including base, supersedes `--refresh`).
- `--rebuild-base` flag retired.
- `build_agent` takes `--no-cache-base` for forcing base rebuild — no interpretation burden on the function.
- Update Makefile.template variables, tool_interface.md docs, and tests.

## Completed this session

- `scripts/agent-sandbox.sh`: Parses `--refresh`/`--rebuild`; `rebuild_flags()` emits `--refresh` or `--rebuild` (rebuild wins); build dispatch passes `--no-cache-base` to `build_agent`.
- `scripts/start_agent.sh`: Parses `--refresh`/`--rebuild`; separate rebuild paths — `--rebuild` calls `build_agent --no-cache-base`, `--refresh` calls `build_agent` with no extra flag.
- `libs/containers.sh`: Renamed `build_agent`'s `rebuild_base` param to `no_cache_base`.
- `libs/_templates/Makefile.template`: Old `REBUILD`/`REBUILD_BASE` → `REFRESH`/`REBUILD`.
- `docs/architecture/tool_interface.md`: Corrected docs to describe `REFRESH=1` and `REBUILD=1` accurately.
- `tests/test_start_agent.sh`: Added `test_refresh_flags_parsed_by_start_agent`, `test_rebuild_base_flag_removed`; updated block position test.
