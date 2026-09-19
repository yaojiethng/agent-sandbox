# Agent Handover

**Date:** 2026-09-18
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Land S2 + S4 of the env-precedence feature: wire the resolver into the entrypoints and flip the runtime precedence to flag-wins (explicit flag > `AGENT_SANDBOX_*` env var > per-sandbox `.env` > hard error), fix the `package-branch` `--sandbox` forward, make `resume --list`/`--interactive` need only `--sandbox`, and record the precedence model and the `make -C` CWD contract in an ADR plus docs.

## Scope

S2 (wire + flip) and S4 (ADR + docs) of the env-precedence plan (`devlog/roadmap.md:119`). S3 (thin CLI / remove per-call identity flags) is deferred. Docker runtime validation is not available in this container; S2 is verified offline (unit tests, `bash -n`, shellcheck, full suite) and the runtime `make start`/`make resume` confirmation is left to the operator.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | `session_env_common_init` resolves flag-wins: explicit name/dir beat `.env` and `AGENT_SANDBOX_*`; empty args resolve from `.env` | `bash tests/test_session_env.sh` | accepted (19/19; P4 pins flipped to flag-wins) |
| 2 | `package-branch` forwards `--sandbox` to `package_branch.sh` | `bash tests/test_dispatch.sh` | accepted |
| 3 | `resume` requires only `--sandbox`; name/project resolve from `.env` in the sandbox dir | `bash tests/test_resume.sh` | accepted (16/16) |
| 4 | Full suite stays green; `bash -n` and shellcheck clean on changed files | `run_tests.sh`, `bash -n`, shellcheck | accepted (840/840, rc=0) |
| 5 | S4: precedence ADR created and identity docs updated (precedence + `make -C` contract) | `ls docs/adr/env_precedence.md` | accepted |

## Hot files

| File | Why in scope |
|---|---|
| `src/libs/session_env.sh` | Wire `env_resolve_identity`; identity args win over `.env` (flag-wins). The P4 pins flip here |
| `scripts/start_agent.sh`, `scripts/resume_agent.sh` | Entrypoints that call `session_env_common_init`; resume `--list`/`--interactive` need only `--sandbox` |
| `scripts/agent-sandbox.sh`, `src/libs/package_branch.sh` | Fix the `package-branch --sandbox` forward |
| `tests/test_session_env.sh`, `tests/test_resume.sh`, `tests/test_dispatch.sh` | Tests for the flip, resume partial resolution, and the forward fix |
| `docs/adr/`, `docs/` | S4: precedence ADR + docs updates |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Precedence flip is implemented in `session_env_common_init`, which now resolves via `env_resolve_identity` and re-asserts the identity after `.env` | `common_init` is the single chokepoint both start and resume use, so the flip and the resolver wire-in land in one place | this handover |
| `resume` needs only `--sandbox`; name/project resolve from `.env` | Review correction 8: `--list`/`--interactive` are sandbox-only; identity is recoverable from `.env` in the sandbox dir | this handover |
| The P4 precedence pins were flipped (explicit beats `.env`) | P4 deliberately pinned the pre-flip file-beats-flag baseline; S2 is the designed flip | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The P4 precedence pins now assert flag-wins, not the pre-P4 file-beats-flag baseline - this is the designed S2 flip, not a regression | steering | next iteration (idle) |
| Docker runtime validation (`make start`/`make resume`) is not available in this container; the precedence flip is unit-tested but must be runtime-confirmed by the operator before the branch is trusted for real sessions | blocker -> risk | operator |

## Completed

| File | Change |
|---|---|
| `src/libs/session_env.sh` | `common_init` resolves identity via `env_resolve_identity` (flag-wins), re-asserts identity after `.env`; empty name/dir args allowed (resolve from `.env`/env) |
| `scripts/agent-sandbox.sh` | `package-branch` forwards `--sandbox` |
| `scripts/resume_agent.sh` | Resume requires only `--sandbox`; name/project resolve from `.env` |
| `tests/test_session_env.sh` | P4 pins flipped to flag-wins; added `.env`-fallback and `AGENT_SANDBOX_*`-level tests (17 to 19) |
| `tests/test_dispatch.sh` | `test_package_branch` asserts `--sandbox` is forwarded |
| `docs/adr/env_precedence.md` | New ADR: centralized precedence resolver, flag-wins, rejected alternatives |
| `docs/concepts/sandbox_identity.md` | Primitives note `.env` storage; added Resolution Precedence section + ADR link + `make -C` contract |

## Deferred items

None.

## What's Next

M2.6 - Session Persistence. Remaining in the feature plan: **S3** (thin CLI + sandbox Makefile - an API-breaking surface, deferred for operator sign-off). The resolver, wire-in, and precedence flip (P4-P1-P2-P3-S1-S2) are landed; S4 (ADR + docs) is done.

**Conclusions from this iteration:** the flag-wins precedence flip landed in `session_env_common_init` (wired via `env_resolve_identity`); `resume` is now sandbox-only; `package-branch` forwards its sandbox. Docker runtime validation (`make start`/`make resume`) remains outstanding and is operator-verified.
