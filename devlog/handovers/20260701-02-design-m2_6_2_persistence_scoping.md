# Agent Handover

**Date:** 2026-07-01
**Milestone:** M2.6 — Session Resume and Mount Model Redesign
**Type:** Design — Phase 1.5 scoping
**Status:** Closed

## Objective

Scope the Phase 1.5 implementation: volume-based session persistence without the full worktree mount model. Container persists by default; `REFRESH=1` recreates from scratch.

## Design Decision

### Decision diagram (persisted in docs/)

```
make start (no REFRESH)
  │
  ├─ .run-identity exists?  (host file in SANDBOX_DIR)
  │    ├── No  → compute SESSION_TS, RUN_ID, HOST_HEAD_SHA, SANDBOX_ID
  │    │         write to .run-identity
  │    │         run copy pipeline (snapshot_copy_worktree, snapshot_archive_head)
  │    │         compose up → volume created → snapshot_init_git
  │    │
  │    └── Yes → read identity from .run-identity
  │               re-export SESSION_TS, RUN_ID, HOST_HEAD_SHA, SANDBOX_ID
  │
  ├─ volume sandbox-<project>-data exists and /.git/HEAD resolves?
  │    ├── No  → run copy pipeline → compose up → snapshot_init_git
  │    └── Yes → skip copy pipeline → compose up (reuses volume)
  │              entrypoint: skip snapshot_init_git, resume existing git state
  │
  └─ (proceed to compose up)

make stop
  └─ compose down              (no -v → volume preserved)

make start REFRESH=1
  ├─ rm .run-identity
  ├─ compose down -v           (-v → named volume removed)
  └─ compose up                (volume recreated fresh)
      └─ entrypoint: snapshot_init_git (full init)
```

### Volume model

- **Named volume** `sandbox-<project>-data` defined in compose template (top-level `volumes:`)
- Replaces the current anonymous volume (`VOLUME` instruction in Dockerfile kept for compatibility but superseded by compose-managed volume)
- `docker compose down -v` removes the named volume
- The named volume is labelled with `agent-sandbox.project-name` for lifecycle management

### Identity model — `.run-identity`

**Problem:** On resume, env vars (SESSION_TS, RUN_ID, HOST_HEAD_SHA) must match the values in the volume's SESSION_STATE so that diff_export at teardown and package_branch after the session use the same RUN_ID.

**Solution:** `$SANDBOX_DIR/.run-identity` stores the session identity for the current volume. Written once at first start, read back on resume, deleted on REFRESH.

```
# .run-identity format (key=value, one per line)
SESSION_TS=20260622-104203
RUN_ID=abc123
HOST_HEAD_SHA=deadbeef
SANDBOX_ID=12345678
```

**Written by:** `start_agent.sh` at first start (after computing fresh values)
**Read by:** `start_agent.sh` on resume (before compose up)
**Deleted by:** `make start REFRESH=1` (alongside volume removal)
**Consumed by:** Both host-side scripts and container-side scripts via env vars (exported by start_agent.sh, passed to compose, inherited by entrypoint)

### Init gating in capability entrypoint

```
Volume's sandbox/.git/HEAD resolves?
  ├── No  → ERROR: "Volume has no valid git state. Use REFRESH=1 to recreate."
  │         Container exits with non-zero.
  └── Yes → skip snapshot_init_git entirely. Resume existing git state.
             (No env var comparison needed — .run-identity guarantees alignment.)
```

No staleness warning on resume. The INIT_SHA in the volume's SESSION_STATE is correct for that session's diffs regardless of where the host HEAD is now. If the user wants a fresh baseline relative to current HEAD, they use REFRESH.

### REFRESH mechanism

`REFRESH=1` is gated at both teardown calls in `run_agent.sh` (pre-start and post-exit). When set:
1. `rm -f "$SANDBOX_DIR/.run-identity"` — removes the identity file
2. `-v` is added to `docker compose down` — removes the named volume

On the next `start`, no `.run-identity` + no volume → fresh init pipeline.

## Env var lifecycle under persistence

| Env var | Fresh init | Resume (from .run-identity) | Used by | Divergence risk resolved? |
|---|---|---|---|---|
| `SESSION_TS` | computed from `date -u` | read from `.run-identity` | `routing.sh` (diff export paths), `draft_state.sh`, compose labels | ✅ — same value on host and in SESSION_STATE |
| `RUN_ID` | derived from `SESSION_TS:SANDBOX_ID` | read from `.run-identity` | `diff_export.sh` (error logs), `package_diff.sh` → SESSION_STATE, `routing.sh` (output paths) | ✅ — `diff_export.sh` uses env var, `package_branch.sh` reads SESSION_STATE, both same value |
| `HOST_HEAD_SHA` | `git rev-parse HEAD` of PROJECT_DIR | read from `.run-identity` | SANDBOX_ID derivation, compose labels, SESSION_STATE (`host_head_sha`) | ✅ — stored but never consumed for validation |
| `SANDBOX_ID` | derived from `SANDBOX_DIR:HOST_HEAD_SHA` | read from `.run-identity` | RUN_ID derivation, debug output | ✅ |
| `SANITIZED_HOST_BRANCH` | derived from `git branch --show-current` | **not in .run-identity** — recomputed fresh | compose labels, draft branch naming | ✅ — branch identity is operational (which branch to review on) not historical; draft.sh reads from session-diffs path anyway |

## Files changed

| Priority | File | Change |
|---|---|---|
| **PREFACTOR** | `scripts/start_agent.sh` | Add `.run-identity` write (after computing identity vars) and read (before using them). Add volume-resume gating: skip copy pipeline if volume exists + `.git/HEAD` valid. Export `REFRESH` flag. |
| **PREFACTOR** | `src/build/docker-compose.yml` | Add top-level `volumes:` with named volume `sandbox-{{PROJECT_NAME}}-data`. Add `sandbox-data` volume mount to sandbox service (replaces implicit anonymous volume from Dockerfile `VOLUME`). |
| **CORE** | `src/build/compose.sh` | `compose_teardown()` — conditionally add `-v` only when `REFRESH=1`. |
| **CORE** | `scripts/run_agent.sh` | Both teardown calls — pass `REFRESH` to teardown logic. |
| **CORE** | `src/capability/entrypoint.sh` | Add pre-init check: if `/.git/HEAD` resolves, skip `snapshot_init_git` and log "resuming existing volume". If HEAD doesn't resolve, error with "Use REFRESH=1" message. |
| **DOCS** | `docs/architecture/security.md` | Update Execution Model Assumptions: "Containers are ephemeral" — Tier 1 now persists by default. |
| **DOCS** | `docs/operations/quickstart.md` | Document REFRESH flag and persistence model. Include decision diagram. |
| **DOCS** | `docs/operations/provider_onboarding_guide.md` | Note the new named volume in compose template. |
| **DOCS** | `devlog/roadmap.md` | Add Phase 1.5 subsection between Phase 1 and Phase 2. |
| **DOCS** | `docs/concepts/sandbox_identity.md` | Document `.run-identity` and env var lifecycle under persistence. |

## Files unchanged (reasons)

| File | Why not changed |
|---|---|
| `src/capability/snapshot.sh` | Init functions stay as fallback for fresh init path. |
| `scripts/stop.sh` | Label-based volume filtering is a no-op for named volumes managed by compose (compose handles lifecycle). |
| `scripts/prune.sh` | No change needed. |
| `src/libs/` (libs) | No lib changes — env vars flow unchanged; `.run-identity` just changes their source on resume. |
| `scripts/onboard.sh` | No change — SANDBOX_DIR structure unaffected. |
| `src/reasoning/entrypoint.sh` | No change — agent-side entrypoint is unaffected by volume model. |

## Documentation impact — each env var's lifecycle

When these docs describe env vars, they must state whether the value is recomputed or persisted:

| Env var | Under persistence | Doc update needed in |
|---|---|---|
| `SESSION_TS` | Set once at first start, reused on resume (via `.run-identity`) | `sandbox_identity.md` — lifecycle description |
| `RUN_ID` | Set once at first start, reused on resume (via `.run-identity`) | `sandbox_identity.md` — lifecycle description |
| `HOST_HEAD_SHA` | Set once at first start, reused on resume | `sandbox_identity.md` — note that it reflects original baseline, not current HEAD |
| `SANDBOX_ID` | Set once at first start, reused on resume | `sandbox_identity.md` — lifecycle description |
| `SANITIZED_HOST_BRANCH` | Recomputed each start (not persisted) | `sandbox_identity.md` — note that this is operational, not historical |
| `REFRESH` | New — fresh each invocation | `quickstart.md` — new flag documentation |

## Acceptance criteria

| # | Criterion | Verifiable by |
|---|---|---|
| 1 | `.run-identity` written to SANDBOX_DIR on first start | file exists after `make start` |
| 2 | `.run-identity` read back on subsequent start without REFRESH | same RUN_ID in container labels |
| 3 | `make start` without REFRESH reuses existing volume | entrypoint logs "resuming existing volume" |
| 4 | `.run-identity` + volume removed on `make start REFRESH=1` | new RUN_ID, fresh init runs |
| 5 | Volume persists after agent exits (normal teardown) | `docker volume ls` shows named volume |
| 6 | Entrypoint errors when `.git/HEAD` is invalid | container fails with clear message |
| 7 | `bash -n` on all changed shell files | syntax check |
| 8 | Existing tests pass | `bash scripts/run_tests.sh` exits 0 |
