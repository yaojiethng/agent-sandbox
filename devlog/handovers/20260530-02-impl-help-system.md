# Agent Handover

**Date:** 2026-05-30
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Impl
**Status:** Closed

## Objective

Implement the help system and consistent error handling (Phase 1 of the dispatch cleanup design). Add `usage()` to every subcommand script, add `--help`/`-h` handling to all entry points, and wire up `agent-sandbox help <subcommand>`.

## Completed this session

| File | Change summary |
|---|---|
| `scripts/stop.sh` | Added `usage()` with help text. Added `--help`/`-h` detection. |
| `scripts/workflows/apply.sh` | Added `usage()` with help text. Added `--help` handling in `main()`. Error cases now call `usage()`. |
| `scripts/workflows/draft.sh` | Added `usage()` with help text. Added `--help` handling in `main()`. Error cases now call `usage()`. |
| `scripts/workflows/confirm.sh` | Added `usage()` with help text. Added `--help` handling in `main()`. Error cases now call `usage()`. |
| `scripts/workflows/reject.sh` | Added `usage()` with help text. Added `--help` handling in `main()`. Error cases now call `usage()`. |
| `scripts/build.sh` | Added `usage()` with help text. Added `--help` handling in `main()`. Error cases now call `usage()`. |
| `src/libs/package_diff.sh` | Added `usage()` with help text. Added `--help` handling in direct execution path. |
| `src/libs/package_branch.sh` | Added `usage()` with help text. Replaced inline `--help` grep with `usage()`. Error cases now call `usage()`. |
| `scripts/agent-sandbox.sh` | Added `help)` case dispatching to subcommand scripts via `--help`. |

## Next session

Phase 2 — Streamline dispatch: reduce `parse_flags` to 3 universal flags, remove `rebuild_flags()` and `require_provider_args()` from dispatch level, use `PASSTHROUGH` pattern.
