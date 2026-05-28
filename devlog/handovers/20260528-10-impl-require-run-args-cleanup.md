# Agent Handover

**Session date:** 2026-05-28
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Impl
**Status:** Active

## Objective

Resolve the `require_run_args` naming inconsistency. Split the function into two smaller validators (`require_base_args`, `require_provider_args`) so `build` can reuse the base check without triggering a spurious `--provider` error. All subcommands use the same validation pattern.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | `require_run_args` no longer exists | `grep -c "^require_run_args" scripts/agent-sandbox.sh` = 0 | Agent |
| 2 | `require_base_args` defined and used by build, start, serve, dry-run | `grep -c "require_base_args" scripts/agent-sandbox.sh` ≥ 4 | Agent |
| 3 | `require_provider_args` used by start, serve, dry-run | `grep -c "require_provider_args" scripts/agent-sandbox.sh` ≥ 3 | Agent |
| 4 | Syntax checks pass | `bash -n scripts/agent-sandbox.sh` — OK | Agent |
| 5 | Full suite passes | `bash scripts/run_tests.sh` — 0 failed | Agent ✅ |

## Completed this session

| File | Change summary |
|---|---|
| `scripts/agent-sandbox.sh` | Split `require_run_args()` into `require_base_args()` and `require_provider_args()`. `build` now uses `require_base_args` instead of inline validation. `start`/`serve`/`dry-run` call both. |

**Status:** Closed
