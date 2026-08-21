# Agent Handover

**Date:** 2026-08-21
**Milestone:** M2.6 — Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective
Deliver **Option D(a)** of the L141 staleness-restoration: restore the volume/sandbox staleness criterion (lost in the command-split) using the `.compose/<session-id>.yml` registry as source of truth (D7) and surface it in `resume --list`. Also roll in the three queued thermo-nuclear review fixes from iteration `20260821-06` (interactive.sh bootstrap, test fixture, comment). **`prune.sh` is NOT changed this iteration** — its current `--stale` is the legacy volume-label path and stays as-is; the **registry-based prune (Rules 1+2) is a separate consecutive iteration** (see What's Next). The full prune command-shape redesign and the image-staleness column remain out of scope.

## Context

### Finding being restored (`20260821-05`)
The volume/sandbox staleness criterion (`agent-sandbox.host-head-sha` ≠ current `git rev-parse HEAD`) was **lost** when the resume branch was stripped from `start` (`20260821-04`). `make resume` reads identity from `.compose/<session-id>.yml` and applies **no** staleness gate; docs describing volume staleness are out of date. Filed under L141 (interactive prune redesign). Option D scopes the restoration subset on the settled registry/worktree shapes, deferring lock-dependent prune-scope parts.

### Current `resume --list` shape
`scripts/resume_agent.sh` builds `RESUME_INVENTORY` as `SESSION_ID|provider|session-ts|branch` (newest first), optionally filtered by provider, and renders:
```
Resumable sessions (make resume SESSION_ID=<id>):
  <sid><-8>  <provider><-10>  <session-ts><-17>  <branch>
```
Registry field extraction helpers: `record_provider(file)` (from `image: <provider>-agent-<project>`), `record_label(file, label)` (from `x-session-labels.agent-sandbox.<label>`).

### Current `prune.sh --stale` mechanism (the inconsistency)
`make stop PRUNE=1 STALE=1` → `prune.sh --stale` computes staleness by **`docker volume ls` filtered by `agent-sandbox.sandbox-dir` label** then `docker volume inspect ... Labels["agent-sandbox.host-head-sha"]` vs current HEAD. So **resume reads `.compose` (D7 truth) but prune reads docker volume labels** — the exact inconsistency the finding flags. Prune has no `--list` surface.

### Registry staleness source
Each `.compose/<session-id>.yml` record `x-session-labels.agent-sandbox.host-head-sha` records the HEAD SHA at session creation. Sandbox staleness = that recorded SHA ≠ current `git -C "$PROJECT_DIR" rev-parse HEAD`.

### Scope (confirmed, operator `2026-08-21`)
1. **Shared sandbox-staleness helper (D7 truth)** — staleness over `.compose` records (`host-head-sha` vs current HEAD), reusable for resume and a future registry-based prune.
2. **`resume --list` sandbox-staleness column** — extend `RESUME_INVENTORY`/render with a `stale`/`fresh` column; backward-compatible with existing tests.
3. **`prune.sh` untouched** — current `--stale` volume-label path stays as-is; the **registry-based prune (Rule 1: prune stale `.yml` records per args; Rule 2: a run with no matching `.compose` record is prunable) is a separate consecutive iteration** (confirmed against design walk `20260818-02` / mount-model record).
4. **Fold in the 3 queued review fixes.**
5. **Tests + docs sweep** — `test_resume.sh` staleness-column tests; docs swept for the volume-label `STALE` semantics → registry-truth surface, noting the consecutive registry-based-prune follow-on. Suite stays green.

### Queued review fixes to fold in (from `20260821-06` review)
1. `interactive.sh` self-locates its repo root (mirrors `draft.sh`/`apply.sh`) so `start_agent.sh`/`resume_agent.sh` drop their duplicated `AGENT_SANDBOX_REPO="${AGENT_SANDBOX_REPO:-$REPO_ROOT}"` fallback and use `$REPO_ROOT`; `_start_providers()` uses `$REPO_ROOT`.
2. `test_wizard_accept_runs_to_completion` in `test_start_agent.sh` reuses `make_committed_repo` instead of hand-writing git init/commit.
3. Reword `_start_providers()` comment ("build.sh validates, not enumerates").

## Decisions
*Resolved in-session; final decisions only.*

**D7-a — Sandbox staleness is registry-truth (D7), surfaced but not gating.** `resume --list` gains a `fresh`/`stale`/`unknown` sandbox-staleness column computed from each `.compose` record's `host-head-sha` vs current project HEAD. `unknown` when the record has no `host-head-sha` or the current HEAD can't be determined. No resume staleness **gate** is re-introduced (surfacing only, per scope).

**D7-b — Interactive picker consumes the staleness field without corrupting display.** `RESUME_INVENTORY` lines grow a 5th `stale` field; the interactive path reads all 5 so the branch column isn't polluted, and marks stale sessions `[STALE]` in the picker.

**D7-c — `prune.sh` untouched this iteration.** The current `--stale` volume-label path stays; the registry-based prune (Rules 1+2) is a separate consecutive iteration (`20260821-08`). The `session_stale` helper is the reuse point.

## Findings
| Finding | Type | Impact |
|---|---|---|
| The `AGENT_SANDBOX_REPO` fallback in `start_agent.sh`/`resume_agent.sh` was a tautology (REPO_ROOT ≡ AGENT_SANDBOX_REPO in every invocation) and existed only to satisfy `interactive.sh`'s internal routing.sh source | structural (review `20260821-06`) | resolved — `interactive.sh` self-locates (mirrors draft/apply); consumers use `$REPO_ROOT` |
| `test_wizard_accept_runs_to_completion` hand-wrote a git fixture instead of the canonical `make_committed_repo` | test consistency (review `20260821-06`) | resolved — fixture reused |

## Completed
| File | Change |
|---|---|
| `scripts/resume_agent.sh` | Added `session_stale()` (registry-truth staleness: fresh/stale/unknown, D7); `build_inventory` lines gain a `stale` field; `--list` renders the sandbox-staleness column; interactive picker reads all 5 fields and marks stale sessions `[STALE]`; dropped the redundant `AGENT_SANDBOX_REPO` fallback (sources `interactive.sh` via `$REPO_ROOT`) |
| `scripts/start_agent.sh` | Dropped the redundant `AGENT_SANDBOX_REPO` fallback; `_start_providers()` + wizard use `$REPO_ROOT`; reworded the `_start_providers()` comment (fix #3) |
| `scripts/workflows/interactive.sh` | Self-locates its repo root (`AGENT_SANDBOX_REPO` default from own path, mirrors draft/apply) before sourcing `routing.sh` |
| `tests/test_resume.sh` | New `test_list_shows_sandbox_staleness` (git-repo project: matching record `fresh`, differing `stale`) |
| `tests/test_start_agent.sh` | `test_wizard_accept_runs_to_completion` reuses `make_committed_repo` (fix #2) |
| `docs/architecture/tool_interface.md`, `docs/architecture/sandbox_lifecycle.md`, `docs/development/quickstart.md` | `resume --list` documented with the registry-truth `fresh/stale/unknown` sandbox-staleness column |
| `devlog/roadmap.md` | Review-fixes entry marked done (folded into `20260821-07`); **new** queued entry for the consecutive registry-based prune (Rules 1+2) |

## What's Next
- Present AC status + suite output for pre-close review (Gate 3); set Status Closed and commit.
- Acknowledge completion on roadmap (the review-fix + staleness-surface parts of the queued L141 sub-task).

## Consecutive iteration — registry-based prune (Rules 1+2)
The **registry-based prune** is explicitly deferred to the **next consecutive iteration** (not this one; `prune.sh` stays untouched here). Original model (confirmed, design walk `20260818-02` / mount-model record): **Rule 1** — prune `.compose/*.yml` per prune args (the stale records); **Rule 2** — a run with no matching `.compose/<session-id>.yml` record is prunable, scope by delivery (copy: volume + containers; mount: registry resources only; worktrees never touched). The shared staleness helper built here is the reuse point for that iteration.
