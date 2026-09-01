# Agent Handover

**Date:** 2026-07-30
**Milestone:** M2.6 — Session Persistence
**Type:** Implementation — Security model rewrite for simplified two-path model
**Status:** Closed

## Objective

Rewrite `docs/architecture/security.md` to reflect the simplified two-path model (Copy M2.6.5, Mount M2.6.6), remove all worktree content, and document the new principle: harness provides container boundary, user provides `.git`, harness does not mediate git operations.

## Scope

Single file: `docs/architecture/security.md`. Six targeted edits.

## Changes

| Section | Change |
|---|---|
| Principle | Updated link to new mount model doc. Added: harness does not mediate git operations. |
| Mount modes table | Removed Worktree row. Renamed Columns: `.snapshot/` / `.git` (was `PROJECT_DIR/.git`). Mount row: user-provided `.git`. Added ADR link for worktree rejection. |
| Assumptions | Removed `(mount, worktree)` qualifier — mount containment only. |
| Security Invariants | Removed "Worktree backing (not supported)" paragraph. |
| Execution Model Assumptions | "Containers are ephemeral" → "Containers and volumes persist across restarts via `docker compose stop`" |
| Non-goals | Removed worktree residual risk paragraph and "verify no secrets in git history" bullet. |

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Zero stale backlinks in security.md | Accepted — `grep` confirms zero references to deleted files |
| 2 | Mount modes table: Copy + Mount only, no Worktree | Accepted |
| 3 | Principle documents harness/git boundary | Accepted |
| 4 | All stale references outside handovers resolved | Accepted — `adr_policy.md` example updated |
| 5 | Roadmap stale-backlinks task marked complete | Accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/architecture/security.md`](docs/architecture/security.md) | Six edits: Mount modes, Principle, Invariants, Assumptions, Non-goals |
| [`docs/operations/adr_policy.md`](docs/operations/adr_policy.md) | Updated supersede example to reference new doc |
| [`devlog/roadmap.md`](devlog/roadmap.md) | Stale-backlinks task marked complete |

## Completed this session

| File | Change summary |
|---|---|
| [`docs/architecture/security.md`](docs/architecture/security.md) | Rewritten: worktree removed, simplified two-path model, user-provided `.git`, harness-git boundary documented |
| [`docs/operations/adr_policy.md`](docs/operations/adr_policy.md) | Updated supersede example |
| [`devlog/roadmap.md`](devlog/roadmap.md) | Security model update task marked complete |

## Deferred items

None.

## Next session

Continue M2.6.5 — multi-volume concurrency implementation (volume-per-session via RUN_ID, locking, interactive selector).
