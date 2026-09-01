# Agent Handover

**Date:** 2026-06-09
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Implementation
**Status:** Closed

## Objective

Implement M2.7 Track A item 8 — Artefact path updates to use RUN_ID.

## Scope

1. Pass `RUN_ID` to sandbox container (docker-compose.yml), write to SESSION_STATE (snapshot.sh)
2. Update `session_export_path()` in routing.sh to accept optional `RUN_ID` suffix
3. Update `output_export_path()` in routing.sh to use `RUN_ID` instead of `SESSION_TS`
4. Update entrypoint.sh to pass `RUN_ID` to session export paths
5. Update package_diff.sh and package_branch.sh to read `RUN_ID` from SESSION_STATE
6. Update draft branch naming to use RUN_ID (fall back to SESSION_TS if unavailable)
7. Update draft_parse_folder_name() to extract RUN_ID from folder names
8. Update draft_write_state() to include run_id
9. Update prompt templates and quickstart docs

## Completed this session

| File | Change |
|---|---|
| `src/build/docker-compose.yml` | Added `RUN_ID=${RUN_ID:-}` to sandbox environment |
| `src/capability/snapshot.sh` | Write `run_id` to SESSION_STATE |
| `src/libs/routing.sh` | `session_export_path()` accepts optional `RUN_ID`; `output_export_path()` uses `RUN_ID` instead of `SESSION_TS`; doc comments updated |
| `src/capability/entrypoint.sh` | Pass `RUN_ID` to session export paths |
| `src/libs/package_diff.sh` | Read `run_id` from SESSION_STATE instead of `session_ts` |
| `src/libs/package_branch.sh` | Read `run_id` from SESSION_STATE instead of `session_ts` |
| `src/libs/draft_state.sh` | `draft_parse_folder_name()` extracts `RUN_ID`; `draft_write_state()` includes `run_id` field |
| `scripts/workflows/draft.sh` | Draft branch uses `RUN_ID` (fallback to `SESSION_TS`); `RUN_ID` plumbed through to write_state |
| Prompt templates | Updated path format references |
| Quickstart docs | Updated example paths |
