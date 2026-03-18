# Agent Handover

**Session date:** 2026-03-18
**Milestone:** M2.1 — General Capability Layer Prototype
**Session type:** Implementation

## Objective
Refresh `tool_interface.md`, `execution_model.md`, and `quickstart.md` against implemented M2.1 state; implement `build_context` (mktemp model) and template versioning; close M2.1 with end-to-end validation and Trigger B.

## Scope
Documentation group, build & context group, template versioning, end-to-end validation, Trigger B.

## Acceptance criteria

- [x] `tool_interface.md` — Staleness Detection section absent; Onboarding section references `agent-sandbox onboard`; `.env` table includes `PROJECT_DIR` and `SANDBOX_DIR`; paths use `.workspace/input/` and `.workspace/output/`; build semantics describe `build_context` mktemp model
- [x] `execution_model.md` — CLI Wrapper section absent; Image Digest & Staleness section absent; Invocation Model describes `.env`-based model; Mount Shape table includes `output/` row; Build Context Model section present
- [x] `quickstart.md` — Onboarding section uses `agent-sandbox onboard`; brief file named `agents.md`; workspace listing includes `output/`; Recovery section references `.snapshot/`
- [x] End-to-end: agent modifies a file in `sandbox/`; `staged.diff` lands in `.workspace/changes/`; `make apply` applies the diff cleanly — confirmed by operator

## Hot files

| File | Why in scope |
|---|---|
| [`docs/operations/tool_interface.md`](docs/operations/tool_interface.md) | Doc refresh + build_context model |
| [`docs/architecture/execution_model.md`](docs/architecture/execution_model.md) | Doc refresh + build_context model |
| [`docs/operations/quickstart.md`](docs/operations/quickstart.md) | Doc refresh |
| [`libs/build_context.sh`](libs/build_context.sh) | New — build_context function |
| [`providers/opencode/build_sandbox.sh`](providers/opencode/build_sandbox.sh) | build_context integration + template version check |
| [`providers/opencode/build_agent.sh`](providers/opencode/build_agent.sh) | build_context integration |
| [`providers/opencode/Dockerfile`](providers/opencode/Dockerfile) | Flat COPY paths |
| [`libs/_template/dockerfile-default.sandbox`](libs/_template/dockerfile-default.sandbox) | Flat COPY paths + version tag |
| [`libs/_template/docker-compose.yml.template`](libs/_template/docker-compose.yml.template) | Version tag |
| [`libs/_template/Makefile.template`](libs/_template/Makefile.template) | Version tag |
| [`scripts/onboard.sh`](scripts/onboard.sh) | Template version recording + --refresh flag |
| [`Makefile`](Makefile) | make onboard / make refresh targets |
| [`tests/test_build_context.sh`](tests/test_build_context.sh) | New — property-based tests |
| `libs/image.sh` | Deleted |
| `tests/test_image.sh` | Deleted |
| `providers/opencode/image-files.txt` | Deleted |
| [`docs/development/roadmap.md`](docs/development/roadmap.md) | Trigger B — M2.1 compacted, M2.2 promoted |
| [`docs/development/roadmap_future.md`](docs/development/roadmap_future.md) | Trigger B — M2.2 removed |
| [`docs/development/changelog.md`](docs/development/changelog.md) | M2.1 entry appended |
| [`docs/development/project_index.md`](docs/development/project_index.md) | M2.1 files updated; Tests section added |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| `build_context` uses `mktemp -d` rather than a persistent `context/` directory | No repo artefacts; no `.gitignore` entries needed; temp dir lifecycle is self-contained | `execution_model.md`, `tool_interface.md` |
| Dockerfile `COPY` paths are flat, matching temp dir layout | Decouples Dockerfile from repo directory structure | `providers/opencode/Dockerfile`, `libs/_template/dockerfile-default.sandbox` |
| Template version tag embedded in each onboarded template file | Version travels with the file; `build_sandbox.sh` greps both installed and current template to detect staleness | `scripts/onboard.sh`, `providers/opencode/build_sandbox.sh` |
| `onboard --refresh` updates versioned template files and `.env` version lines only | Preserves operator-set values and `agents.md`; targeted refresh without full re-onboard | `scripts/onboard.sh` |

## Completed this session

| File | Change |
|---|---|
| `docs/operations/tool_interface.md` | Removed Staleness Detection; rewrote Onboarding around `agent-sandbox onboard`; corrected image naming; corrected paths; Build Inputs section added describing mktemp model |
| `docs/architecture/execution_model.md` | Removed CLI Wrapper and Image Digest sections; rewrote Invocation Model; added `output/` row to Mount Shape; added Build Context Model section |
| `docs/operations/quickstart.md` | Rewrote onboarding around `agent-sandbox onboard`; corrected brief filename, workspace listing, Recovery path |
| `libs/build_context.sh` | New: `build_context`; sandbox and agent types; mktemp; ERR trap; hard error on missing file |
| `libs/_template/dockerfile-default.sandbox` | Flat COPY paths; template version tag (`version: 1`) |
| `libs/_template/docker-compose.yml.template` | Template version tag (`version: 1`) |
| `libs/_template/Makefile.template` | Template version tag (`version: 1`) |
| `providers/opencode/Dockerfile` | Flat COPY path for `dirs.sh` |
| `providers/opencode/build_sandbox.sh` | build_context integration; digest label; template version staleness check; corrected REPO_ROOT |
| `providers/opencode/build_agent.sh` | build_context integration; replaces image.sh sourcing and image-files.txt |
| `scripts/onboard.sh` | Template version recording; `--refresh` flag; usage block updated |
| `Makefile` (repo-level) | `make onboard` and `make refresh` targets |
| `tests/test_build_context.sh` | New: property-based tests for build_context |
| `libs/image.sh` | Deleted |
| `tests/test_image.sh` | Deleted |
| `providers/opencode/image-files.txt` | Deleted |
| `docs/development/roadmap.md` | Trigger B: M2.1 compacted, decisions updated, M2.2 promoted with full task list |
| `docs/development/roadmap_future.md` | M2.2 section removed |
| `docs/development/changelog.md` | M2.1 entry appended |
| `docs/development/project_index.md` | Touched files updated to M2.1; image.sh removed; build_context.sh and test_build_context.sh added; Tests section added |

## Deferred items

None.

## Next session
**M2.2 — Reasoning Layer Modularisation.**

At session open (Step 1): compact any fully-checked task groups from this session in `roadmap.md` (none expected — Trigger B already compacted M2.1).

Read the M2.2 task list in `roadmap.md` before beginning. M2.2 opens with a design step — the shared logic extraction requires auditing `start_agent.sh` and `container-entrypoint.sh` before any files are changed.

**Watch-out items:**
1. M2.2 depends on M2.1 being fully applied to the repo — confirm all session outputs are committed before starting.
2. The base reasoning image extraction (M2.2 base image group) must not bake project-specific content — this constraint is recorded in M2.1 decisions and must be preserved through the refactor.
