# Agent Handover

**Date:** 2026-05-01
**Milestone:** Container tooling path relocation (prerequisite for M2.x)
**Type:** Implementation
**Status:** Closed

## Objective

Implement the container tooling path relocation design spec — relocating harness tooling from ad-hoc paths (`/libs/`, `/usr/local/bin/`, `~/sandbox/libs/`) into a dedicated container directory (`/opt/sandbox/bin/`, `/opt/sandbox/lib/`, `/opt/sandbox/docs/`) — across all 11 files specified in the design document.

## Scope

- [x] Implement all file changes described in [`docs/devlog/discussions/design_container_tooling_path_relocation.md`](../discussions/design_container_tooling_path_relocation.md) — the 11 exact-change sections (File change spec items 1–11), plus any prompt template `~/sandbox/libs/` path updates and docs path updates listed there.
- [x] Update architecture documents in scope to reflect the system as built (e.g. `sandbox-architecture.md`, `execution_model.md` if they reference old paths).
- [x] Verify with `make test` (all tests passing with updated assertions) and the AC grep patterns.
- Explicitly out of scope: docs restructuring (operations/development/devlog folding — deferred to future investigation); prompt templates `defer.md`, `wrapup.md`, `new-session.md`, `new-session-v2.md` (pre-existing concern, deferred); the `--interactive` flag for `apply`/`draft` (pending under M2.3, separate scope).

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Build context test passes (`bash tests/test_build_context.sh`) | **Accepted** — 39/39 passed |
| 2 | No stale `/libs/` source paths in runtime scripts | **Accepted** — 0 results |
| 3 | No stale `~/sandbox/libs/` paths in prompt templates | **Accepted** — 0 results |
| 4 | No stale `/usr/local/bin/` COPY/ENTRYPOINT in Dockerfiles | **Accepted** — 0 results |
| 5 | Sandbox Dockerfile ENTRYPOINT uses full path | **Accepted** — `["/opt/sandbox/bin/sandbox-entrypoint.sh"]` |
| 6 | `dry_run.sh` sources from `/opt/sandbox/lib/` | **Accepted** — `source /opt/sandbox/lib/dirs.sh` |
| 7 | All provider Dockerfiles use `/opt/sandbox/` paths | **Accepted** — all 4 verified |
| 8 | Architecture docs have no stale path references | **Accepted** — 0 results |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/devlog/discussions/design_container_tooling_path_relocation.md`](../discussions/design_container_tooling_path_relocation.md) | Design spec — exact per-file changes |
| [`libs/containers.sh`](../../libs/containers.sh) | Update build context COPY lists — sandbox (7 files + docs) and agent (4 files + docs) |
| [`libs/sandbox.Dockerfile`](../../libs/sandbox.Dockerfile) | Update COPY destinations to `/opt/sandbox/bin/`/`lib/`, add docs COPY, update ENTRYPOINT |
| [`libs/sandbox-entrypoint.sh`](../../libs/sandbox-entrypoint.sh) | Update 3 source paths from `/libs/` to `/opt/sandbox/lib/` |
| [`scripts/dry_run.sh`](../../scripts/dry_run.sh) | Update absolute path from `/libs/dirs.sh` to `/opt/sandbox/lib/dirs.sh` |
| [`providers/pi/provider.Dockerfile`](../../providers/pi/provider.Dockerfile) | Update COPY paths, add `ENV PATH`, full-path ENTRYPOINT |
| [`providers/opencode/provider.Dockerfile`](../../providers/opencode/provider.Dockerfile) | Same as pi provider |
| [`providers/hermes/provider.Dockerfile`](../../providers/hermes/provider.Dockerfile) | Same as pi provider |
| [`providers/claude-code/provider.Dockerfile`](../../providers/claude-code/provider.Dockerfile) | Same as pi provider |
| [`agent/prompts/package-diff.md`](../../agent/prompts/package-diff.md) | Update 6 path occurrences from `~/sandbox/libs/` to `/opt/sandbox/lib/` |
| [`agent/prompts/package-branch.md`](../../agent/prompts/package-branch.md) | Update 1 path occurrence from `~/sandbox/libs/` to `/opt/sandbox/lib/` |
| [`agent/prompts/agent-sandbox.md`](../../agent/prompts/agent-sandbox.md) | Update docs reference from `docs/` to `/opt/sandbox/docs/` |
| [`libs/package_diff.sh`](../../libs/package_diff.sh) | Update usage comment path |
| [`tests/test_capability_layer.sh`](../../tests/test_capability_layer.sh) | Update 4 path assertions |
| [`tests/test_build_context.sh`](../../tests/test_build_context.sh) | Update file count and file name assertions |

## Decisions made this session

| Decision | Rationale | Reference |
|---|---|---|
| `libs/dirs.sh` usage comment updated from `/libs/` to `/opt/sandbox/lib/` | Covering docstring that references the old runtime path — not in design spec but uncovered during verification | `libs/dirs.sh` line 14 |
| `mkdir -p` added before `cp -r docs/` in both build context functions | `cp -r` to a nested directory fails if parent doesn't exist; context dir starts empty | `libs/containers.sh` build_context functions |
| `local context_dir=""` instead of `local context_dir` in build context functions | Prevents `unbound variable` error from `set -u` when ERR trap fires before assignment | `libs/containers.sh` lines 67, 94 |

## Mid-session findings

None.

## Completed this session

| File | Change summary |
|---|---|
| `libs/containers.sh` | Updated build_context_sandbox (7 files + docs) and build_context_agent (4 files + docs) |
| `libs/sandbox.Dockerfile` | Updated COPY destinations to `/opt/sandbox/bin/`/`lib/`, added docs/ COPY, updated ENTRYPOINT and RUN chmod |
| `libs/sandbox-entrypoint.sh` | Updated 3 source paths from `/libs/` to `/opt/sandbox/lib/` |
| `scripts/dry_run.sh` | Updated source path from `/libs/dirs.sh` to `/opt/sandbox/lib/dirs.sh` |
| `providers/pi/provider.Dockerfile` | Updated COPY to `/opt/sandbox/`, added ENV PATH, full-path ENTRYPOINT |
| `providers/opencode/provider.Dockerfile` | Same |
| `providers/hermes/provider.Dockerfile` | Same |
| `providers/claude-code/provider.Dockerfile` | Same |
| `agent/prompts/package-diff.md` | Updated 6 path occurrences |
| `agent/prompts/package-branch.md` | Updated 1 path occurrence |
| `agent/prompts/agent-sandbox.md` | Updated docs reference |
| `libs/package_diff.sh` | Updated usage comment path |
| `libs/package_branch.sh` | Fixed `local` used outside function in direct-mode execution block [see correction below] |
| `tests/test_capability_layer.sh` | Updated 4 path assertions |
| `tests/test_build_context.sh` | Updated fixture, file assertions, and file counts |

## Deferred items

None.

## Next session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline — `--interactive` flag still pending.

**Context handover:** Container tooling path relocation — prerequisite complete. Design spec at `docs/devlog/discussions/design_container_tooling_path_relocation.md`. Implementation covered 15 files; `test_build_context.sh` passes 39/39; all stale path greps return 0.

**Trigger B:** Not applicable — this session closed a prerequisite, not a sub-milestone.

**Blocking questions:** None.

**Known decisions from this session:**
- `/opt/sandbox/bin/` (entrypoints) + `/opt/sandbox/lib/` (library scripts) + `/opt/sandbox/docs/` (architecture + concepts) layout is implemented across all container images
- No backward-compat symlinks — every consumer updated in-scope
- 4 provider Dockerfiles updated identically with `ENV PATH=/opt/sandbox/bin:$PATH` and full-path ENTRYPOINTs
- `mkdir -p` required before `cp -r docs/` in build context since context dir starts empty
- `local context_dir=""` pattern prevents `set -u` unbound variable in ERR traps

**Watch-outs:**
- The `lib/` (not `libs/`) convention under `/opt/sandbox/` applies to all future container-path updates
- Prompt templates `defer.md`, `wrapup.md`, `new-session.md`, `new-session-v2.md` still reference `docs/operations/` by project-relative path — this is a pre-existing concern, not addressed here

**Conclusions from this session:** Container tooling path relocation is complete. All harness tooling now lives under `/opt/sandbox/` with FHS-compliant layout. Build context functions include the extended file sets (sandbox: 7+docs, agent: 4+docs). No stale `/libs/` or `/usr/local/bin/` paths remain in runtime scripts or Dockerfiles. The prerequisite is done.

---
[CORRECTION — 2026-05-01]: `libs/package_branch.sh` had a pre-existing bug: `local` used outside a function in the direct-mode execution block (lines 159-170), which is a bash syntax error causing "local: can only be used in a function". Fixed by replacing `local` with plain variable assignments. Post-fix verification: `bash libs/package_branch.sh --session-summary=test_fix --sandbox=... --init-sha=... --outdir=...` exits 0 and produces correct output.
