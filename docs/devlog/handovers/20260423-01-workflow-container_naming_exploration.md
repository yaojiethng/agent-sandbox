# Agent Handover

**Session date:** 2026-04-23
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Design
**Status:** Closed

## Objective

Design hash-based session identity (run_id) to replace timestamp-based container naming; supersede existing M2.7 design document.

## Scope

Design session triggered by operator proposal: replace timestamp-based container naming with a short hash (run_id) that encodes the M2.7 primitive set (SESSION_TS, REPO_COMMIT, WORKTREE_ID).

**In scope:**
1. Design document creation: hash-based run_id for container naming and session identity
2. Define hash input factors (M2.7 primitives) and output format (6-char hex with `:` separator)
3. Mark existing `story_session_identity_and_harness_versioning.md` as SUPERSEDED
4. Update M2.7 roadmap entry with new design reference
5. Document `make stop` criteria (Docker Compose project labels)
6. Add `make prune` task to M2.7 roadmap (Docker cache/volume cleanup)

**Explicitly deferred:**
- Implementation — this is design only
- M2.3 implementation units C-G (pending per roadmap)

**Files to change:**
- `docs/discussions/design_session_identity_hash_based.md` (new)
- `docs/devlog/discussions/story_session_identity_and_harness_versioning.md` (SUPERSEDED marker)
- `docs/devlog/roadmap.md` (M2.7 design reference + prune task)

## Carried forward

None.

## Acceptance criteria

| Criterion | Status |
|---|---|
| Design document exists with run_id formula, container naming, stop/prune design | ✓ Accepted |
| Old design document has SUPERSEDED marker with link to new design | ✓ Accepted |
| M2.7 roadmap entry references new design document | ✓ Accepted |
| M2.7 roadmap includes make stop redesign and make prune task | ✓ Accepted |

## Hot files

| File | Why in scope | Status |
|---|---|---|
| `docs/discussions/design_session_identity_hash_based.md` | New design document for hash-based run_id | ✓ Complete |
| `docs/devlog/discussions/story_session_identity_and_harness_versioning.md` | Mark as SUPERSEDED | ✓ Complete |
| `docs/devlog/roadmap.md` | Update M2.7 design reference + add prune task | ✓ Complete |
| `scripts/start_agent.sh` | Read for SESSION_TS/WORKTREE_ID/REPO_COMMIT context | Read only |
| `scripts/checkpoint.sh` | Read for WORKTREE_ID derivation context | Read only |
| `scripts/stop.sh` | Document stop criteria (Docker Compose project labels) | Read only |
| `libs/_templates/Makefile.template` | Reference for make stop target structure | Read only |

## Decisions made this session

None.

## Completed this session

| File | Change summary |
|---|---|
| `docs/discussions/design_session_identity_hash_based.md` | Created: hash-based run_id design, container naming, make stop/prune design |
| `docs/devlog/discussions/story_session_identity_and_harness_versioning.md` | Added SUPERSEDED marker with link to new design |
| `docs/devlog/roadmap.md` | Updated M2.7: design reference, stop/prune tasks, stale images reference |

## Deferred items

None.

## Next session

**Sub-milestone:** M2.7 — Session Identity and Harness Versioning.
**Session type:** Implementation — Phase 1 (run_id derivation and container naming).

Read `docs/devlog/roadmap.md` M2.7 section for task list. Start with Phase 1 tasks in `docs/discussions/design_session_identity_hash_based.md`.

**Watch-outs:**
- `SESSION_NAME` retained for backwards compatibility in Docker labels
- Existing containers use timestamp-based naming; new sessions use run_id
- Image rename (dropping `<project>` suffix) blocked on agents.md code review

**Grep to run:** `grep -r "SESSION_TS" scripts/ libs/` — identify all timestamp usages for migration.
