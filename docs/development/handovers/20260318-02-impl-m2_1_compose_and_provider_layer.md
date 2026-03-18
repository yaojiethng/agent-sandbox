# Agent Handover

**Session date:** 2026-03-18
**Milestone:** M2.1 — General Capability Layer Prototype
**Session type:** Implementation

## Objective
Implement orchestration & lifecycle task group: clean up reasoning layer container (remove sandbox code, rename `.agent-input/` → `workspace/input/`, introduce `workspace/output/`), produce dogfood `docker-compose.yml`, update `start_agent.sh` to two-container lifecycle via compose.

## Scope
Orchestration & lifecycle task group. `.agent-input/` rename scoped into this session (touches same files). Build & context, dry-run, end-to-end validation remain deferred.

## Acceptance criteria

- `container-entrypoint.sh` contains no snapshot pipeline, no diff pipeline, no sandbox code — reads brief and input from `workspace/input/`, execs agent — **pending**
- `Dockerfile` (reasoning layer) creates `workspace/input/` and `workspace/output/` only; no `.agent-input/` or `.workspace/` mkdir — **pending**
- `dirs.sh` has `OUTPUT_DIR_NAME` (`workspace/output`); `AGENT_INPUT_DIR_NAME` and `WORKSPACE_DIR_NAME` removed — **pending**
- `docker-compose.yml` (dogfood) mounts match execution_model.md mount shape table; sandbox service healthcheck polls `sandbox/.git`; base compose has no ports; agent service uses `volumes_from` — **pending**
- `start_agent.sh` rewrites to two-container lifecycle: writes `.env` into `SANDBOX_DIR`, calls `docker compose up/down`; snapshot pipeline writes to `.snapshot/`; `.agent-input/` references gone — **pending**

## Hot files

| File | Why in scope |
|---|---|
| [`providers/opencode/Dockerfile`](providers/opencode/Dockerfile) | Remove entrypoint script COPY/chmod; mkdir for workspace/input and workspace/output; ENTRYPOINT ["opencode"] |
| [`libs/dirs.sh`](libs/dirs.sh) | Remove `AGENT_INPUT_DIR_NAME`, `WORKSPACE_DIR_NAME`; add `OUTPUT_DIR_NAME` |
| `SANDBOX_DIR/docker-compose.yml` | New dogfood compose file; two-service model; correct mount shape; no ports |
| `SANDBOX_DIR/docker-compose.serve.yml` | New serve overlay; adds port binding and serve command to agent service |
| `SANDBOX_DIR/docker-compose.dry-run.yml` | New dry-run overlay; adds dry_run.sh bind mount to agent service |
| [`providers/opencode/start_agent.sh`](providers/opencode/start_agent.sh) | Two-container lifecycle via compose; .env writer; snapshot writes to .snapshot/; .agent-input/ refs gone |
| [`scripts/dry_run.sh`](scripts/dry_run.sh) | Updated to new dir names and paths; writes liveness to workspace/output/ |
| ~~[`scripts/container-entrypoint.sh`](scripts/container-entrypoint.sh)~~ | **Deleted** — no entrypoint script needed; opencode exec'd directly |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| Reasoning layer gets `workspace/output/` rw mount | Dedicated output channel for agent logs, chat history, future provider output; keeps it separate from capability layer's `workspace/changes/` | `dirs.sh`, `Dockerfile`, compose, `start_agent.sh` |
| `.agent-input/` rename to `workspace/input/` scoped into this session | Touches the same files as provider layer cleanup; no benefit to deferring | `Dockerfile`, `dirs.sh`, `start_agent.sh` |
| Input layout is flat: `workspace/input/` contains `brief.md` and task files directly; agent reads them from the mount | No copying into sandbox; reasoning/capability layer boundary enforced | `Dockerfile`, compose, `start_agent.sh` |
| `.workspace/` rw mount on reasoning layer removed | Reasoning layer writes only to `workspace/output/`; `.workspace/` parent mount was temporary per execution_model.md | `Dockerfile`, compose, `start_agent.sh` |
| No entrypoint script — `ENTRYPOINT ["opencode"]` directly | Entrypoint was reduced to `exec "$@"` — no setup remaining; serve args handled by compose overlay command:, dry-run by compose exec; wrapper adds no value | `Dockerfile` |
| Serve args moved to `docker-compose.serve.yml` overlay `command:` | Config belongs in a file, not scattered in shell script; consistent with dry-run overlay pattern | `docker-compose.serve.yml`, `start_agent.sh` |

## Completed this session

| File | Change |
|---|---|
| `scripts/container-entrypoint.sh` | **Deleted** — no entrypoint script; opencode exec'd directly via `ENTRYPOINT ["opencode"]` in Dockerfile |
| `providers/opencode/Dockerfile` | Removed entrypoint COPY/chmod; `ENTRYPOINT ["opencode"]` directly; mkdir updated to `workspace/input/` and `workspace/output/` |
| `libs/dirs.sh` | `AGENT_INPUT_DIR_NAME` and `WORKSPACE_DIR_NAME` removed; `OUTPUT_DIR_NAME` added (`workspace/output`) |
| `SANDBOX_DIR/docker-compose.yml` | New dogfood compose; sandbox and agent services; correct mount shape; healthcheck on `sandbox/.git`; no ports in base |
| `SANDBOX_DIR/docker-compose.serve.yml` | New serve overlay; adds port binding and `command: ["serve", ...]` to agent service |
| `SANDBOX_DIR/docker-compose.dry-run.yml` | New dry-run overlay; adds `dry_run.sh` bind mount to agent service |
| `providers/opencode/start_agent.sh` | Two-container lifecycle via compose; writes `.env`; snapshot pipeline to `.snapshot/`; `.agent-input/` refs gone; serve via overlay |
| `scripts/dry_run.sh` | Updated to new dir names via `dirs.sh`; checks `workspace/input/` and `workspace/output/`; writes liveness to `workspace/output/liveness.txt` |

## Deferred items

| Item | Reason | Next |
|---|---|---|
| `libs/_template/docker-compose.yml.template` and mode overlays | Derive from confirmed dogfood compose | Next session |
| `scripts/agent-sandbox.sh` dispatch update | UX layer; depends on compose shape being confirmed | Next session |
| Makefile (project-side template) update | UX layer; depends on `agent-sandbox.sh` | Next session |
| `dry_run.sh` bind-mount → image copy | Currently bind-mounted via `DRY_RUN_SCRIPT` passed inline in `start_agent.sh` and dry-run overlay; when `context/` restructuring lands, copy into agent image instead — drop the overlay volume entry and `DRY_RUN_SCRIPT` resolution in `start_agent.sh` | Build & context task group |
| `libs/build.sh` and `context/` dirs | Build & context task group; depends on compose confirmed | Next session |
| `execution_model.md` dir names table | Still lists `AGENT_INPUT_DIR_NAME` and `WORKSPACE_DIR_NAME`; needs `INPUT_DIR_NAME` and `OUTPUT_DIR_NAME` | Doc debt before M2.1 close |
| End-to-end validation | Requires all containers and compose operational | After orchestration complete |

## Next session
**M2.1 — General Capability Layer Prototype** (continue — UX layer + templates).

**Scope:** Compose templates (base + serve + dry-run overlays), `agent-sandbox.sh` dispatch update, project-side Makefile template update.

**Watch-out items:**
1. `docker-compose.yml` compose file lives in `SANDBOX_DIR` — `agent-sandbox.sh` must pass `--project-directory $SANDBOX_DIR` (or `-f $SANDBOX_DIR/docker-compose.yml`) so compose finds it regardless of cwd.
2. `dry_run.sh` still writes liveness to old path — do not mark dry-run acceptance criteria complete until that file is updated in the dry-run task group.
3. Compose template `{{PROJECT_NAME}}` substitution must produce valid Docker resource names — confirm all interpolations are lowercase (compose image names and container names are case-sensitive).
