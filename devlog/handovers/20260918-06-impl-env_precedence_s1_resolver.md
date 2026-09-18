# Agent Handover

**Date:** 2026-09-18
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Land S1 of the env-precedence feature: add `src/libs/env_resolve.sh`, the centralized precedence resolver for the sandbox identity triple, with unit tests. This is a library only; it is NOT wired into any entrypoint, so current runtime behavior (and the P4 file-beats-flag pins) are unchanged.

## Scope

S1 of the env-precedence resolver plan (`devlog/roadmap.md:119`). The resolver implements the intended precedence (explicit flag > `AGENT_SANDBOX_*` env var > per-sandbox `.env` > hard error) and `.env` location selection (provided sandbox dir else invocation CWD). Wire-in is S2, later.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | Precedence: explicit > env var > `.env` > hard error, per identifier | `bash tests/test_env_resolve.sh` | Agent (7/7) |
| 2 | `.env` located in provided sandbox dir else invocation CWD | `bash tests/test_env_resolve.sh` | Agent (7/7) |
| 3 | Only `AGENT_SANDBOX_*` keys are the env level; a leaked plain export does not beat `.env` | `bash tests/test_env_resolve.sh` | Agent (7/7) |
| 4 | No value at any level is a hard error with onboard guidance (no runtime default) | `bash tests/test_env_resolve.sh` | Agent (7/7) |
| 5 | Full suite stays green; shellcheck clean | `bash scripts/run_tests.sh`, `shellcheck` | Agent (838/838, rc=0) |

## Hot files

| File | Why in scope |
|---|---|
| `src/libs/env_resolve.sh` | New resolver library |
| `tests/test_env_resolve.sh` | Resolver precedence/location/leak-guard unit tests |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `env_resolve_identity` takes empty-as-not-given explicit values and derives the `.env` path itself when one is not supplied | S2 entrypoints pass their parsed flag values as the explicit level and let the resolver pick the `.env`; one call resolves the whole triple | this handover |
| The env level reads only `AGENT_SANDBOX_*` keys | Guards against a sourced script's plain `PROJECT_*` export silently beating `.env` (study review correction 5) | this handover |

## Findings

None.

## Completed

| File | Change |
|---|---|
| `src/libs/env_resolve.sh` | New resolver: `env_resolve_identity`, `_resolve_one`, `_env_value`, `default_env_file` |
| `tests/test_env_resolve.sh` | 7 unit tests over precedence, `.env` location, and the leak guard |

## Deferred items

- **S2 (wire entrypoints)** - deferred. Flips the runtime precedence to flag-wins (behavior change) and needs docker runtime validation unavailable in this container; also contains the `package-branch` `--sandbox` forward fix and sandbox-only resolution for resume `--list`/`--interactive`. Validation + behavior-change sign-off required.

## What's Next

M2.6 - Session Persistence. **S2** (wire the resolver into start/resume, then build/stop/prune, then workflows; fix-or-exclude the `package-branch` forward; sandbox-only resolution for resume `--list`), **S3** (thin CLI + sandbox Makefile - public API change removing per-call identity flags), **S4** (docs + ADR recording the precedence model and the `make -C` CWD contract). S2/S3/S4 need operator input (docker validation, API-surface sign-off) before landing.

**Conclusions from this iteration:** the resolver implements flag-wins (the intended Direction B precedence); S1 is deliberately unwired so the P4 file-beats-flag pins still hold and the flip is a later, explicit S2 step.