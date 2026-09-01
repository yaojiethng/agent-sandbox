# Agent Handover

**Date:** 2026-06-11
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Implementation
**Status:** Closed

## Objective

Implement the build context simplification spec — replace temp-dir assembly (`build_context_*`, `build_image`) with repo-root Docker build context using subdirectory-level COPY instructions in all Dockerfiles.

## Scope (in execution order)

1. **Add new logic** — Update `scripts/build.sh`: add a `repo_root` variable and direct `docker build` path in `build_agent()` and `build_sandbox()` *alongside* the existing temp-dir path (old path still active)
2. **Update all 4 Dockerfiles** with repo-relative COPY paths:
   - `src/capability/dockerfile` (sandbox)
   - `src/reasoning/providers/pi/provider.dockerfile`
   - `src/reasoning/providers/hermes/provider.dockerfile`
   - `src/reasoning/providers/opencode/provider.dockerfile`
3. **Write COPY contract tests** — rewrite `tests/test_build_context.sh` (~496 lines → ~30 lines) asserting every COPY source exists at its repo-relative path
4. **Route to new logic** — change `build_agent()` and `build_sandbox()` to use `$repo_root` as build context, remove temp-dir context calls
5. **Delete old logic** — remove `src/build/context.sh`, remove `build_image()`, `cleanup_build_context()`, `_BUILD_CONTEXT_DIRS` from `scripts/build.sh`
6. **Update docs** — fix `src/reasoning/entrypoint.sh` comment (line 168), fix `docs/architecture/execution_model.md` (line 207), mark roadmap complete

## Carried forward

| Item | From | Resolution |
|---|---|---|
| Implement spec at `devlog/discussions/spec_context_dir_removal.md` | `20260609-09-design-context_dir_removal.md` | Completed this session |

## Completed this session

| File | Change |
|---|---|
| `src/build/context.sh` | Deleted (~112 lines)
| `scripts/build.sh` | Replaced temp-dir build context with repo-root context; removed `build_image()`, `cleanup_build_context()`, `_BUILD_CONTEXT_DIRS` |
| `src/capability/dockerfile` | Rewrote COPY to repo-relative paths (`src/libs/`, `src/capability/entrypoint.sh`, `src/capability/snapshot.sh`, `docs/architecture/`, `docs/concepts/`) |
| `src/reasoning/providers/pi/provider.dockerfile` | Rewrote COPY to repo-relative paths (`src/libs/`, `src/reasoning/entrypoint.sh`, `providers/pi/preflight.sh`, `agent/skills/`, `agent/prompts/`, `providers/pi/config/`, docs) |
| `src/reasoning/providers/hermes/provider.dockerfile` | Rewrote COPY to repo-relative paths (libs, entrypoint, skills, prompts, docs) |
| `src/reasoning/providers/opencode/provider.dockerfile` | Rewrote COPY to repo-relative paths (libs, entrypoint, skills, prompts, docs) |
| `tests/test_build_context.sh` | Rewrote from ~496 lines of property-based assembly tests to ~30 lines of COPY contract tests |
| `src/reasoning/entrypoint.sh` | Updated doc comment referencing `build_context_agent` |
| `docs/architecture/execution_model.md` | Removed stale `agent-sandbox.digest` reference |
| `docs/architecture/provider_lifecycle.md` | Removed stale `build_context_agent` reference |
| `docs/architecture/tool_interface.md` | Removed stale `libs/containers.sh` reference |
| `docs/development/project_index.md` | Replaced `containers.sh` entry with `build.sh`; updated `test_build_context.sh` description |
| `docs/operations/provider_onboarding_guide.md` | Replaced 5 stale `containers.sh`/`build_context_agent` references + inline Dockerfile template example |
| `docs/operations/recovery_protocol.md` | Replaced stale `containers.sh` reference |
| `scripts/run_agent.sh` | Removed dead `source ... build/context.sh` |
| `scripts/start_agent.sh` | Removed dead `source ... build/context.sh` |
| `tests/libs/mock_repo_fixtures.sh` | Updated stale function description comment |
| `src/build/image.sh` | Updated stale comment |
| `devlog/roadmap.md` | Marked Context_dir removal complete with compaction note |

## Hot files

| File | Reason |
|---|---|
| `scripts/build.sh` | Add direct `$repo_root` context path alongside old temp-dir path; later switch to new path, then delete old functions |
| `src/capability/dockerfile` | Rewrite COPY instructions to repo-relative paths |
| `src/reasoning/providers/pi/provider.dockerfile` | Rewrite COPY instructions to repo-relative paths |
| `src/reasoning/providers/hermes/provider.dockerfile` | Rewrite COPY instructions to repo-relative paths |
| `src/reasoning/providers/opencode/provider.dockerfile` | Rewrite COPY instructions to repo-relative paths |
| `tests/test_build_context.sh` | Rewrite as COPY contract tests (~30 lines) |
| `scripts/build.sh` | Route to new logic (switch to `$repo_root`), then delete old functions |
| `src/build/context.sh` | Delete entire file (after nothing calls it) |
| `src/reasoning/entrypoint.sh` | Update doc comment referencing `build_context_agent` |
| `docs/architecture/execution_model.md` | Update `agent-sandbox.digest` reference |
| `devlog/roadmap.md` | Mark Context_dir removal complete |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | `src/build/context.sh` does not exist | `ls src/build/context.sh` returns non-zero | ✅ Accepted |
| 2 | `scripts/build.sh` does not source `context.sh` | `grep -c "source.*context.sh"` = 0 | ✅ Accepted |
| 3 | No `build_context_` refs in `scripts/build.sh` | `grep -c "build_context_"` = 0 | ✅ Accepted |
| 4 | `build_image()` uses `$repo_root`, no old digest label | grep shows `$repo_root` param | ✅ Accepted |
| 5 | No `agent-sandbox.digest` in scripts/ or src/ | `grep -rn` empty | ✅ Accepted |
| 6 | All 4 Dockerfiles use repo-relative COPY paths | manual review | ✅ Accepted |
| 7 | COPY contract tests pass | `bash test_build_context.sh` exits 0 | ✅ Accepted |
| 8 | No stale `agent-sandbox.digest` in `execution_model.md` | `grep -c` = 0 | ✅ Accepted |

## Propagation checklist

| File | Change | Status |
|---|---|---|
| `scripts/build.sh` | Add `$repo_root` context path alongside old temp-dir path | done |
| `src/capability/dockerfile` | Rewrite COPY to repo-relative paths | done |
| `src/reasoning/providers/pi/provider.dockerfile` | Rewrite COPY to repo-relative paths | done |
| `src/reasoning/providers/hermes/provider.dockerfile` | Rewrite COPY to repo-relative paths | done |
| `src/reasoning/providers/opencode/provider.dockerfile` | Rewrite COPY to repo-relative paths | done |
| `tests/test_build_context.sh` | Rewrite as COPY contract tests | done |
| `scripts/build.sh` | Route to new logic (switch to `$repo_root`) | done |
| `src/build/context.sh` | Delete entire file | done |
| `scripts/build.sh` | Remove old functions, comment references | done |
| `src/reasoning/entrypoint.sh` | Update doc comment | done |
| `docs/architecture/execution_model.md` | Update stale `agent-sandbox.digest` ref | done |
| `devlog/roadmap.md` | Mark Context_dir removal complete | done |

## Completed this session

*Not yet defined.*

## Mid-session findings

*None.*

## Decisions

*From design session (20260609-09):*

| Decision | Rationale | Recorded in |
|---|---|---|
| Subdirectory COPY with repo root as build context | Eliminates two-list drift; simpler than temp dir | `devlog/discussions/spec_context_dir_removal.md` |
| `src/libs/` as a whole subdirectory | Shared libs dir is clean enough (2 extra inert files) | spec |
| Single-file COPY for entrypoints/preflight | Files sit in dirs with unrelated content | spec |
| Defer two-sig model to next session | Need repo-root context first | This handover |

## Deferred items

*None.*

## Next session

Two-sig model: container-sig Docker label (hash of `/opt/sandbox/` + `/opt/workflow/`) + preflight check. Needs repo-root context from this session.

## Conclusions from this session

- Context_dir removal completed: all temp-dir assembly removed, repo-root build context with subdirectory COPY is the sole mechanism.
- Found and purged stale references to `build_context_*`, `context.sh`, and `containers.sh` across 6 docs, 2 scripts, 2 code files, and 1 test helper.
- Two out-of-scope stale references fixed (`containers.sh` never existed in this repo state).
- The two-sig model (container-sig label) is now unblocked — the repo-root Dockerfile context makes it straightforward to add `LABEL` instructions at Dockerfile level.
