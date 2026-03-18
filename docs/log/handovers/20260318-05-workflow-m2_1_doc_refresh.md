# Agent Handover

**Session date:** 2026-03-18
**Milestone:** M2.1 — General Capability Layer Prototype
**Session type:** Implementation

## Objective
Refresh `tool_interface.md`, `execution_model.md`, and `quickstart.md` against implemented M2.1 state; then extend `execution_model.md` and `tool_interface.md` to describe the `context/` directory model. Session ends when documentation reflects the `context/` model as current architecture.

## Scope
Documentation group from M2.1 roadmap task list — the three unchecked documentation tasks — plus the `context/` model description in architecture docs.

Doc refresh tasks:
- `docs/operations/tool_interface.md`
- `docs/architecture/execution_model.md`
- `docs/operations/quickstart.md`

`context/` model extension (this session):
- `docs/architecture/execution_model.md` — add `context/` build model; remove `image-files.txt` references
- `docs/operations/tool_interface.md` — describe `context/` directory as build input source; update build semantics

`context/` implementation (next session):
- `libs/build.sh`, `providers/opencode/context/`, `SANDBOX_DIR/context/`, `providers/opencode/Dockerfile` layer reorder, `libs/image.sh` + `tests/test_image.sh` deletion, end-to-end validation

## Acceptance criteria

- [ ] `tool_interface.md` — Staleness Detection section absent; Onboarding section references `agent-sandbox onboard`; `.env` table includes `PROJECT_DIR` and `SANDBOX_DIR`; paths use `.workspace/input/` and `.workspace/output/`; build semantics describe `context/` as the build input source
- [ ] `execution_model.md` — CLI Wrapper section absent; Image Digest & Staleness section absent; Invocation Model describes `.env`-based model; Mount Shape table includes `output/` row and contains no future-language notes; `context/` model described
- [ ] `quickstart.md` — Onboarding section uses `agent-sandbox onboard`; brief file named `agents.md`; workspace listing includes `output/`; Recovery section references `.snapshot/` not `.agent-input/`

## Hot files

| File | Why in scope |
|---|---|
| [`docs/operations/tool_interface.md`](docs/operations/tool_interface.md) | Doc refresh + `context/` model description |
| [`docs/architecture/execution_model.md`](docs/architecture/execution_model.md) | Doc refresh + `context/` model description |
| [`docs/operations/quickstart.md`](docs/operations/quickstart.md) | Doc refresh — onboarding flow described M1.x single-container model |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| `build_context` uses `mktemp -d` rather than a persistent `context/` directory | No repo artefacts; no `.gitignore` entries needed; temp dir lifecycle is clean and self-contained; digest computed from temp dir contents is equivalent to any other content-addressed approach | `libs/build.sh`, `execution_model.md`, `tool_interface.md` |
| Dockerfile `COPY` paths are flat, matching temp dir layout | Decouples Dockerfile from repo directory structure; build context is always the temp dir regardless of where source files live in the repo | `Dockerfile`, `dockerfile-default.sandbox` |

## Completed this session

| File | Change |
|---|---|
| `docs/operations/tool_interface.md` | Removed Staleness Detection section; rewrote Onboarding section around `agent-sandbox onboard`; corrected image naming to `agent-sandbox-<project>` / `opencode-agent-<project>`; added `PROJECT_DIR`/`SANDBOX_DIR` to `.env` table; corrected input/output dir paths; added `make rebuild dry-run`; replaced Capability Layer Dockerfile section with Build Inputs section describing `build_context` mktemp model |
| `docs/architecture/execution_model.md` | Removed CLI Wrapper section; removed Image Digest & Staleness section; rewrote Invocation Model for `.env`-based model; added `output/` row to Mount Shape table; removed future-language note; corrected `agents.md` reference; added Build Context Model section describing mktemp approach |
| `docs/operations/quickstart.md` | Rewrote onboarding section around `agent-sandbox onboard`; corrected brief filename to `agents.md`; added `output/` to workspace listing; corrected Recovery section path from `.agent-input/` to `.snapshot/`; simplified pre-run checklist |
| `libs/build_context.sh` | New: `build_context` function; `sandbox` and `agent` image types; `mktemp -d` build context; hard error on missing source file; ERR trap removes partial context on failure; prints temp dir path to stdout for caller to use and clean up |
| `libs/_template/dockerfile-default.sandbox` | `COPY` paths updated from repo-relative to flat filenames matching temp dir layout; template version tag added (`version: 1`) |
| `libs/_template/docker-compose.yml.template` | Template version tag added (`version: 1`) |
| `libs/_template/Makefile.template` | Template version tag added (`version: 1`); `onboard general` → `onboard` throughout |
| `providers/opencode/Dockerfile` | `COPY libs/dirs.sh` updated to `COPY dirs.sh` matching temp dir layout |
| `providers/opencode/build_sandbox.sh` | Sources `libs/build_context.sh`; calls `build_context sandbox`; temp dir build context; digest label; template version staleness check for all three versioned files; warns with `agent-sandbox onboard --refresh`; fixed `REPO_ROOT` to `$SCRIPT_DIR/..` |
| `providers/opencode/build_agent.sh` | Removes `libs/image.sh` sourcing and `image-files.txt` digest; sources `libs/build_context.sh`; calls `build_context agent`; same temp dir and digest pattern |
| `scripts/onboard.sh` | Reads template version from each template at copy time; records `DOCKERFILE_SANDBOX_VERSION`, `COMPOSE_VERSION`, `MAKEFILE_VERSION` in `.env`; `--refresh` flag added; usage block updated; `onboard general` → `onboard` throughout; script path comment corrected |
| `Makefile` (repo-level) | `make onboard` and `make refresh` targets added targeting dogfood `sandbox/`; help text updated |
| `tests/test_build_context.sh` | New: property-based tests for `build_context`; output contract, file contents per image type, content fidelity, isolation, digest determinism, caller cleanup, error cases |
| `libs/image.sh` | Delete (operator action — `git rm`) |
| `tests/test_image.sh` | Delete (operator action — `git rm`) |
| `providers/opencode/image-files.txt` | Delete (operator action — `git rm`) |

## Deferred items

| Item | Reason | Next |
|---|---|---|
| End-to-end validation | Requires operator to apply outputs and run full end-to-end | Next session |

## Next session
**M2.1 — General Capability Layer Prototype** (end-to-end validation → sub-milestone close).

At session open (Step 1): compact completed task groups in `roadmap.md`.

Then:

1. Run `make build all` — confirm both images build; check digest label present (`docker inspect <image> | grep digest`)
2. Run `make dry-run` — confirm both containers start, reasoning writes to sandbox, diff written
3. Run full end-to-end: `make start`, agent modifies a file, `make stop`, inspect `staged.diff`, `make apply`
4. Trigger B: compact completed task groups, promote M2.2 scope paragraph

**Watch-out items:**
1. Confirm `grep "image.sh" scripts/agent-sandbox.sh` returns nothing before deleting `libs/image.sh` — installed binary may be stale if not reinstalled this session.
2. After end-to-end validation passes, trigger Trigger B immediately — M2.1 is complete.
