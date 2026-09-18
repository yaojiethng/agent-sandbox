# Agent Handover

**Date:** 2026-09-18
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Land S3 of the env-precedence feature: thin the identity surface so per-call `--name`/`--project`/`--sandbox` flags are no longer required. The resolver (flag > `AGENT_SANDBOX_*` > `.env` > hard error) fills identity from the environment or the per-sandbox `.env`, so the sandbox Makefile and the leaf entrypoints no longer demand all three flags per invocation.

## Scope

Pending operator confirmation (Gate 1). See the scope proposal in chat.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | `agent-sandbox <sub> --env=<path>` resolves identity when no flags are given and forwards it | `bash tests/test_dispatch.sh` | accepted (test_build_resolves_identity_from_env_file) |
| 2 | Identity flags are optional; an unresolvable identity is a hard error with an onboard hint | `bash tests/test_dispatch.sh` | accepted (test_build_missing_args) |
| 3 | Makefile run targets carry `--env=$(ENV_FILE)` and no identity flags | `bash tests/test_onboard.sh` | accepted (15/15) |
| 4 | Full suite stays green; `bash -n` and shellcheck clean on changed files | `run_tests.sh`, `bash -n`, shellcheck | accepted (842/842, rc=0) |
| 5 | ADR updated with the portable `ENV_FILE` pointer and `.env`-location precedence | `grep -q ENV_FILE docs/adr/env_resolution.md` | accepted |

## Decision

| Decision | Rationale | Where recorded |
|---|---|---|
| The dispatcher is the thin seam: it resolves a missing field lazily (flag > `AGENT_SANDBOX_*` > `.env` via `--env`/sandbox/CWD); onboard is exempt (it creates `.env`) | The CLI edge is what the sandbox Makefile invokes; leaves stay unchanged and keep their per-call validations | this handover |
| `ENV_FILE := $(CURDIR)/.env` | `$(MAKEFILE_LIST)`/`$(abspath)` are GNU-only; `$(CURDIR)` is portable and, under the `make -C` contract, equals the sandbox/Makefile directory | ADR `env_resolution.md` |
| `--env` is consumed by the dispatcher for resolution and not forwarded to the leaves; leaves read `<sandbox>/.env` (co-located with the `.env` the pointer names) | Avoids a relative/absolute split in start/resume `--env` handling; the standard `.env` is co-located | this handover |
| Backward compatible: `--name/--project/--sandbox` stay accepted, never deleted; removal is future work | Thin surface without breaking direct/scripted calls | this handover / roadmap |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Removal opportunities logged (future): `--name/--project` on `start`, `require_sandbox`/`require_project_sandbox` in the dispatcher are now unused, and the old relative `--env=`-on-start semantics are dead | scope change | later iterations |
| `$(MAKEFILE_LIST)`/`$(abspath)` are GNU-make-only (macOS BSD make lacks them); rejected in favour of `$(CURDIR)` | contradiction -> resolved | design record |
| Edge: an `--env` pointing to a `.env` not co-located with the sandbox dir drives resolution but the leaves read `<sandbox>/.env`; standard sandboxes co-locate them | scope change | later iterations |
| Operator-steered: subagent progress visibility is missing - a `pi -p` review round lost to network loss had no visible progress and had to be recovered from the raw session transcript. Need internal visibility into a running subagent (progressing / blocked / stalled) to triage interruptions. No solution yet; scoped under M3 (roadmap_future, Multi-Agent Coordination) | steering | roadmap_future M3 |

## Completed

| File | Change |
|---|---|
| `src/libs/env_resolve.sh` | Added `env_resolve_value` (single-identifier resolver) for the dispatcher seam |
| `scripts/agent-sandbox.sh` | `resolve_identity` seam: resolves `--name/--project/--sandbox` lazily from `--env`/env/CWD; `--env` parsed; onboard exempt; package-branch resolves sandbox |
| `scripts/templates/Makefile.template` | `ENV_FILE := $(CURDIR)/.env`; every run target drops identity flags and passes `--env=$(ENV_FILE)`; refresh keeps identity flags for onboard |
| `tests/test_dispatch.sh` | Assert thin resolution from `--env`; update the missing-args test; harness repoints `AGENT_SANDBOX_REPO` for resolution sourcing |
| `tests/test_onboard.sh` | `make stop`/`make start` targets assert `--env` and no identity flags |
| `docs/adr/env_resolution.md` | `.env`-location precedence + portable `$(CURDIR)` pointer and the non-co-located edge |

## Deferred items

None.

## What's Next

M2.6 - Session Persistence. S3 is the last planned step of the env-precedence feature; the roadmap task (line 119) can close once the operator confirms the docker smoke test (make start / make resume) against the resolved (`.env`-driven) identity.

**Conclusions from this iteration:** the thin CLI lands via dispatcher-level lazy resolution; the sandbox Makefile drops identity flags in favour of `--env=$(ENV_FILE)` (`$(CURDIR)/.env`), portable to GNU/BSD make under the `make -C` contract. Identity flags stay accepted (backward compatible) with removal opportunities logged.