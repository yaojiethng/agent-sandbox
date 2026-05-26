# Agent Handover

**Session date:** 2026-05-26
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Implementation
**Status:** Closed

**Mid-session findings (from subsequent fix pass):**
- `all-changes.diff` does not always apply cleanly to baseline — per-commit patches can fail due to context drift between intermediate commits. Shelved — requires deeper investigation of patch behaviour.
- `package_branch.sh` COPY target had underscore name (`package_branch.sh`) but everything consumed it as dash (`package-branch.sh`). Also `diff_export.sh` was not deployed to any container. Both fixed.
- Other provider Dockerfiles (claude-code, hermes, opencode) had stale COPY paths — old `provider-entrypoint.sh` name, missing packaging files. All updated to match pi provider.
- Added `test_diff_export.sh` (3 tests) and `test_packaging_symmetry.sh` (2 tests) to cover identified gaps.

## Objective

Move all files from `libs/` to their target directories per the structural cleanup design (`build/`, `src/libs/`, `src/capability/`, `src/reasoning/`, `scripts/workflows/`), update every source/COPY/exec path to match, and fix the packaging pipeline deployment asymmetry.

## Scope

**In scope — file moves:**
- `libs/containers.sh` → split: naming→`build/image.sh`, context→`build/context.sh`, orchestration→`scripts/build.sh`
- `libs/compose.sh` → `build/compose.sh`
- `libs/docker-compose.yml` → `build/docker-compose.yml`
- `libs/docker-compose.dry-run.yml` → `build/docker-compose.dry-run.yml`
- `libs/diff.sh` → `src/libs/diff.sh` (+ extract `diff_export` to `src/libs/diff_export.sh`)
- `libs/dirs.sh` → `src/libs/dirs.sh`
- `libs/routing.sh` → `src/libs/routing.sh`
- `libs/session.sh` → split: `session_state.sh`→`src/libs/`, `guards.sh`→`scripts/guards.sh`
- `libs/snapshot.sh` → `src/capability/snapshot.sh`
- `libs/sandbox-entrypoint.sh` → `src/capability/entrypoint.sh`
- `libs/sandbox.Dockerfile` → `src/capability/Dockerfile`
- `libs/provider-entrypoint.sh` → `src/reasoning/entrypoint.sh`
- `libs/package_branch.sh` → `src/libs/package_branch.sh`
- `libs/package_diff.sh` → `src/libs/package_diff.sh`
- `libs/diff_workflow.sh` → `scripts/workflows/apply.sh`
- `libs/draft_workflow.sh` → split: `scripts/workflows/draft.sh`, `confirm.sh`, `reject.sh`
- `libs/interactive_session_select.sh` → `scripts/workflows/interactive.sh`
- `libs/_templates/` → `scripts/templates/`
- `libs/checkpoint.sh` → `scripts/checkpoint.sh` ... wait, checkpoint is already in libs/ now.
- `libs/session.sh` → split into `src/libs/session_state.sh` + `scripts/guards.sh`

**Also:**
- Fix packaging pipeline asymmetry — `diff.sh`, `package_branch.sh`, `package_diff.sh` all deployed to both containers
- Update `containers.sh` build_context source paths
- Update Dockerfile COPY paths in both sandbox.Dockerfile and provider.Dockerfile
- Update every source/exec path that references a moved file

**Explicitly deferred:**
- This session is large enough — nothing else

## Carried forward

None.

## Acceptance criteria

Not yet defined.

## Hot files

| File | Why in scope |
|---|---|
| Every file in `libs/` | Moving to target directories |
| `scripts/` | Receiving split files (workflows/, build.sh, guards.sh) |
| `containers.sh` | build_context source paths must update |
| `sandbox.Dockerfile` | COPY source paths must update |
| `providers/pi/provider.Dockerfile` | COPY source paths must update |
| All `tests/test_*.sh` | Source paths reference moved files |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| checkpoint.sh dissolved into build/image.sh | Single pure function worktree_id_derive belongs with container identity naming | Handover mid-session finding |
| Copy-then-remove strategy for file moves | Both old and new paths exist simultaneously during transition; tests pass at every intermediate state | Session workflow |

## Mid-session findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `checkpoint.sh` contains one pure function `worktree_id_derive` — belongs with container identity naming in `build/image.sh` | Correctness | `checkpoint.sh` dissolved; function merged into `build/image.sh` alongside `agent_base_image_name`, `agent_image_name`, `sandbox_image_name`. `start_agent.sh` sources `build/image.sh` instead. | This session |
| `libs/checkpoint.sh` disappears entirely — no standalone file needed | Simplification | One fewer file to maintain; function inlined into natural home | This session |

## Completed this session

| File | Change |
|---|---|
| `src/build/image.sh` | added — image naming + container identity (extracted from libs/containers.sh + libs/checkpoint.sh) |
| `src/build/context.sh` | added — build context prep (extracted from libs/containers.sh) |
| `src/build/compose.sh` | renamed from libs/compose.sh |
| `src/build/docker-compose.yml` | renamed from libs/docker-compose.yml |
| `src/build/docker-compose.dry-run.yml` | renamed from libs/docker-compose.dry-run.yml |
| `scripts/build.sh` | added — build orchestration (build_image, build_agent, build_sandbox, preflight) |
| `scripts/guards.sh` | added — git workflow guards (validate_project_dir, draft_clear_stale_lock) |
| `scripts/workflows/draft.sh` | renamed from libs/draft_workflow.sh (draft_run + helpers only) |
| `scripts/workflows/confirm.sh` | added — confirm_run (split from draft_workflow.sh) |
| `scripts/workflows/reject.sh` | added — reject_run (split from draft_workflow.sh) |
| `scripts/workflows/apply.sh` | renamed from libs/diff_workflow.sh |
| `scripts/workflows/interactive.sh` | renamed from libs/interactive_session_select.sh |
| `scripts/templates/` | renamed from libs/_templates/ |
| `src/libs/session_state.sh` | added — session_state_read/write (extracted from libs/session.sh) |
| `src/libs/routing.sh` | renamed from libs/routing.sh |
| `src/libs/diff.sh` | renamed from libs/diff.sh |
| `src/libs/diff_export.sh` | added — diff_export orchestrator (extracted from libs/diff.sh) |
| `src/libs/dirs.sh` | renamed from libs/dirs.sh |
| `src/libs/package_branch.sh` | renamed from libs/package_branch.sh |
| `src/libs/package_diff.sh` | renamed from libs/package_diff.sh |
| `src/capability/entrypoint.sh` | renamed from libs/sandbox-entrypoint.sh |
| `src/capability/Dockerfile` | renamed from libs/sandbox.Dockerfile |
| `src/capability/snapshot.sh` | renamed from libs/snapshot.sh |
| `src/reasoning/entrypoint.sh` | renamed from libs/provider-entrypoint.sh |
| `providers/pi/provider.Dockerfile` | modified — COPY paths updated; packaging symmetrical |
| `providers/claude-code/provider.Dockerfile` | modified — COPY paths updated; packaging symmetrical |
| `providers/hermes/provider.Dockerfile` | modified — COPY paths updated; packaging symmetrical |
| `providers/opencode/provider.Dockerfile` | modified — COPY paths updated; packaging symmetrical |
| `scripts/agent-sandbox.sh` | modified — source paths updated to new locations |
| `scripts/start_agent.sh` | modified — source paths updated; checkpoint.sh dissolved |
| `scripts/run_agent.sh` | modified — source paths updated |
| `scripts/onboard.sh` | modified — templates path updated |
| `tests/libs/mock_repo_fixtures.sh` | modified — creates new src/ layout for build context tests |
| `tests/test_build_context.sh` | modified — source paths and mock paths updated |
| `tests/test_checkpoint.sh` | modified — source path to src/build/image.sh |
| `tests/test_diff_dispatch.sh` | modified — source path to src/libs/ |
| `tests/test_diff_helpers.sh` | modified — source path to src/libs/ |
| `tests/test_diff_workflow.sh` | modified — source path + AGENT_SANDBOX_REPO |
| `tests/test_dirs.sh` | modified — source path to src/libs/ |
| `tests/test_draft_workflow.sh` | modified — sources split workflow files + guards |
| `tests/test_interactive_session_select.sh` | modified — source path + AGENT_SANDBOX_REPO |
| `tests/test_package_branch.sh` | modified — source path to src/libs/ |
| `tests/test_package_diff.sh` | modified — source path to src/libs/ |
| `tests/test_provider_entrypoint.sh` | modified — source path to src/reasoning/entrypoint.sh |
| `tests/test_routing.sh` | modified — source path to src/libs/ |
| `tests/test_session.sh` | modified — sources session_state.sh + guards.sh |
| `tests/test_snapshot_container.sh` | modified — source path to src/libs/session_state.sh |
| `tests/test_start_agent.sh` | modified — docker-compose path to src/build/ |
| `tests/test_diff_export.sh` | added — 3 tests for diff_export orchestrator |
| `tests/test_packaging_symmetry.sh` | added — 2 tests for packaging pipeline deployment |
| `.gitignore` | modified — exceptions for src/build/*.sh and src/build/*.yml |
| `agent/drafts/bash-dependency-audit.skill.md` | added — bash dependency audit process |
| `agent/drafts/refactor-mv-rename-file.skill.md` | added — rename/move workflow skill |
| `docs/concepts/context_resolution.md` | added — three-layer context resolution model |
| `devlog/discussions/20260526-design-shared_library_organisation.md` | added — libs/ refactor design |
| `devlog/discussions/20260526-spec-path_resolution_convention.md` | added — path resolution spec |
| `docs/devlog/handovers/20260526-06-impl-libs_file_moves.md` | added — this handover |
| `libs/compose.sh` | deleted — moved to src/build/compose.sh |
| `libs/containers.sh` | deleted — split into src/build/{image,context}.sh + scripts/build.sh |
| `libs/diff.sh` | deleted — moved to src/libs/diff.sh + src/libs/diff_export.sh |
| `libs/diff_workflow.sh` | deleted — moved to scripts/workflows/apply.sh |
| `libs/dirs.sh` | deleted — moved to src/libs/dirs.sh |
| `libs/draft_workflow.sh` | deleted — split into scripts/workflows/{draft,confirm,reject}.sh |
| `libs/interactive_session_select.sh` | deleted — moved to scripts/workflows/interactive.sh |
| `libs/package_branch.sh` | deleted — moved to src/libs/package_branch.sh |
| `libs/package_diff.sh` | deleted — moved to src/libs/package_diff.sh |
| `libs/provider-entrypoint.sh` | deleted — moved to src/reasoning/entrypoint.sh |
| `libs/routing.sh` | deleted — moved to src/libs/routing.sh |
| `libs/sandbox-entrypoint.sh` | deleted — moved to src/capability/entrypoint.sh |
| `libs/session.sh` | deleted — split into src/libs/session_state.sh + scripts/guards.sh |
| `libs/snapshot.sh` | deleted — moved to src/capability/snapshot.sh |
| `libs/checkpoint.sh` | deleted — dissolved into src/build/image.sh |
| `libs/docker-compose.yml` | deleted — moved to src/build/docker-compose.yml |
| `libs/docker-compose.dry-run.yml` | deleted — moved to src/build/docker-compose.dry-run.yml |
| `libs/sandbox.Dockerfile` | deleted — moved to src/capability/Dockerfile |
| `libs/_templates/` | deleted — moved to scripts/templates/ |

## Deferred items

| Item | Reason |
|---|---|
| providers/ directory restructuring | Spec scope only covered libs/ — providers/, agent/, docs/devlog/ remain for future structural cleanup stages |
| Container-side path changes | /opt/sandbox/lib/ paths unchanged; Dockerfile COPY source paths updated this session |

## Next session

Sub-milestone: M2.7 — Session Identity and Harness Versioning

**Conclusions from this session:**
- The libs/ stage of the structural cleanup is complete. All 18 files in libs/ have been moved to their target directories per the design spec.
- Key splits: containers.sh (3 files), session.sh (2 files), draft_workflow.sh (3 files), diff.sh (2 files), checkpoint.sh dissolved
- Packaging pipeline is now symmetrical — all three packaging files deployed to both containers
- Context resolution convention applied: host-only libs use $AGENT_SANDBOX_REPO, cross-context libs use _self_dir, test files use $REPO_ROOT
- Verification: 330 tests pass, 0 fail, 7 skip

**Learning points — workflow amendments to formalise:**

1. **Rename propagation checklist** — Before renaming any file, grep every reference across the entire tree (`.sh`, `.yml`, `.md`, `Dockerfile`), categorise by whether it must change (source path, COPY path, test fixture, documentation, comment), and produce a propagation table. Change all references before `git mv`. This session missed mock_repo_fixtures.sh, Dockerfile COPY target names, and provider Dockerfiles on the first pass.

2. **File lifecycle gate** — New files that replace old ones must follow: create new → update all references → verify with `make test` → delete old → re-verify. Never batch-remove originals before the reference update pass is confirmed. The root-level `build/` gitignore issue is also a lifecycle problem: check `.gitignore` before creating files in a new directory.

3. **Convention-first design** — Naming convention (dashes vs underscores, directory layout, file extensions) must be frozen in the design doc before any implementation begins. The mid-session dash→underscore standardisation caused cascading renames and missed references that a pre-implementation decision would have avoided.

4. **Container-side path verification** — Every file sourced from `/opt/sandbox/lib/` inside a container must have a corresponding COPY line in the relevant Dockerfile. Currently untested. A test that diffs the set of sourced paths against the set of deployed paths would catch omissions like the missing `diff_export.sh` COPY target.

These four amendments are formalised as the rename/move workflow in `agent/drafts/refactor-mv-rename-file.skill.md`.
