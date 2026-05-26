# Design: Shared Library Organisation

**Date:** 2026-05-26
**Session:** `20260526-03-design-shared_library_organisation`
**Milestone:** M2.7 — Session Identity and Harness Versioning

---

## Principles

Files are grouped by a two-dimensional grid: **deployment target** (host / capability container / reasoning container) × **lifecycle stage** (build-time / runtime).

- **build/** — files only relevant to the build step (never deployed to containers)
- **libs/shared/** — deployed to both capability and reasoning containers
- **libs/capability/** — deployed only to the capability container
- **libs/reasoning/** — deployed only to the reasoning container
- **libs/host/** — sourced exclusively by host-side scripts (`scripts/*.sh`)

Within each directory, files are grouped by responsibility boundary, not by caller.

---

## Current State — Pain Points

### containers.sh (10 functions, 264 lines) — 4 responsibilities interleaved

| Responsibility | Functions | Clean extraction? |
|---|---|---|
| Image naming | `agent_base_image_name`, `agent_image_name`, `sandbox_image_name` | ✅ Pure functions, zero deps |
| Build context prep | `_build_context_copy`, `build_context_sandbox`, `build_context_agent` | ✅ Self-contained file ops |
| Build execution | `build_image`, `build_agent`, `build_sandbox` | ⚠️ Call naming + context — tightly coupled |
| Preflight | `preflight` | ✅ Standalone |


### session.sh (4 functions, 103 lines) — two responsibilities

| Functions | Concern | Proposed home |
|---|---|---|
| `validate_project_dir`, `draft_clear_stale_lock` | **Git workflow guards** — validate repo usability, clear stale locks. Always called as an adjacent pair (4 call sites: apply_run, draft_run, confirm_run, reject_run). | `libs/host/guards.sh` |
| `session_state_read`, `session_state_write` | **K/V metadata store** — reads/writes SESSION_STATE file (init_sha, session_ts, workspace paths). Written inside capability container, read from both containers + host. | `libs/shared/session-state.sh` |


### Deployment lapse — packaging pipeline asymmetry

Current deployment of packaging files:

| File | Capability container | Reasoning container |
|---|---|---|
| `diff.sh` | ✅ (sandbox.Dockerfile #27) | 🟡 in build context but NOT COPY'd |
| `package_branch.sh` | ✅ (sandbox.Dockerfile #30) | 🟡 in build context but NOT COPY'd |
| `package_diff.sh` | 🟡 not in sandbox.Dockerfile | ✅ (provider.Dockerfile #12) |

**Fix:** All three should be deployed to BOTH containers (symmetrical packaging pipeline).


### draft_workflow.sh (11 functions, 509 lines) — three workflows in one file

| Workflow | Functions | Lines | Proposed file |
|---|---|---|---|
| Draft | `draft_resolve_latest_export`, `draft_parse_folder_name`, `draft_read_export_time`, `draft_guard_no_collision`, `draft_write_state`, `draft_read_state_from_branch`, `draft_validate_branch`, `draft_resolve_commit_message`, `draft_run` | ~350 | `libs/host/workflows/draft.sh` |
| Confirm | `confirm_run` | ~70 | `libs/host/workflows/confirm.sh` |
| Reject | `reject_run` | ~60 | `libs/host/workflows/reject.sh` |

---

## Proposed Structure

```
build/                                    # Build-time only (host side)
  image.sh                                # Image naming: agent_base_image_name,
                                          #   agent_image_name, sandbox_image_name
                                          #   (extracted from containers.sh)
  context.sh                              # Build context prep: _build_context_copy,
                                          #   build_context_sandbox, build_context_agent
                                          #   (extracted from containers.sh)
  compose.sh                              # Compose file generation (was libs/compose.sh)


libs/
  shared/                                 # Deployed to BOTH containers
    session-state.sh                      # K/V store: session_state_read + session_state_write
                                          #   (extracted from session.sh)
    routing.sh                            # Path layout conventions (unchanged)
    dirs.sh                               # Path resolution (unchanged)
    diff.sh                               # Diff utilities (unchanged — but now deployed
                                          #   to reasoning container too: fixed lapse)
    diff-export.sh                        # diff_export orchestrator (extracted from diff.sh)
    package-branch.sh                     # Branch packaging (unchanged — deployed to
                                          #   both containers: fixed lapse)
    package-diff.sh                       # Diff packaging (unchanged — deployed to
                                          #   both containers: fixed lapse)

  capability/                             # Capability container only
    entrypoint.sh                         # sandbox-entrypoint.sh (unchanged)
    snapshot.sh                           # Snapshot pipeline (unchanged)

  reasoning/                              # Reasoning container only
    entrypoint.sh                         # provider-entrypoint.sh (unchanged)

  host/                                   # Host-side only (scripts/*.sh source these)
    guards.sh                             # Git workflow guards: validate_project_dir,
                                          #   draft_clear_stale_lock
                                          #   (extracted from session.sh)

    build.sh                              # Build orchestration: build_image, build_agent,
                                          #   build_sandbox, preflight
                                          #   (remainder of containers.sh after extraction)

    workflows/
      draft.sh                            # draft_run + helpers
      confirm.sh                          # confirm_run
      reject.sh                           # reject_run
      apply.sh                            # apply_run (was libs/diff_workflow.sh)
      interactive.sh                      # Session pickers (was libs/interactive_session_select.sh)


scripts/                                  # Host entry points (unchanged — path references updated
                                          #   to point to new libs/host/ locations)
```

---

## File-by-file mapping

| Current file | New path | Change |
|---|---|---|
| `libs/containers.sh` | → split across `build/image.sh` + `build/context.sh` + `libs/host/build.sh` | Pure extraction — no logic change |
| `libs/compose.sh` | → `build/compose.sh` | Move (unchanged content) |
| `libs/session.sh` | → split across `libs/shared/session-state.sh` + `libs/host/guards.sh` | Pure extraction |
| `libs/diff.sh` | → split across `libs/shared/diff.sh` + `libs/shared/diff-export.sh` | Extract orchestrator from utilities |
| `libs/diff_workflow.sh` | → `libs/host/workflows/apply.sh` | Rename + move |
| `libs/draft_workflow.sh` | → split across `libs/host/workflows/draft.sh`, `confirm.sh`, `reject.sh` | Split by workflow stage |
| `libs/interactive_session_select.sh` | → `libs/host/workflows/interactive.sh` | Rename + move |
| `libs/sandbox-entrypoint.sh` | → `libs/capability/entrypoint.sh` | Rename + move |
| `libs/snapshot.sh` | → `libs/capability/snapshot.sh` | Move |
| `libs/provider-entrypoint.sh` | → `libs/reasoning/entrypoint.sh` | Rename + move |
| `libs/package_branch.sh` | → `libs/shared/package-branch.sh` | Move + rename (dash convention) |
| `libs/package_diff.sh` | → `libs/shared/package-diff.sh` | Move + rename (dash convention) |
| `libs/dirs.sh` | → `libs/shared/dirs.sh` | Move |
| `libs/routing.sh` | → `libs/shared/routing.sh` | Move |
| `libs/sandbox.Dockerfile` | → `libs/capability/container.Dockerfile` | Rename |
| `libs/_templates/` | → `libs/host/templates/` | Move |
| `libs/docker-compose.yml` | → `build/docker-compose.yml` | Move |
| `libs/docker-compose.dry-run.yml` | → `build/docker-compose.dry-run.yml` | Move |

---

## Deployment matrix (after)

| File | Host | Capability | Reasoning | Lifecycle |
|---|---|---|---|---|
| `build/image.sh` | ✅ sourced | ❌ | ❌ | Build |
| `build/context.sh` | ✅ sourced | ❌ | ❌ | Build |
| `build/compose.sh` | ✅ sourced | ❌ | ❌ | Build |
| `libs/host/build.sh` | ✅ sourced | ❌ | ❌ | Host runtime |
| `libs/host/guards.sh` | ✅ sourced | ❌ | ❌ | Host runtime |
| `libs/host/workflows/*` | ✅ sourced | ❌ | ❌ | Host runtime |
| `libs/shared/session-state.sh` | ✅ sourced | ✅ deployed | ✅ deployed | Runtime |
| `libs/shared/routing.sh` | ✅ sourced | ✅ deployed | ✅ deployed | Runtime |
| `libs/shared/dirs.sh` | ✅ sourced | ✅ deployed | ✅ deployed | Runtime |
| `libs/shared/diff.sh` | ✅ sourced | ✅ deployed | ✅ deployed | Runtime |
| `libs/shared/diff-export.sh` | ✅ sourced | ✅ deployed | ✅ deployed | Runtime |
| `libs/shared/package-branch.sh` | ✅ sourced | ✅ deployed | ✅ deployed | Runtime |
| `libs/shared/package-diff.sh` | ✅ sourced | ✅ deployed | ✅ deployed | Runtime |
| `libs/capability/entrypoint.sh` | ❌ | ✅ deployed | ❌ | Runtime |
| `libs/capability/snapshot.sh` | ❌ | ✅ deployed | ❌ | Runtime |
| `libs/reasoning/entrypoint.sh` | ❌ | ❌ | ✅ deployed | Runtime |

---

## Key decisions

1. **Packaging pipeline is symmetrical** — `diff.sh`, `package-branch.sh`, `package-diff.sh` all deployed to both containers. The build context for both containers includes all three; both Dockerfiles COPY all three.

2. **`session-state.sh` separated from `routing.sh`** — K/V metadata store is a different concern from path layout conventions. They're orthogonal.

3. **`draft_workflow.sh` split into three files** — draft / confirm / reject each get their own file under `libs/host/workflows/`.

4. **`containers.sh` split into three files** — naming → `build/image.sh`, context → `build/context.sh`, build orchestration → `libs/host/build.sh`.

5. **Dash convention** for multi-word filenames — `package-branch.sh` not `package_branch.sh`, `diff-export.sh` not `diff_export.sh`. Consistent with existing `docker-compose.yml`.

6. **Entrypoints renamed** — `sandbox-entrypoint.sh` → `entrypoint.sh` under `capability/`, `provider-entrypoint.sh` → `entrypoint.sh` under `reasoning/`. The directory is sufficient disambiguation.

---

## Open questions

- **`build.sh` vs splitting further** — `libs/host/build.sh` would contain `build_image`, `build_agent`, `build_sandbox`, `preflight`. That's 4 functions, ~120 lines. Clean enough, or split `build_image` into `build/execute.sh`?
- **Test files** — test paths reference `../libs/` for sourcing. These would need updating. Should test fixtures remain in `tests/libs/` or follow the same organisation?
- **Transition ordering** — file moves must update all `source` paths in scripts/ and libs/, plus build context COPY paths in containers.sh. Should this be done in a single commit to avoid broken intermediate states?
