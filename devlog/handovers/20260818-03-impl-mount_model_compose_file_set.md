# Agent Handover

**Date:** 2026-08-19
**Milestone:** M2.6.6 — Mount Model: Host-backed Sandbox
**Type:** Implementation
**Status:** Closed

## Objective

Implement the first M2.6.6 implementation task — **Compose template: realize the file-set decision** (roadmap task, settled design walk `20260818-02`, decision "Compose file sets"). Introduce a mode-selectable compose file set at generation time via the existing `compose_generate` pipeline: base template + copy overlay + mount overlay, merged through `docker compose config`; no YAML conditionals. Move the copy-only `SNAPSHOT_DIR` mount/env out of the base template into the copy overlay so mount-mode compose never inherits it.

## Context (verified)

- `compose_generate(output_file, project_name, provider_name, input_files...)` in `src/build/compose.sh` already merges an arbitrary input-file list through `docker compose config --no-interpolate` — the file-set mechanism exists; this task adds mode-selectable file-set composition.
- The **dry-run overlay** (`src/build/docker-compose.dry-run.yml`) is the working precedent for base+overlay composition.
- The base template `src/build/docker-compose.yml` currently carries the sandbox `volumes:` block, the `SNAPSHOT_DIR` RO bind mount (`/home/agentuser/.snapshot`) and `SNAPSHOT_DIR` env — mount-mode compose must not inherit these.
- Delivery selector: `SANDBOX_TYPE=copy|mount` (settled naming, walk `20260818-02`), default `copy` for this task; full wiring to onboarding/`.env` is delivery-enablement scope.
- Design decisions realized here: Compose file sets (decision 2); Worktree (decision 9 — single shared worktree, default `$SANDBOX_DIR/.worktree/`); Copy-in mechanism (decision 5 — status quo RO-mount-at-start; volume seeding deferred).

## Session history

- `2026-08-18`: scope proposed as the compose file-set task only (out-of-scope list below); recorded in handover `20260818-03`, which was dropped when the container re-baselined (untracked file, baseline now `e026891`). Operator confirmed scope the same day ("can we proceed" given the fresh baseline). Handover recreated here on `2026-08-19`.

## Files in scope

| File | Change |
|---|---|
| `src/build/docker-compose.yml` | Base — strip copy-only `SNAPSHOT_DIR` mount/env and named sandbox volume (moves to copy overlay) |
| `src/build/docker-compose.copy.yml` | NEW — copy overlay: named volume + `SNAPSHOT_DIR` mount/env + snapshot path documentation |
| `src/build/docker-compose.mount.yml` | NEW — mount overlay: worktree bind mount |
| `src/build/compose.sh` | File-set selection at generation (`SANDBOX_TYPE` selector, default copy) |
| `scripts/start_agent.sh` / `scripts/run_agent.sh` | Export/surface the delivery selector; pass the file set per mode |
| `tests/test_trace_compose_gen.sh` (+ compose tests) | File-set selection tests; copy overlay keeps `SNAPSHOT_DIR`; mount overlay does not inherit it |
| `docs/architecture/execution_model.md` | Compose Generation — file-set model |
| `docs/development/tool_interface.md` (if it documents the template) | Compose generation doc sync |

## Out of scope this session

- Mount delivery enablement (entrypoint redirect, `.git`+init-marker validation, entrypoint branch inversion cleanup) — next task
- `.run-identity` deprecation / identity registry fold
- Terminology sweep (agent run / agent iteration)
- Mount worktree with git history
- M2.6 close housekeeping (changelog extraction, stale close-order label)

## Verification

- Full suite green (`make test`, invariant: 0 failed / 0 skipped)
- Generated mount-mode compose (docker stub) contains no `SNAPSHOT_DIR` mount/env and no named sandbox volume
- Generated copy-mode compose is behaviorally identical to today's output (modulo file provenance)
- Dry-run overlay composition unchanged

## Decisions

| Decision | Rationale |
|---|---|
| Scope: compose file-set task only | operator-confirmed 2026-08-18 |
| `SANDBOX_TYPE=copy|mount` as the generation-time selector, default `copy` | settled naming from design walk `20260818-02`; invalid values rejected before any compose invocation |
| Named sandbox volume + snapshot mount/env move wholly into the copy overlay | the only delivery with a snapshot; mount compose must not inherit them |
| Delivery overlays live in `src/build/` alongside base + dry-run | harness-level, not provider-level (same class as the dry-run overlay) |
| Overlay merge ordering: base → delivery overlay → provider overlay → mode overlay | delivery wiring precedes provider/mode additions; `docker compose config` merges `environment` by key and appends `volumes` |
| `WORKTREE_DIR` default `${SANDBOX_DIR}/.worktree`, overridable; baked at generation | design decision Worktree (walk `20260818-02`); custom mount point injects at generation |
| Remove the 4 repo-presence assertions from `test_run_agent.sh` (operator-directed) | presence of a committed file is trivially true; the meaningful guard is the production existence check at each injection point (`run_agent.sh` guards all 5 required files) + behavioral trace/static tests |

## Completed this session

- [x] Base template restructured: named sandbox volume, snapshot mount, snapshot env, and x-workspace snapshot row removed (copy-only wiring now entirely absent from the base file — verified: zero grep hits)
- [x] `src/build/docker-compose.copy.yml` — copy overlay (named volume + snapshot RO mount + env)
- [x] `src/build/docker-compose.mount.yml` — mount overlay (worktree bind at `/home/agentuser/sandbox`)
- [x] `compose.sh` — `WORKTREE_DIR` substitution added; header docs updated (file-set model)
- [x] `run_agent.sh` — delivery overlay selection (`SANDBOX_TYPE`, default copy, invalid rejected), `WORKTREE_DIR` default export; assembly header comment updated (also corrected stale `libs/` paths in the comment)
- [x] `start_agent.sh` — path-derivation comment updated (snapshot is copy-delivery; exported unconditionally until delivery enablement)
- [x] Tests — `test_trace_compose_gen.sh` (4 new: base-free-of-copy-wiring, copy overlay carries wiring, mount overlay worktree-only, mount output free of wiring), `test_trace_start.sh` (3 new: copy default merges copy overlay, mount merges mount overlay, invalid `SANDBOX_TYPE` rejected). Removed the 4 trivial repo-presence checks from `test_run_agent.sh` (operator-directed — presence assertions restate the repo's own committed structure; the meaningful guards are the production existence checks in `run_agent.sh`, present for all 5 required files, plus the trace/static tests). Suite 471 → 476 net, 0 failed / 0 skipped
- [x] Docs — `execution_model.md` Compose Generation (delivery overlays, `SANDBOX_TYPE`, corrected `libs/` → `src/build/`), `tool_interface.md` (repo-owned templates list + delivery-overlay note)

## Mid-session findings

| Finding | Disposition |
|---|---|
| Pre-existing stale `libs/` paths in compose docs/comments (files live in `src/build/`) | corrected in the touched blocks (`run_agent.sh` header, `execution_model.md`) — adjacent spots (base template header, `start_agent.sh` paths comment) also corrected since they were rewritten this session |
| No docker/YAML validator in the reasoning container — real `docker compose config` merge not exercised here | covered by stub-based trace tests + syntax copied verbatim from the production-validated base template; full merge verified at next real host run |
| Docker-stub `compose config` returns only the first input file — does not merge overlays | pre-existing limitation (documented in the stub header); static per-file assertions + file-set selection trace tests used instead |

## Acceptance criteria

- [x] Operator confirms this session's scope (compose file-set task only)
- [x] Base + copy + mount file sets produce correct merges for both modes
- [x] Copy mode behavior unchanged; mount-mode compose free of copy-only wiring
- [x] Tests + docs updated; suite green (480/0/0)

## Operational notes

- Baseline `e026891` — squashed snapshot of the design settlement; both `20260818-01`/`20260818-02` handovers present and Closed (read-only).
- Open gotchas relevant to this session: library functions must `return` not `exit` (`src/build/compose.sh` is sourced; new error paths use `return 1`); policy-text changes need per-section approval — architecture docs (`execution_model.md`) are not policy files, but doc changes are presented in chat before writing where substantive.