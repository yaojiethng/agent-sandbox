# Agent Handover

**Session date:** 2026-03-18
**Milestone:** M2.1 — General Capability Layer Prototype
**Session type:** Implementation

## Objective
Complete M2.1 implementation: UX layer (`libs/_template/docker-compose.yml.template`, `scripts/agent-sandbox.sh` rewrite, project-side Makefile template), onboarding (`workflow/general/scripts/onboard.sh`, `.env` ownership transfer), build & context model (`libs/build.sh`, `context/` directories, Dockerfile layer reorder), and `libs/image.sh` + `tests/test_image.sh` deletion. End-to-end validation is the exit gate.

## Scope

### Completed this session
Orchestration & lifecycle (partial), onboarding (new).

### Remaining — pushed to next session
- Documentation: `docs/operations/tool_interface.md` (new), `docs/architecture/execution_model.md` (update), `docs/operations/quickstart.md` (rewrite)
- Build & context: `libs/build.sh`, `providers/opencode/context/`, `SANDBOX_DIR/context/`, `providers/opencode/Dockerfile` layer reorder
- Cleanup: `libs/image.sh` + `tests/test_image.sh` deletion
- Validation: end-to-end test

## Acceptance criteria

Carried from M2.1 roadmap — sub-milestone gate:

- ✅ `make start` brings up two containers via `docker compose up`; capability layer starts first (service dependency)
- ⏭ Agent modifies a file in `sandbox/`; `staged.diff` appears in `SANDBOX_DIR/.workspace/changes/` after session ends — pushed to next session
- ⏭ `make apply` applies the diff cleanly to the host repo — pushed to next session
- ✅ `make serve` exposes port via compose override
- ✅ `make dry-run` runs both containers, reasoning writes to sandbox, graceful termination, diff written
- ⏭ Capability layer exits cleanly and triggers diff pipeline — pushed to next session
- ⏭ Capability layer container has no mount on `SANDBOX_DIR/.workspace/` parent — only `SANDBOX_DIR/.workspace/changes/`; reasoning layer has no mount on `SANDBOX_DIR/.snapshot/` — pushed to next session
- ✅ `make start` calls `docker build` before compose up; second `make start` with no file changes completes build step in under 5 seconds (cache hit) — `--no-cache` removed from `build_sandbox.sh`; Docker cache handles unchanged layers
- ⏭ `make build sandbox|agent|all` builds correct images from `context/` directories — pushed to next session

## Hot files

| File | Why in scope |
|---|---|
| [`libs/_template/docker-compose.yml.template`](libs/_template/docker-compose.yml.template) | Completed — rebuilt from dogfood |
| [`libs/_template/Makefile.template`](libs/_template/Makefile.template) | Completed — reads PROJECT_DIR/SANDBOX_DIR from .env via -include |
| [`scripts/agent-sandbox.sh`](scripts/agent-sandbox.sh) | Completed — two-image build, rebuild interface, serve subcommand, staleness removed |
| [`workflow/general/scripts/onboard.sh`](workflow/general/scripts/onboard.sh) | Completed — new file; full SANDBOX_DIR setup from templates |
| [`providers/opencode/start_agent.sh`](providers/opencode/start_agent.sh) | Completed — reads .env instead of writing it |
| [`Makefile`](Makefile) | Completed — dogfood; build-* variants, rebuild targets corrected |
| [`libs/build.sh`](libs/build.sh) | Next — `build_context` function replacing `image-files.txt` |
| `providers/opencode/context/` | Next — reasoning layer build context directory |
| `SANDBOX_DIR/context/` | Next — capability layer build context directory |
| [`providers/opencode/Dockerfile`](providers/opencode/Dockerfile) | Next — layer reorder: slow layers above `COPY context/` |
| [`libs/image.sh`](libs/image.sh) | Next — delete; unblocked (agent-sandbox.sh no longer sources it) |
| `tests/test_image.sh` | Next — delete; co-requisite with libs/image.sh |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| `serve` added as top-level subcommand in `agent-sandbox.sh` | `rebuild serve` implies serve is a first-class mode; CLI should be self-consistent — every mode you can rebuild into, you can invoke directly | `agent-sandbox.sh` |
| `.env` ownership transferred to `onboard.sh` | Path vars are fully derivable from flags and never change per-machine; rewriting on every run risked overwriting operator-set values; onboard writes once, `start_agent.sh` reads | `start_agent.sh`, `onboard.sh` |
| `PROJECT_DIR` and `SANDBOX_DIR` written to `.env` by onboard | Makefile uses `-include .env` so paths are never committed; portable across machines without editing the Makefile | `Makefile.template`, `onboard.sh` |
| `onboard.sh` prompts for missing flags interactively | Reduces friction; operator can run bare `agent-sandbox onboard general` and be guided through setup | `onboard.sh` |
| `workflow/general/scripts/onboard.sh` produces complete working SANDBOX_DIR | All template files copied, `.workspace/` dirs created, `.env` written, `agents.md` stub produced; operator only needs to fill in `agents.md` and review `.env` before first run | `onboard.sh` |
| `start_agent.sh` run.sh handoff removed | `run.sh` is future replacement, not current entrypoint; premature handoff duplicated work and broke `--brief`/`--env` passthrough | `start_agent.sh` |
| `--no-cache` removed from `build_sandbox.sh` | Consistent with roadmap decision: `docker build` runs on every `make start`; Docker cache provides sub-5s hit when nothing changed; `--no-cache` defeated this entirely | `build_sandbox.sh`, roadmap M2.1 decisions |
| `agents.md` is the brief convention for onboarded projects | `agent_context_brief.md` is the agent-sandbox dogfood convention; `agents.md` is the standard for all other projects | `onboard.sh`, `sandbox-onboarding_skill.md` |

## Completed this session

| File | Change |
|---|---|
| `libs/_template/docker-compose.yml.template` | Rebuilt from dogfood; `{{PROJECT_NAME}}` in container_name only; no ports in base; volumes_from pattern; env vars match dirs.sh |
| `libs/_template/Makefile.template` | `-include .env` / `export`; PROJECT_DIR/SANDBOX_DIR from .env; `?= $(error ...)` fallbacks; build-* variants; rebuild targets corrected; serve uses `agent-sandbox serve` |
| `scripts/agent-sandbox.sh` | Full rewrite: two-image build with sandbox/agent/all variants; serve as top-level subcommand; rebuild builds all then re-execs mode; preflight checks both images; staleness check and libs/image.sh sourcing removed |
| `workflow/general/scripts/onboard.sh` | New file: copies all template files, creates .workspace/ dirs, writes .env once, writes agents.md stub, prompts for missing flags, validates WSL/Linux paths, -h/--help usage block |
| `providers/opencode/start_agent.sh` | .env write block removed; reads .env and validates required vars; errors with onboard instructions if .env missing; compose logic retained in full; run.sh handoff removed |
| `Makefile` (dogfood) | build-sandbox/build-agent/build-all targets added; rebuild targets corrected to use rebuild [start/serve/dry-run] interface; serve target uses agent-sandbox serve; help updated |
| `providers/opencode/build_sandbox.sh` | `--no-cache` flag removed; Docker cache handles unchanged layers |

## Deferred items

| Item | Reason | Next |
|---|---|---|
| `docs/operations/tool_interface.md` | New doc; operator-facing CLI/Makefile reference; scoped to include `context/` model as target state | Next session (first — docs before implementation) |
| `docs/architecture/execution_model.md` | Remove stale CLI Wrapper and Image Digest sections; update paths and terminology | Next session |
| `docs/operations/quickstart.md` | Full rewrite; currently describes M1.x single-container flow | Next session |
| `libs/build.sh` + `context/` directories | Build & context group; after docs confirmed | Next session |
| `providers/opencode/Dockerfile` layer reorder | Depends on `context/` model being defined | Next session |
| `libs/image.sh` + `tests/test_image.sh` deletion | Unblocked — `agent-sandbox.sh` no longer sources `libs/image.sh` | Next session (first implementation task) |
| End-to-end validation | Requires build & context complete | Next session (closes M2.1) |
| Remaining acceptance criteria (⏭) | Require `context/` implementation and end-to-end validation | Next session |

## Next session
**M2.1 — General Capability Layer Prototype** (documentation, then build & context + cleanup + end-to-end validation).

**Session type:** Spec/Implementation — docs first, then implementation, then validation.

**Scope and order:**
1. **Documentation** (before any implementation):
   - `docs/operations/tool_interface.md` — new; operator-facing CLI and Makefile reference, build semantics, SANDBOX_DIR structure, `.env` ownership, container naming, onboarding flow. Scope to include `context/` model even though not yet implemented — write it as the target state.
   - `docs/architecture/execution_model.md` — remove CLI Wrapper and Image Digest & Staleness sections (staleness gone); update Directory Layout and terminology to current paths; keep mount shape, snapshot pipeline, entrypoint sequence, diff pipeline, container lifecycle.
   - `docs/operations/quickstart.md` — full rewrite; currently describes M1.x single-container flow with wrong paths and old onboarding steps; rewrite against two-container model and `onboard` CLI.
2. **Implementation** (after docs confirmed):
   - Delete `libs/image.sh` and `tests/test_image.sh` — unblocked, no dependencies
   - `libs/build.sh` — `build_context` function; hard error on missing file
   - `providers/opencode/context/` and `SANDBOX_DIR/context/` directories
   - `providers/opencode/Dockerfile` layer reorder
3. **End-to-end validation → sub-milestone close**

**Watch-out items:**
1. `tool_interface.md` folder: likely `docs/operations/` but confirm against `documentation_policy.md` — it is operator-facing reference, not architecture.
2. `libs/image.sh` deletion: confirm installed `agent-sandbox` binary no longer sources it before deleting — installed binary is a copy from `make install` and may be stale if not reinstalled this session.
3. After end-to-end validation passes, trigger Trigger B: compact completed task groups, promote M2.2 scope paragraph.
