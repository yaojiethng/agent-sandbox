# Agent Handover

**Date:** 2026-09-18
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Land P3 of the env-precedence feature: centralize the identity-triple flag parsing in `parse_base_flags` (name + project + sandbox) in `src/libs/common.sh`, and route `stop.sh`, `prune.sh`, and `resume_agent.sh` through it so the future resolver change is localized.

## Scope

P3 of the env-precedence resolver plan (`devlog/roadmap.md:119`). Parse-side centralization only; behavior unchanged. The workflows (`confirm`/`reject`/`draft`/`apply`) parse only project+sandbox and do not source `common.sh`; `start_agent.sh` keeps its `SANDBOX_DIR_OVERRIDE` handling for the resolver wiring (S2). Both stay untouched here.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | `parse_base_flags` sets `PROJECT_DIR` from `--project=`; leaves it empty when absent | `bash tests/test_common_lib.sh` | Agent (19/19) |
| 2 | `stop.sh`, `prune.sh`, `resume_agent.sh` build cleanly and route identity through `parse_base_flags` | `bash -n`, shellcheck | Agent (rc=0) |
| 3 | Full suite stays green | `bash scripts/run_tests.sh` | Agent (831/831) |

## Hot files

| File | Why in scope |
|---|---|
| `src/libs/common.sh` | `parse_base_flags` extended to name + project + sandbox |
| `scripts/stop.sh`, `scripts/prune.sh`, `scripts/resume_agent.sh` | Identity parsing routed through `parse_base_flags`; script-specific loops keep only their own flags |
| `tests/test_common_lib.sh` | `PROJECT_DIR` assertions for `parse_base_flags` |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `PRIVATE_KEYS` are not validated by `check_base_flags`; validation of the full triple stays site-local | Callers with different identity needs must not all be forced to require `--project`; parse centralization (P3) is distinct from validation (S1 resolver) | this handover |
| `# shellcheck disable=SC2034` at library scope for the parsed identity vars | `PROJECT_DIR` etc. are consumed by the sourcing scripts, not inside the library - a known false-positive class, suppressed with rationale per the check_lint policy | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| ShellCheck flags `PROJECT_DIR` in `common.sh` as unused (SC2034) - it is set for callers, not read in-file | contradiction -> handled | none |

## Completed

| File | Change |
|---|---|
| `src/libs/common.sh` | `parse_base_flags` parses `--name=`, `--project=`, `--sandbox=` (identity triple); SC2034 suppression for caller-consumed vars |
| `scripts/stop.sh` | Drops its own `--project=` case; the identity cases are a no-op consumed by `parse_base_flags` |
| `scripts/prune.sh` | Removes the redundant second `--project=` parse loop |
| `scripts/resume_agent.sh` | Routes identity through `parse_base_flags`; removes the three inline identity cases |
| `tests/test_common_lib.sh` | `PROJECT_DIR` assertions (set + default-empty) |

## Deferred items

None.

## What's Next

M2.6 - Session Persistence. Next in the feature plan: **S1** (new `src/libs/env_resolve.sh` precedence resolver + unit tests), then **S2** (wire entrypoints) / **S3** (thin CLI) / **S4** (docs + ADR).

**Conclusions from this iteration:** identity-triple flag parsing is now centralized in `parse_base_flags`; the three `common.sh`-sourcing consumer scripts route through it. The 7/11/12 per-file parse duplication is reduced for the identity-flag set.