# Agent Handover

**Date:** 2026-09-18
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Add the P4 behavioral-baseline tests for the sandbox identity triple env precedence: regression tests pinning that today a per-sandbox `.env` value overrides an explicit `--name`/`--project` argument in `session_env_common_init` (file beats flag). Test-only; no production code changes.

## Scope

P4 of the env-precedence resolver plan (roadmap task at `devlog/roadmap.md:119`, generated from study `20260917-06`). Add to `tests/test_session_env.sh` the missing regression coverage for the flag-vs-`.env` precedence. Do not duplicate the 14 existing tests.

- Regression: `.env` `PROJECT_NAME` overrides the explicit name argument.
- Regression: `.env` `PROJECT_DIR` overrides the explicit project-dir argument.
- Split behavior: git validation reads the explicit directory argument while the export reflects the `.env` value.

## Carried forward

None. The env-precedence feature is a named roadmap task; P1 (move `PROJECT_NAME` into `.env`, `_run_refresh` insert, migration test, template bump 4 to 5) is the next iteration after this one closes.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | `test_env_project_name_overrides_explicit_arg` passes: exported `PROJECT_NAME` equals the `.env` value, not the explicit name arg | `bash tests/test_session_env.sh` | Agent (PASS, 17/17) |
| 2 | `test_env_project_dir_overrides_explicit_arg` passes: exported `PROJECT_DIR` equals the `.env` value, not the explicit dir arg | `bash tests/test_session_env.sh` | Agent (PASS, 17/17) |
| 3 | `test_env_identity_overrides_explicit_args` passes: call succeeds on a valid explicit repo arg while exporting conflicting `.env` name+dir | `bash tests/test_session_env.sh` | Agent (PASS, 17/17) |
| 4 | Full suite stays green with the added tests; `bash -n` and lint clean on the changed test file | `make test`, `bash -n` | Agent (suite 823/823, bash -n OK, shellcheck on file rc=0) |

## Hot files

| File | Why in scope |
|---|---|
| [`tests/test_session_env.sh`](tests/test_session_env.sh) | Home of `session_env_common_init` and `.env`-parser tests; the three new regressions land here |
| [`src/libs/session_env.sh`](src/libs/session_env.sh) | The function under test - read-only reference for the precedence behavior |
| [`tests/libs/test_common.sh`](tests/libs/test_common.sh) | Test framework: fixtures, `set -e` subshell print pattern, assertions |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The shadowing pair to pin is `PROJECT_NAME`/`PROJECT_DIR` at the function level | `session_env_common_init` exports these two from the explicit args (lines 21-22) then the `.env` loop can overwrite them; `dirs_resolve` does not set `SANDBOX_DIR`, so that override belongs to `start_agent.sh` scope, not this function | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| This container was initially a base checkout missing the `05` fix, `06` study, and the roadmap task; the operator ported them (HEAD now `2bfcf1a`). Resolved: all three now present | contradiction -> resolved | none |
| Recorded rename: this file is materialized as `20260918-02-impl-env_precedence_baseline.md`. First drafted under the non-standard `test-` shortform (Test is not a listed handover type), then re-dated from `20260917-07` to `20260918-02` when the running date rolled to Sep 18 (index 02 after the existing `20260918-01` rebase handover). Delivered as a `test:` commit per git policy | doc | none |

## Completed

| File | Change |
|---|---|
| `tests/test_session_env.sh` | Added 3 precedence-pin regressions: `.env` PROJECT_NAME overrides the explicit name arg; `.env` PROJECT_DIR overrides the explicit dir arg; `.env` identity (name+dir) overrides both. 14 to 17 tests, suite 823/823 |
| `devlog/handovers/20260918-02-impl-env_precedence_baseline.md` | P4 baseline iteration record; re-dated from 20260917-07 |

## Deferred items

None.

## What's Next

M2.6 - Session Persistence

The env-precedence feature is a named roadmap task; P4 baseline is the entry point. P1 (move `PROJECT_NAME` into `.env`, `_run_refresh` insertion, migration test, template bump 4 to 5) is the next iteration after this one closes. The baseline deliberately pins today's file-beats-flag behavior; P1 mutates the `.env` schema and S2 flips to flag-wins in later iterations.

**Conclusions from this iteration:** pending the scope gate. The function-level precedence source is confirmed: `session_env_common_init` exports `PROJECT_NAME`/`PROJECT_DIR` from args, then the `.env` loop overwrites them; `dirs_resolve` does not set `SANDBOX_DIR`.
