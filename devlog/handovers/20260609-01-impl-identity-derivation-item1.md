# Agent Handover

**Date:** 2026-06-09
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Implementation
**Status:** Closed

## Objective

Implement M2.7 Track A — Container Identity & Lifecycle — specifically items 1–5 (identity derivation, image naming, container naming, Docker labels, SESSION_STATE). Track A items 6–8 (make stop, make prune, artefact paths) are deferred to a subsequent session.

## Recovery checks

| Check | Result |
|---|---|
| Roadmap reflects prior handover state | ✅ The prior handover (20260602-01) is a Plan type — no code changed; roadmap unchanged |
| Trigger B pending | ✅ None pending |

## Scope

**In scope — this session (item 1 only):**

1. **SANDBOX_ID and RUN_ID derivation** — Add `SANDBOX_ID` and `RUN_ID` to `scripts/start_agent.sh`. Rename `REPO_COMMIT` → `HOST_HEAD_SHA`. Remove `WORKTREE_ID` and `worktree_id_derive()`. Add `{{RUN_ID}}` and `{{HOST_HEAD_SHA}}` substitutions to `src/build/compose.sh`.

**Out of scope — deferred to later sessions:**
- Items 2–8 of Track A (image naming, container naming, labels, SESSION_STATE, stop, prune, artefact paths)
- All of Track B (build pipeline, two-sig, dry-run seam testing, AGENTS.md injection cleanup, autosave reliability)
- All of Track C (UID mapping)
- Mid-session finding: BRANCH_FROM_ARG default unification with HOST_HEAD_SHA
- Test updates (WORKTREE_ID → SANDBOX_ID in test files)
- Documentation updates

## Hot files

| File | Reason |
|---|---|
| `scripts/start_agent.sh` | Identity derivation, WORKTREE_ID removal, REPO_COMMIT rename, container naming |
| `src/build/image.sh` | `worktree_id_derive` removal, image naming functions |
| `src/build/compose.sh` | {{RUN_ID}} and {{HOST_HEAD_SHA}} substitutions |
| `src/build/docker-compose.yml` | x-session-labels anchor and service labels |
| `src/capability/snapshot.sh` | SESSION_STATE: write `host_head_sha` |
| `scripts/build.sh` | Propagate SANDBOX_ID to image naming |
| `tests/test_start_agent.sh` | WORKTREE_ID tests → SANDBOX_ID tests |
| `tests/test_checkpoint.sh` | WORKTREE_ID_derive tests → SANDBOX_ID tests |
| `docs/concepts/sandbox_host_correspondence_model.md` | Identity table update |

## Design reference

[`design_session_identity_hash_based.md`](../discussions/design_session_identity_hash_based.md) — spec for hash-based identity model. Decisions from 20260602-01 handover (A–H) are adopted.

## Decisions

| # | Decision | Rationale |
|---|---|---|
| A | Adopt tiered identity model per design doc | Supersedes flat WORKTREE_ID + REPO_COMMIT model |
| B | Rename REPO_COMMIT → HOST_HEAD_SHA | Clearer name |
| C | Image naming includes SANDBOX_ID | Prevents collision across sandbox instances at different commits |
| D | Labels: `agent-sandbox.project-name`, `sandbox-dir`, `host-head-sha`, `host-branch`, `session-ts`, `run-id` | Complete provenance set; matches design spec |
| E | WORKTREE_ID removed; `worktree_id_derive()` function removed | Superseded by SANDBOX_ID |

## Completed this session

| File | Change |
|---|---|
| `scripts/start_agent.sh` | Added `SANDBOX_ID` and `RUN_ID` derivation after `SESSION_TS`. Renamed `REPO_COMMIT` → `HOST_HEAD_SHA`. Removed `WORKTREE_ID` block and redundant second `source image.sh`. Added identity echoes. |
| `src/build/compose.sh` | Added `{{RUN_ID}}` and `{{HOST_HEAD_SHA}}` to substitution table in doc comment and `sed` expression list. |

## Deferred items

| Item | Why deferred | Next session |
|---|---|---|
| Track A item 2: Image naming with SANDBOX_ID | One item per session | Next implementation session |
| Track A item 3: Container naming with RUN_ID | One item per session | After item 2 |
| Track A item 4: Docker labels | One item per session | After item 3 |
| Track A item 5: SESSION_STATE host_head_sha | One item per session | After item 4 |
| Track A item 6: make stop redesign | One item per session | After item 5 |
| Track A item 7: make prune | One item per session | After item 6 |
| Track A item 8: Artefact path updates | One item per session | After item 7 |
| Tests: update WORKTREE_ID → SANDBOX_ID in test files | Belongs with item's implementation | With respective items |
| BRANCH_FROM_ARG default unification with HOST_HEAD_SHA | Mid-session finding, needs design | After Track A |
| package-branch and package-diff working-context variable unification | From 20260530-04 — needs design | Unscheduled |

## Next session

Item 2 — Image naming with SANDBOX_ID.

- Update `src/build/image.sh`: `sandbox_image_name()` and `agent_image_name()` accept optional `sandbox_id` arg; when present return `sandbox-<project>-<sandbox_id>` / `<provider>-agent-<project>-<sandbox_id>`.
- Update `scripts/start_agent.sh` to propagate `SANDBOX_ID` to image name calls.
- Update `scripts/build.sh` to propagate `SANDBOX_ID` through `build_sandbox`, `build_agent`, `preflight`.
- Remove `worktree_id_derive()` function from `src/build/image.sh` (superseded by SANDBOX_ID).
