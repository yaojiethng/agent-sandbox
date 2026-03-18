# Agent Handover

**Session date:** 2026-03-17
**Milestone:** M2.1 — General Capability Layer Prototype
**Session type:** Implementation

## Objective
Implement capability layer container files, update reasoning layer container files, document exit flow, and produce a standalone functional test script.

## Scope
Capability layer container task group, reasoning layer container task group, and the `execution_model.md` doc update for exit flow. Orchestration & lifecycle, build & staleness, dry-run, and end-to-end validation deferred.

## Acceptance criteria
- `dockerfile-default.sandbox` exists as capability layer Dockerfile template — **produced, awaiting operator commit**
- `Dockerfile.sandbox` exists as dogfood project-level capability layer Dockerfile — **produced, awaiting operator commit**
- `scripts/sandbox-entrypoint.sh` implements entrypoint sequence per `execution_model.md` — **produced, awaiting operator commit**
- `providers/opencode/container-entrypoint.sh` stripped to brief injection, input copy, exec only — **produced, awaiting operator commit**
- `providers/opencode/Dockerfile` stripped of snapshot/diff libs — **produced, awaiting operator commit**
- `docs/architecture/execution_model.md` stop sequence and entrypoint sequence reflect TERM trap and full signal path — **produced, awaiting operator commit**
- `test_capability_layer.sh` covers startup, mutation via `--volumes-from`, shutdown, diff integrity, and gate 2 failure case — **produced, awaiting operator commit**

## Hot files

| File | Why in scope |
|---|---|
| [`libs/_template/dockerfile-default.sandbox`](libs/_template/dockerfile-default.sandbox) | New: capability layer Dockerfile template |
| [`Dockerfile.sandbox`](Dockerfile.sandbox) | New: dogfood project-level capability layer Dockerfile (lives in SANDBOX_DIR) |
| [`scripts/sandbox-entrypoint.sh`](scripts/sandbox-entrypoint.sh) | New: capability layer entrypoint |
| [`providers/opencode/container-entrypoint.sh`](providers/opencode/container-entrypoint.sh) | Stripped to reasoning layer responsibilities only |
| [`providers/opencode/Dockerfile`](providers/opencode/Dockerfile) | Removed snapshot/diff libs, updated mount point dirs |
| [`docs/architecture/execution_model.md`](docs/architecture/execution_model.md) | Stop sequence and entrypoint sequence updated for TERM trap and exit flow |
| [`tests/test_capability_layer.sh`](tests/test_capability_layer.sh) | New: standalone functional test script |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| Add `trap 'exit 0' TERM` alongside EXIT trap in `sandbox-entrypoint.sh` | `docker stop` sends SIGTERM to PID 1; without TERM trap bash exits 143 which some tooling treats as error; clean exit ensures EXIT trap fires reliably | `execution_model.md`, `sandbox-entrypoint.sh` |
| Signals do not cross container boundaries | SIGTERM from ctrl-c on reasoning layer does not reach capability layer; harness (`docker stop`) is the shutdown path for capability layer | Chat — not recorded in a doc; low risk as it is a clarification not a design decision |
| `container-entrypoint.sh` retained (not eliminated) | Still needed for brief injection and input copy; elimination decision deferred until those responsibilities are confirmed to have no other home | Roadmap deferred items |
| Use `--volumes-from` for mutation in functional test | Tests the actual shared-volume trust boundary rather than exec directly into capability layer process; matches production reasoning layer mount | `test_capability_layer.sh` comments |
| `Dockerfile.sandbox` is identical to template for dogfood case | agent-sandbox project has no capability layer customisation needs; template derived from working version per roadmap decision | Roadmap |

## Completed this session

| File | Change |
|---|---|
| `libs/_template/dockerfile-default.sandbox` | New: capability layer Dockerfile template; Ubuntu base, bash/git only, copies sandbox-entrypoint.sh + libs |
| `Dockerfile.sandbox` | New: dogfood capability layer Dockerfile for agent-sandbox SANDBOX_DIR; identical to template with build context note |
| `scripts/sandbox-entrypoint.sh` | New: capability layer entrypoint; full sequence per execution_model.md including TERM trap |
| `providers/opencode/container-entrypoint.sh` | Stripped from ~120 lines to ~50; removed snapshot/diff/git/autosave; brief + input copy + exec only |
| `providers/opencode/Dockerfile` | Removed COPY libs lines; fixed `/var/libs/` typo → `/var/lib/`; updated mount dirs `.bootstrap` → `.agent-input` |
| `docs/architecture/execution_model.md` | Stop sequence expanded to 4 steps with full signal path; entrypoint sequence adds TERM trap as step 5, renumbers to 7 steps |
| `tests/test_capability_layer.sh` | New: standalone functional test; covers build, startup, mutation via --volumes-from, shutdown, diff integrity, gate 2 failure case |

## Deferred items

| Item | Reason | Next |
|---|---|---|
| Orchestration & lifecycle (compose files, `start_agent.sh` rewrite) | Capability layer must be smoke-tested standalone before compose is built | Next session, after operator runs `test_capability_layer.sh` |
| Build & staleness (two-image `image-files.txt` split, per-image rebuild dispatch) | Caller-side; depends on compose and `start_agent.sh` shape being confirmed | Next session |
| Path alignment in `start_agent.sh` (`.agent-input/` → `.snapshot/`) | Caller-side; part of `start_agent.sh` rewrite | Next session |
| Dry-run update (`scripts/dry_run.sh`) | Depends on compose and lifecycle being settled | Next session |
| End-to-end validation | Requires all containers and compose built | After orchestration complete |
| `container-entrypoint.sh` elimination decision | Brief injection still needed; no other home confirmed yet | Revisit during reasoning layer modularisation (M2.2) |

## Next session
**M2.1 — General Capability Layer Prototype** (continue implementation — orchestration & lifecycle).

**Prerequisite:** Operator runs `test_capability_layer.sh` against a pre-built `.snapshot/` and confirms all checks pass before orchestration work begins.

**Scope:** Orchestration & lifecycle task group — compose files (dogfood first, then templates), then `start_agent.sh` two-container lifecycle rewrite.

**Watch-out items:**
1. Compose build context for `Dockerfile.sandbox` must be repo root — the file lives in `SANDBOX_DIR` (a sibling dir). Compose `build.context` field needs to point to repo root explicitly.
2. `start_agent.sh` currently uses imperative `docker run`; the rewrite replaces this with `docker compose up/down` but retains all other behaviour (snapshot pipeline, env loading, validation).
3. Roadmap specifies dogfood compose file is created first in agent-sandbox's own `SANDBOX_DIR`, template derived from it — do not produce template first.
