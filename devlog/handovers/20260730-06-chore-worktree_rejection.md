# Agent Handover

**Session date:** 2026-07-30
**Milestone:** M2.6 — Session Persistence
**Session type:** Housekeeping — Worktree rejection and simplified mount model
**Status:** Closed

## Objective

Formally reject worktree backing, consolidate all worktree-related documents into one study, write the rejection ADR, and simplify the mount model design to reflect the user-provided `.git` approach.

## Scope

Three units:

**Unit 1 — Worktree rejection study:** Consolidated all worktree investigations into `devlog/discussions/20260730-study-settled-worktree_rejection.md` — mechanism design, security delta (invariant-by-invariant comparison, residual risk table, required mitigations), and rejection rationale. Supersedes 5 documents.

**Unit 2 — ADR:** `docs/adr/sandbox_delivery_model.md` — formal record of the rejection decision with rationale.

**Unit 3 — Mount model simplification:** Stripped worktree content from `devlog/discussions/20260730-design-settled-mount_model.md`. Backing axis now: "user-provided `.git` — whatever repo the user places in the mounted directory. Harness does not mediate." Roadmap updated to link to ADR.

## Content migration

**Created:**

| File | Lines | Content |
|---|---|---|
| `devlog/discussions/20260730-study-settled-worktree_rejection.md` | 170 | Consolidated: mechanism design, security delta, residual risk analysis, rejection rationale |
| `docs/adr/sandbox_delivery_model.md` | 53 | ADR: rejection decision + rationale |

**Deleted:**

| File | Reason |
|---|---|
| `20260622-study-settled-security_delta_worktree_model.md` | 317 lines consolidated into worktree rejection study |

**Modified:**

| File | Change |
|---|---|
| `devlog/discussions/20260730-design-settled-mount_model.md` | Worktree content replaced with one-liner + ADR link |
| `devlog/roadmap.md` | Not in scope → Rejected; links to ADR; stale backlinks task updated |

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Single worktree document covers mechanism, security delta, rejection | Accepted — `20260730-study-settled-worktree_rejection.md` |
| 2 | ADR records rejection decision | Accepted — `docs/adr/sandbox_delivery_model.md` |
| 3 | Mount model doc has no worktree detail beyond one-liner + link | Accepted |
| 4 | Roadmap links to ADR | Accepted |
| 5 | security_delta deleted (content migrated) | Accepted |

## Hot files

| File | Why in scope |
|---|---|
| `devlog/discussions/20260730-study-settled-worktree_rejection.md` | New — consolidated worktree investigation |
| `docs/adr/sandbox_delivery_model.md` | New — worktree rejection ADR |
| `devlog/discussions/20260730-design-settled-mount_model.md` | Simplified — worktree content removed |
| `devlog/roadmap.md` | Updated links to ADR |

## Completed this session

| File | Change summary |
|---|---|
| `devlog/discussions/20260730-study-settled-worktree_rejection.md` | New: consolidated worktree investigation (mechanism, security delta, rejection) |
| `docs/adr/sandbox_delivery_model.md` | New: ADR — worktree backing rejected |
| `devlog/discussions/20260730-design-settled-mount_model.md` | Simplified: worktree content → one-liner + ADR link |
| `devlog/discussions/20260622-study-settled-security_delta_worktree_model.md` | Deleted: content migrated to worktree rejection study |
| `devlog/roadmap.md` | Not in scope → Rejected; links to ADR |

## Deferred items

None.

## Next session

**Session type:** Implementation — security.md rewrite

Rewrite `docs/architecture/security.md` to reflect the simplified two-path model (M2.6.5 Copy, M2.6.6 Mount). Remove worktree row from Mount modes table. Update stale backlinks. Document the new principle: harness provides container boundary; user provides `.git`; harness does not mediate git operations.
