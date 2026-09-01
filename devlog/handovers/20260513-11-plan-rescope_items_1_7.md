# Agent Handover

**Date:** 2026-05-13
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Planning
**Status:** Active

## Objective

Rescope M2.7 items 1–7 based on the changes made in items 8–12, identify stale/superseded tasks, and determine the implementation order with dependency analysis.

## Investigation results

Each item was audited against the current codebase state after items 8–12 were implemented. Key findings:

### Item 1 — run_id derivation
**Verdict: Still relevant.**
- `SESSION_TS`, `REPO_COMMIT`, `WORKTREE_ID` are all already exported in `scripts/start_agent.sh` (lines 186, 191, 197).
- Container naming still uses `SESSION_TS` directly: `sandbox-${PROJECT_NAME}-${SESSION_TS}`.
- Change: add `RUN_ID` derivation and switch container names to use it.
- **No dependency on other items.** Can be done independently.

### Item 2 — Docker labels
**Verdict: Still relevant.**
- Compose template already has `x-session-labels` anchor with `project-dir`, `session-ts`, `host-branch`.
- Need to add `project`, `worktree-id`, `run-id`.
- **Depends on:** item 1 (run_id must exist before you can label it).
- **Prerequisite for:** item 3 (stop.sh needs worktree-id label to filter).

### Item 3 — make stop redesign
**Verdict: Still relevant.**
- `stop.sh` currently filters containers by Docker Compose project label.
- Redesign to filter by `project + worktree-id` labels enables parallel sessions from different worktrees.
- `stop.sh` implementation is unchanged by recent refactors.
- **Depends on:** item 2 (labels must exist on containers before stop.sh can filter by them).

### Item 4 — make prune implementation
**Verdict: Still relevant, minor path reference update needed.**
- Scope: `make prune` target for build cache, layer cache, system cache, volume cache cleanup.
- The original description mentions workspace temp directories — with item 10's `x-workspace` anchor, those paths are now documented in one place.
- The prune implementation should reference `x-workspace` anchor paths rather than hardcoding `.workspace/session-diffs`.
- **No hard dependency on other items.** But logically follows item 3 (stop/cleanup lifecycle).

### Item 5 — Two-sig model
**Verdict: Needs design refresh before implementation.**
- Original design based on hashing `libs/` + `build_context` directory to detect stale images.
- Item 10 removed `dirs.sh` from production paths and unified path definitions in the `x-workspace` anchor.
- Container-sig (stale image detection) is still valuable. Harness-sig (runtime drift detection) — the compose template is now the authority, so it would hash the template itself.
- The build context functions that container-sig was designed to replace still exist (item 7).
- **Depends on:** item 7 (context_dir removal is a prerequisite — can't have two sources of truth for file staging).
- **Needs a design refresh session before implementation.**

### Item 6 — Paired refactor (move compose files into providers/)
**Verdict: Superseded by item 10.**
- Original rationale: "move compose files into providers/ so the harness-sig hash boundary matches the folder boundary."
- Item 10's `x-workspace` anchor achieved the same architectural goal (single authority for paths) via a different mechanism.
- The `agents.md not COPY-ed` prerequisite check confirmed clean (0 references in any provider Dockerfile).
- Compose template + provider overlay pattern is the right architecture and is already in place.
- **Recommendation: Mark as superseded, remove from task list.**

### Item 7 — Context_dir removal
**Verdict: Still relevant, independent.**
- `build_context_sandbox`, `build_context_agent`, `_build_context_copy` still present in `libs/containers.sh` (25 occurrences).
- `tests/test_build_context.sh` still has ~388 lines / ~47 tests testing context_dir population.
- The stale digest pipeline (`agent-sandbox.digest` Docker label, baked by `build_image()` but never read) is still being written.
- `build_container.sh` was already deleted in M2.3 — but the code comment at item 7 still references it (line ~70 comment).
- `package_branch.sh` drift still present: `sandbox.Dockerfile` COPYs it, but `build_context_sandbox()` doesn't stage it.
- **Prerequisite for:** item 5 (container-sig replaces the digest pipeline that context_dir feeds).
- **No dependency on items 1–4.** Can be done independently.

### Updated dependency graph

```
item 1 (run_id) ──→ item 2 (labels) ──→ item 3 (stop redesign)
                                              │
                                              └──→ item 4 (prune)

item 7 (context_dir) ──→ item 5 (two-sig) [needs design refresh]

item 6 (paired refactor) → SUPERSEDED
```

Items 7 and 1 are independent of each other and could be done in parallel or in either order.

## Scope

- Mark item 6 as superseded (remove from task list, note in changelog or keep as historical record with `[SUPERSEDED]` marker).
- Add a note that item 5 needs a design refresh before implementation.
- Confirm the implementation order.
- Do NOT implement any of items 1–7 in this session.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Item 6 marked as superseded in roadmap | ✅ |
| 2 | Item 5 noted as needing design refresh | ✅ |
| 3 | Dependency graph documented | ✅ |
| 4 | Implementation order confirmed | ✅ |
| 5 | Planning handover created | ✅ |

## Hot files

| File | Why in scope |
|---|---|
| `docs/devlog/roadmap.md` | Rescope items 1–7 |
| `libs/containers.sh` | Audited for context_dir functions (item 7) |
| `libs/docker-compose.yml` | Audited for labels (item 2) and path anchor (item 6 supersession) |
| `scripts/start_agent.sh` | Audited for run_id primitives (item 1) |
| `scripts/stop.sh` | Audited for current filter mechanism (item 3) |
| `tests/test_build_context.sh` | Audited for context_dir test count (item 7) |
| `devlog/discussions/design_session_identity_hash_based.md` | Original design for items 1–5 |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Item 6 marked superseded | x-workspace anchor achieved same goal via different mechanism | roadmap.md |
| Item 5 needs design refresh | Item 10 changed the foundation (no more dirs.sh, x-workspace is authority) | roadmap.md |
| Implementation order: 1→2→3→4, 7 (parallel), 5 (after 7 + design refresh) | Dependencies: labels need run_id, stop needs labels, two-sig needs context_dir removal first | This handover |

## Mid-session findings

None.

## Completed this session

| File | Change |
|---|---|
| `docs/devlog/roadmap.md` | Items 1–7 rescoped with track structure, dependencies, and implementation order. Item 6 superseded. Item 5 noted needs design refresh. Container-sig design added. |
| `docs/devlog/handovers/20260513-11-plan-rescope_items_1_7.md` | **New** — this handover |

## Deferred items

| Item | Reason |
|---|---|
| Item 5 (two-sig) design refresh | Requires separate design session before implementation — see handover 12 for ongoing investigation |

## Next session

Item 1 (run_id derivation) is the natural starting point — no dependencies, all primitives already exist.

### Final plan summary

**Track A — Container Identity & Lifecycle:** 1 (run_id) → 2 (labels) → 3 (stop) → 4 (prune)
**Track B — Build Pipeline:** 7 (context_dir removal, 2 sessions) → 5 container-sig implementation

**Container-sig design:** settled in separate session (see handover 12). Hashes `/opt/sandbox/` + `/opt/workflow/` at build time, baked as Docker label, checked at preflight with warning (not a block).

**Harness-sig:** deferred — investigation in progress (handover 12).

Key decisions from grilling:
- Context_dir removal uses repo root as build context directly (no `.dockerignore` whitelist). ~3MB extra context size is acceptable. No runtime access risk — un-COPIED files don't enter the image. `build_image()` and `build_context_*` functions removed; `build_sandbox`/`build_agent` kept as named functions.
- Labels include `project-name`, `worktree-id`, `run-id` plus backwards-compatible `session-ts`, `host-branch`, `project-dir`.
- `worktree_id_derive` moves from `scripts/checkpoint.sh` to `libs/containers.sh` for shared access by start_agent.sh and stop.sh.
