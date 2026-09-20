# Agent Handover

**Date:** 2026-09-18
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Land P1 of the env-precedence feature: move `PROJECT_NAME` into the per-sandbox `.env`, drop the sed `<project-name>` injection and the baked template literal, bump the Makefile template to version 5, and add a refresh migration path plus tests for existing sandboxes whose `.env` lacks `PROJECT_NAME`.

## Scope

P1 of the env-precedence resolver plan (`devlog/roadmap.md:119`, from study `20260917-06`). `PROJECT_NAME` becomes a `.env` key so the future resolver has a single `.env` store; identity is no longer duplicated as a template literal.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | Fresh onboard writes `PROJECT_NAME=<name>` to `.env` | `bash tests/test_onboard.sh` | Agent (PASS) |
| 2 | Generated Makefile reads `PROJECT_NAME` from `.env`; no `<project-name>` or concrete-name literal is baked | `bash tests/test_onboard.sh` | Agent (PASS) |
| 3 | Refresh inserts `PROJECT_NAME` into a pre-P1 `.env` that lacks it | `bash tests/test_onboard.sh` | Agent (PASS) |
| 4 | Full suite stays green; `bash -n` and shellcheck clean on changed files | `bash scripts/run_tests.sh` | Agent (825/825, rc=0) |

## Hot files

| File | Why in scope |
|---|---|
| `scripts/templates/Makefile.template` | Version 4 to 5; `PROJECT_NAME := <project-name>` replaced with `?=` from `.env` |
| `scripts/onboard.sh` | Drop sed injection (both modes); `_write_env_file` gains `PROJECT_NAME`; refresh gains the name insert/migrate path |
| `tests/test_onboard.sh` | Assert `.env` PROJECT_NAME, no baked literal, and the refresh migration |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `MAKEFILE_VERSION` is write-only metadata in `.env`; the template bump has no staleness gate that compares the number | Grep confirmed no consumer reads `MAKEFILE_VERSION`; refresh merely records the current template version | this handover |
| Refresh inserts the missing `PROJECT_NAME` line after `SANDBOX_DIR` in `.env` | `_validate_refresh` requires `--name`, so the value is always available during refresh; append keeps old-format schema intact | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| `MAKEFILE_VERSION` is recorded by onboard but never read by any code - it is informational, not a staleness gate | contradiction | next iteration (idle) |

## Completed

| File | Change |
|---|---|
| `scripts/templates/Makefile.template` | Version 4 to 5; `PROJECT_NAME` read from `.env` via `?=` error-guard instead of the baked `<project-name>` literal |
| `scripts/onboard.sh` | Fresh/refresh write the Makefile by `cp` (injection dropped); `_write_env_file` emits `PROJECT_NAME`; refresh inserts/updates the name line in existing `.env` |
| `tests/test_onboard.sh` | `.env` PROJECT_NAME assertion; no-baked-literal test; pre-P1 `.env` refresh migration test |

## Deferred items

None.

## What's Next

M2.6 - Session Persistence. Next in the feature plan: **P2** (unify `.env` loading into a new `src/libs/env.sh`) then **P3** (centralize base flag parsing in `common.sh`), then the feature **S1-S4**.

**Conclusions from this iteration:** `PROJECT_NAME` now lives in `.env`; the sed injection and baked literal are gone; refresh migrates old sandboxes. `MAKEFILE_VERSION` has no read-side staleness consumer.
