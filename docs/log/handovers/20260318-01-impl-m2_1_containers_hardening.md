# Agent Handover

**Session date:** 2026-03-18
**Milestone:** M2.1 — General Capability Layer Prototype
**Session type:** Implementation

## Objective
Continue M2.1 implementation: harden container files produced in prior session, resolve ownership and mount shape issues discovered during validation, update docs and roadmap to reflect design decisions made.

## Scope
Continuation of capability layer container and shared harness task groups from prior session. No new task groups entered scope. Orchestration & lifecycle, build & context, dry-run, and end-to-end validation remain deferred.

## Acceptance criteria
- `VOLUME /home/agentuser/sandbox` declared in capability layer Dockerfiles; `--volumes-from` works correctly — **accepted**
- Capability layer mounts `workspace/changes/` only (not workspace parent); `sandbox-entrypoint.sh` writes only to `CHANGES_DIR` — **accepted**
- `libs/dirs.sh` replaces `WORKSPACE_DIR_NAME` with `CHANGES_DIR_NAME`; `WORKSPACE_DIR_NAME` retained for reasoning layer with temporary note — **accepted**
- `test_capability_layer.sh` signature updated to `<repo-root> <sandbox-dir>`; all mounts corrected; `set -euo pipefail` removed; build output surfaces on failure — **accepted**
- `context/` model and always-build decisions recorded in roadmap; `image-files.txt` staleness model superseded — **accepted**
- Base reasoning image (`opencode-base`) scoped in M2.2 — **accepted**
- `.agent-input/` → `workspace/input/` rename scoped as path alignment task — **accepted**
- `execution_model.md` mount shape section reflects subdirectory ownership model — **accepted**
- `agent_context_brief.md` Handover first rule added — **accepted**
- `test_capability_layer.sh` all checks passing — **accepted, confirmed by operator**

## Hot files

| File | Why in scope |
|---|---|
| [`libs/_template/dockerfile-default.sandbox`](libs/_template/dockerfile-default.sandbox) | VOLUME declaration added; working dirs updated to `workspace/changes/` |
| [`Dockerfile.sandbox`](Dockerfile.sandbox) | Same as above |
| [`libs/dirs.sh`](libs/dirs.sh) | `WORKSPACE_DIR_NAME` → `CHANGES_DIR_NAME`; ownership comments updated |
| [`scripts/sandbox-entrypoint.sh`](scripts/sandbox-entrypoint.sh) | Uses `CHANGES_DIR_NAME`; stale content clear removed; `--volumes-from` comments |
| [`providers/opencode/Dockerfile`](providers/opencode/Dockerfile) | `sandbox/` removed from `mkdir -p`; `--volumes-from` comment added |
| [`docs/architecture/execution_model.md`](docs/architecture/execution_model.md) | Mount shape table rewritten; `--volumes-from` rationale + VOLUME explanation; subdirectory ownership model |
| [`tests/test_capability_layer.sh`](tests/test_capability_layer.sh) | Signature fix; mount fixes; `set -e` removed; build output on failure; `VOLUME` model |
| [`agent_context_brief.md`](agent_context_brief.md) | Handover first rule added to Collaboration Protocol |
| [`roadmap.md`](roadmap.md) | `context/` model decisions; base image in M2.2; workspace/input rename task; build & staleness superseded; acceptance criteria updated |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| `VOLUME /home/agentuser/sandbox` required in capability layer Dockerfile | `--volumes-from` only exposes directories declared with `VOLUME`; without it sandbox exists only in writable layer and is invisible to other containers | Both capability Dockerfiles, `execution_model.md` |
| Anonymous volume removed with `docker rm -v` / `compose down -v` | Keeps lifecycle clean; each session gets fresh sandbox from image; no stale content across runs | `execution_model.md`, both Dockerfiles |
| Capability layer mounts `workspace/changes/` only — not workspace parent | Enforces ownership boundary at filesystem level; capability layer cannot write to `workspace/input/`; any write outside `workspace/changes/` from capability layer is a bug | `execution_model.md`, `dirs.sh`, `sandbox-entrypoint.sh`, both Dockerfiles |
| `workspace/changes` as `CHANGES_DIR_NAME` default in `dirs.sh` | Capability layer path is `workspace/changes/` (no dot, consistent with `sandbox/` convention); host-side backing store is `$SANDBOX_DIR/.workspace/changes/` | `libs/dirs.sh` |
| `.agent-input/` → `workspace/input/` rename scoped but not implemented | Rename confirmed as target model; reasoning layer workspace mount narrows from parent to subdirectory once done; deferred to keep M2.1 scope contained | Roadmap path alignment task |
| `context/` model replaces `image-files.txt`; `docker build` always runs on `make start` | `image-files.txt` maintenance burden grows with user-managed capability layers and multiple providers; Docker cache provides ~1s no-op when nothing changed | Roadmap M2.1 decisions |
| Base reasoning image (`opencode-base`) deferred to M2.2 | Slow layers (apt-get, npm install) extractable once M2.1 Dockerfile confirmed project-agnostic; M2.1 constraint: no project-specific content in reasoning Dockerfile | Roadmap M2.2 scope |
| Signal handling in bash PID 1 containers — correct pattern is `sleep infinity & wait $!` | `wait` with no jobs returns immediately; `sleep infinity` as foreground receives SIGTERM directly bypassing bash traps; `sleep infinity &` + `wait $!` keeps bash as signal receiver so TERM trap fires correctly | `sandbox-entrypoint.sh`, `execution_model.md` |
| `--entrypoint` flag required to run commands in image with ENTRYPOINT set | Without `--entrypoint`, arguments are passed to the entrypoint not executed directly; `docker run image test -f path` runs the entrypoint with `test -f path` as args, not `test` | `test_capability_layer.sh` |
| Test script must not use `set -euo pipefail` | Variable assignment with failing command triggers silent exit via cleanup trap; test scripts must handle all failures explicitly | `test_capability_layer.sh` |
| Test script args must be resolved to absolute paths | Docker bind mounts require absolute paths; relative paths cause daemon rejection | `test_capability_layer.sh` |

## Completed this session

| File | Change |
|---|---|
| `libs/_template/dockerfile-default.sandbox` | `VOLUME` declaration added; `mkdir -p` updated to `workspace/changes/` + `.snapshot/`; comment updated |
| `Dockerfile.sandbox` | Same as above |
| `libs/dirs.sh` | `WORKSPACE_DIR_NAME` replaced with `CHANGES_DIR_NAME` (default `workspace/changes`); `WORKSPACE_DIR_NAME` retained for reasoning layer with temporary note |
| `scripts/sandbox-entrypoint.sh` | Uses `CHANGES_DIR_NAME` from dirs.sh; `find -mindepth 1 -delete` removed; `--volumes-from` comments; `sleep infinity & wait $!` for correct signal handling in PID 1 bash container |
| `providers/opencode/Dockerfile` | `sandbox/` removed from `mkdir -p`; comment explains `--volumes-from` ownership |
| `docs/architecture/execution_model.md` | Mount shape section rewritten: subdirectory model, `--volumes-from` rationale, `VOLUME` explanation, updated table; entrypoint step 7 updated to `sleep infinity & wait $!` |
| `tests/test_capability_layer.sh` | Signature `<repo-root> <sandbox-dir>`; absolute path resolution; mounts corrected; `set -euo pipefail` removed; build output surfaced; `--entrypoint` for image content checks; `NO_CACHE` option; `WORKSPACE_CHANGES_DIR` throughout; HEALTHCHECK poll replaces `sleep 3`; random `RUN_ID` for container names; `docker rmi` in cleanup; all checks passing |
| `agent_context_brief.md` | Handover first added as first principle in Collaboration Protocol |
| `roadmap.md` | `context/` model decisions added; staleness decision superseded; build & context task group replaces build & staleness; base image task in M2.2; workspace/input rename task in path alignment; dry-run write path constraint noted; acceptance criteria corrected |

## Deferred items

| Item | Reason | Next |
|---|---|---|
| Orchestration & lifecycle (compose files, `start_agent.sh` rewrite) | Deferred to separate sessions; capability layer validated | Next session |
| Build & context (`libs/build_context.sh`, `context/` dirs, layer reorder) | Depends on compose shape being confirmed | Next session |
| `.agent-input/` → `workspace/input/` rename | Scoped; deferred to keep M2.1 contained; reasoning layer workspace mount narrows once complete | Path alignment task, next session or dedicated session |
| Dry-run update (`scripts/dry_run.sh`) | Not provided; write path constraint noted in roadmap; depends on lifecycle being settled | Next session |
| End-to-end validation | Requires all containers and compose built | After orchestration complete |
| `dry_run.sh` write path audit | File not uploaded; must be verified to write only to `workspace/changes/` | When dry-run task is implemented |
| `start_agent.sh` mount for capability layer | Must use `$SANDBOX_DIR/.workspace/changes/` not parent | When orchestration task is implemented |

## Next session
**M2.1 — General Capability Layer Prototype** (continue — orchestration & lifecycle).

**Scope:** Orchestration & lifecycle task group — dogfood `docker-compose.yml` first, then templates, then `start_agent.sh` two-container lifecycle rewrite.

**Watch-out items:**
1. Compose build context for `Dockerfile.sandbox` must be repo root — file lives in `SANDBOX_DIR`. Compose `build.context` must point to repo root explicitly.
2. Capability layer compose service must mount `$SANDBOX_DIR/.workspace/changes/` → `workspace/changes/` only — not the workspace parent. Reasoning layer mounts `.agent-input/` and `.workspace/` (parent, temporary).
3. `start_agent.sh` rewrite replaces imperative `docker run` with `docker compose up/down` but retains all other behaviour — snapshot pipeline, env loading, validation, `--volumes-from` wiring handled by compose `volumes_from:` service key.
