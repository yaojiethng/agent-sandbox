# Agent Handover

**Date:** 2026-06-09
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Design
**Status:** Closed

## Objective

Design the approach for removing the temp-dir build context mechanism. Evaluate options — repo-root context, subdirectory COPY, or retaining simplified assembly — and produce a spec for implementation.

## Scope

1. Remove `src/build/context.sh` (contains `build_context_sandbox`, `build_context_agent`, `_build_context_copy`, `context_digest`).
2. Update `scripts/build.sh` to use repo root as build context for both sandbox and agent builds, instead of temp dirs.
3. Update all Dockerfiles to use repo-relative COPY paths instead of flat temp-dir paths.
4. Rewrite `tests/test_build_context.sh` as COPY contract tests — assert the files expected by each Dockerfile COPY instruction exist at the expected repo-relative path.
5. Remove `build_image` in favour of direct `docker build` call (the digest label it computed is for the temp-dir context, not the whole repo — the two-sig model will replace it with a proper container-sig label).

**Out of scope (deferred):**
- Two-sig model (container-sig label + preflight check) — next session after this.
- Harness-sig — deferred to future.
- Docker label removal/renaming beyond what's needed for `build_image` removal.

## Carried forward

*None — prior session was cleanly closed with all Track A items complete.*

## Hot files

| File | Reason |
|---|---|
| `src/build/context.sh` | Target for removal — contains build context assembly functions |
| `scripts/build.sh` | Must be updated to remove context.sh sourcing, use repo-root build context |
| `src/capability/dockerfile` | COPY paths reference flat temp-dir layout; must be repo-relative |
| `src/reasoning/providers/pi/provider.dockerfile` | Same — COPY paths from flat temp-dir |
| `tests/test_build_context.sh` | Rewrite as COPY contract tests |

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | `src/build/context.sh` is removed | `ls src/build/context.sh` returns non-zero | |
| 2 | `scripts/build.sh` no longer sources `context.sh` | `grep -c "source.*context.sh" scripts/build.sh` returns 0 | |
| 3 | Docker copies work with repo-root context: all COPY sources in `src/capability/dockerfile` exist at the repo-relative path | `tests/test_build_context.sh` (rewritten) passes | |
| 4 | Docker copies work with repo-root context: all COPY sources in `providers/pi/provider.dockerfile` exist at the repo-relative path | `tests/test_build_context.sh` (rewritten) passes | |
| 5 | `build_image` function is removed from `scripts/build.sh` | `grep -c "build_image" scripts/build.sh` returns 0 | |
| 6 | All old `build_context_*` test patterns removed; new COPY contract tests pass | `bash tests/test_build_context.sh` exits 0 | |

## Completed this session

| File | Change |
|---|---|
| `devlog/discussions/spec_context_dir_removal.md` | Created — spec document detailing subdirectory COPY approach with repo root as build context

## Mid-session findings

*None.*

## Decisions

| Decision | Rationale | Recorded in |
|---|---|---|
| Subdirectory COPY with repo root as build context | Eliminates two-list drift; simpler than temp dir; more precise than whole-repo context | `devlog/discussions/spec_context_dir_removal.md` |
| `src/libs/` as a whole subdirectory | Shared libs directory is clean enough (2 extra inert files); eliminates most common drift source | spec Dockerfile rewrites |
| Single-file COPY for entrypoints/preflight | Files sit in dirs with unrelated content (dockerfile, provider configs) | spec Dockerfile rewrites |
| Defer two-sig model to next session | Need repo-root context first to add container-sig label at Dockerfile level | This handover |

## Deferred items

*None.*

## Next session

**Context handover:** [`20260609-09-design-context_dir_removal.md`](20260609-09-design-context_dir_removal.md)

Implement the spec in `devlog/discussions/spec_context_dir_removal.md` — delete `src/build/context.sh`, update `scripts/build.sh` and all Dockerfiles to use repo-root context with subdirectory COPY, rewrite `tests/test_build_context.sh` as COPY contract tests.

Then: two-sig model (container-sig label + preflight check).

## Conclusions from this session

- **Rejected** whole-repo-root as build context (overkill, unnecessarily large context send to docker daemon)
- **Rejected** Dockerfile-parsing approach to auto-derive context (janky, introduces parser bugs)
- **Rejected** retaining context.sh assembly or inlining it into build.sh (doesn't solve the two-list drift problem)
- **Settled on:** subdirectory COPY with repo root as build context — `src/libs/` as a whole dir, individual files for entrypoints/preflight, split docs into architecture/ and concepts/
- Build context carries ~2 extra inert lib files + ~7 extra draft .md files — negligible cost
- Spec document written at `devlog/discussions/spec_context_dir_removal.md`

---

## Design (Step 3)

### Current architecture

The build pipeline currently:
1. `build_context_sandbox()` copies specific files from `src/capability/`, `src/libs/`, and `docs/` into a temp dir
2. `build_context_agent()` does the same for `src/reasoning/`, `src/libs/`, `src/reasoning/providers/<n>/`, `docs/`, and `agent/`
3. The Dockerfile COPY commands reference files flat in the temp dir context (e.g. `COPY entrypoint.sh /opt/sandbox/bin/`)
4. `build_image()` computes a content digest of the temp dir and labels the image

### Target architecture

1. All Dockerfiles use repo-root as build context
2. COPY commands reference repo-relative paths (e.g. `COPY src/capability/entrypoint.sh /opt/sandbox/bin/`)
3. No more `build_context_*` temp dir assembly
4. `build_image()` and `context_digest()` removed — `docker build` called directly
5. Container-sig (replacing the temp-dir digest label) moved to Dockerfile-level `LABEL` instruction (two-sig model, next session)
