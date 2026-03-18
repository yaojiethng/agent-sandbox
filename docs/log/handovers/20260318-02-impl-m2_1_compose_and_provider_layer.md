# Agent Handover

**Session date:** 2026-03-18
**Milestone:** M2.1 — General Capability Layer Prototype
**Session type:** Implementation

## Objective
Implement orchestration & lifecycle task group: clean up reasoning layer container (remove sandbox code, rename `.agent-input/` → `workspace/input/`, introduce `workspace/output/`), produce dogfood `docker-compose.yml`, update `start_agent.sh` to two-container lifecycle via compose.

## Scope
Orchestration & lifecycle task group. `.agent-input/` rename scoped into this session. Build & context, UX layer (`agent-sandbox.sh`, Makefile template), compose base template, and end-to-end validation remain deferred.

## Acceptance criteria

- `make dry-run` completes end-to-end: both containers start, `dry_run.sh` runs inside the agent container, `workspace/output/liveness.txt` is written, containers tear down cleanly — **accepted**
- `make start` brings up two containers via compose; capability layer reaches healthy state before agent starts; OpenCode TUI takes over the terminal cleanly; session teardown writes `staged.diff` in `SANDBOX_DIR/.workspace/changes/` after the agent exits — **accepted**
- `make serve` starts agent with OpenCode in serve mode; port is accessible at `127.0.0.1:SERVE_PORT` — **accepted**
- Snapshot is built into `SANDBOX_DIR/.snapshot/` (not `.agent-input/snapshot/`); old `.agent-input/` directory is not created — **accepted**
- Agent container has no access to `workspace/changes/`; capability layer container has no access to `workspace/input/` or `workspace/output/` — **accepted**

## Hot files

| File | Why in scope |
|---|---|
| [`providers/opencode/Dockerfile`](providers/opencode/Dockerfile) | Remove entrypoint script COPY/chmod; mkdir for workspace/input and workspace/output; ENTRYPOINT ["opencode"] |
| [`libs/dirs.sh`](libs/dirs.sh) | Remove `AGENT_INPUT_DIR_NAME`, `WORKSPACE_DIR_NAME`; add `INPUT_DIR_NAME`, `OUTPUT_DIR_NAME` |
| `SANDBOX_DIR/docker-compose.yml` | New dogfood compose file; two-service model; correct mount shape; no ports; image names from .env |
| `SANDBOX_DIR/docker-compose.serve.yml` | New serve overlay; adds port binding and serve command to agent service |
| `SANDBOX_DIR/docker-compose.dry-run.yml` | New dry-run overlay; adds dry_run.sh bind mount to agent service |
| [`providers/opencode/start_agent.sh`](providers/opencode/start_agent.sh) | Two-container lifecycle via compose; .env writer; snapshot writes to .snapshot/; TUI fix via compose run |
| [`providers/opencode/run.sh`](providers/opencode/run.sh) | New: compose invocation with --rebuild flag; TUI fix |
| [`providers/opencode/build_sandbox.sh`](providers/opencode/build_sandbox.sh) | New: capability layer image build; always --no-cache |
| [`providers/opencode/build_agent.sh`](providers/opencode/build_agent.sh) | Accept --project/--sandbox/--brief/--env/--serve flags; image-files.txt path fix |
| [`scripts/agent-sandbox.sh`](scripts/agent-sandbox.sh) | image-files.txt path fix in preflight staleness check |
| [`libs/image.sh`](libs/image.sh) | Improved error messages for missing image-files.txt and missing listed files |
| [`scripts/dry_run.sh`](scripts/dry_run.sh) | Updated to new dir names via `dirs.sh`; checks `workspace/input/` and `workspace/output/`; writes liveness to `workspace/output/liveness.txt` |
| ~~[`scripts/container-entrypoint.sh`](scripts/container-entrypoint.sh)~~ | **Deleted** — no entrypoint script needed; opencode exec'd directly |
| [`docs/architecture/execution_model.md`](docs/architecture/execution_model.md) | All stale references updated; layout, terminology, mount shape, snapshot pipeline, entrypoint sequence |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| Reasoning layer gets `workspace/output/` rw mount | Dedicated output channel for agent logs, chat history, future provider output | `dirs.sh`, `Dockerfile`, compose, `start_agent.sh` |
| `.agent-input/` rename to `workspace/input/` scoped into this session | Touches same files as provider layer cleanup; no benefit to deferring | `Dockerfile`, `dirs.sh`, `start_agent.sh`, `execution_model.md` |
| Input files not copied into sandbox — agent reads from `workspace/input/` mount directly | Copying blurs reasoning/capability layer boundary | `Dockerfile`, `execution_model.md` |
| `.workspace/` rw mount on reasoning layer removed | Reasoning layer writes only to `workspace/output/` | `Dockerfile`, compose, `start_agent.sh` |
| No entrypoint script — `ENTRYPOINT ["opencode"]` directly | No setup remaining; serve args via overlay `command:`, dry-run via `compose exec` | `Dockerfile` |
| Serve args moved to `docker-compose.serve.yml` overlay `command:` | Config belongs in a file; consistent with dry-run overlay pattern | `docker-compose.serve.yml`, `start_agent.sh` |
| Image names derived in `start_agent.sh`, written to `.env`, referenced as variables in compose | Single source of truth; compose file never hardcodes names | `start_agent.sh`, `docker-compose.yml` |
| Standard mode uses `compose up -d sandbox` then `compose run --rm agent` | `compose up` multiplexes logs and does not pass TTY through; `compose run` attaches terminal directly, matching old `docker run -it` behaviour | `start_agent.sh`, `run.sh` |
| `build_sandbox.sh` always uses `--no-cache` | BuildKit cache produced stale layer errors on capability layer Dockerfile | `build_sandbox.sh` |

## Completed this session

| File | Change |
|---|---|
| `scripts/container-entrypoint.sh` | Deleted |
| `providers/opencode/Dockerfile` | `ENTRYPOINT ["opencode"]` directly; mkdir updated to `workspace/input/` and `workspace/output/` |
| `libs/dirs.sh` | `AGENT_INPUT_DIR_NAME` and `WORKSPACE_DIR_NAME` removed; `INPUT_DIR_NAME` and `OUTPUT_DIR_NAME` added |
| `SANDBOX_DIR/docker-compose.yml` | New dogfood compose; image names from `.env`; correct mount shape; no ports in base |
| `SANDBOX_DIR/docker-compose.serve.yml` | New serve overlay |
| `SANDBOX_DIR/docker-compose.dry-run.yml` | New dry-run overlay |
| `providers/opencode/start_agent.sh` | Two-container lifecycle; `.env` writer; snapshot to `.snapshot/`; TUI fix |
| `providers/opencode/run.sh` | New file: compose invocation; `--rebuild` flag; TUI fix |
| `providers/opencode/build_sandbox.sh` | New file: capability layer image build; always `--no-cache` |
| `providers/opencode/build_agent.sh` | Passthrough flags accepted; `image-files.txt` path fix |
| `scripts/agent-sandbox.sh` | `image-files.txt` path fix in staleness check |
| `libs/image.sh` | Improved error messages |
| `scripts/dry_run.sh` | New dir names; writes liveness to `workspace/output/liveness.txt` |
| `docs/architecture/execution_model.md` | All stale references removed; layout, terminology, mount shape, snapshot pipeline, entrypoint sequence updated |

## Deferred items

| Item | Reason | Next |
|---|---|---|
| `libs/_template/docker-compose.yml.template` | Base compose template for onboarded projects; derive from confirmed dogfood | Next session |
| `scripts/agent-sandbox.sh` full rewrite | `build sandbox|agent|all` variants; staleness pre-flight removal; `libs/image.sh` deletion is co-requisite | Build & context session |
| `Makefile` (project-side template) update | Depends on `agent-sandbox.sh` shape | Next session |
| `libs/build_context.sh` and `context/` dirs | `libs/image.sh` + `tests/test_image.sh` deletion included | Build & context session |
| `dry_run.sh` bind-mount → image copy | When `context/` restructuring lands, drop bind mount from overlay | Build & context session |
| `start_agent.sh` → pure pre-flight; `run.sh` → sole compose entry point | Currently duplicated; refactor deferred to keep scope contained | Next session |
| End-to-end validation | Requires `agent-sandbox.sh` and Makefile template operational | After UX layer complete |

## Next session
**M2.1 — General Capability Layer Prototype** (continue — UX layer + base compose template).

**Scope:** `libs/_template/docker-compose.yml.template`, `scripts/agent-sandbox.sh` rewrite, project-side Makefile template update, `start_agent.sh` pre-flight refactor.

**Watch-out items:**
1. `agent-sandbox.sh` must pass `--project-directory $SANDBOX_DIR` to all compose invocations so compose finds the right files regardless of cwd.
2. `libs/image.sh` deletion and `agent-sandbox.sh` staleness removal are co-requisites — neither is done until both are done.
3. `start_agent.sh` refactor: pre-flight only, then calls `run.sh`; removes the duplicated compose block at the bottom.
