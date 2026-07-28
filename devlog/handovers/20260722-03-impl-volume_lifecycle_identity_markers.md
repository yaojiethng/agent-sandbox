# Agent Handover

**Session date:** 2026-07-22
**Milestone:** M2.6 — Session Resume and Mount Model Redesign
**Session type:** Implementation — Volume lifecycle, identity markers, and prune scoping
**Status:** Closed

## Objective

Investigate `prune.sh` to verify the three-tier volume removal model is correctly implemented and the boundaries between `stop`, `stop PRUNE`, and `start REFRESH` are clean.

## Three-tier model (current state)

| Tier | Command | What it removes | Volume preserved? |
|---|---|---|---|
| 1 — Stop | `make stop` | Containers only (via `stop.sh`) | ✅ Named volume preserved |
| 2 — Prune | `make stop PRUNE=1` or `make prune` | Aged containers, images, networks for this project only (via `prune.sh`). Volumes omitted — the named `sandbox-data` volume is managed by compose lifecycle, not prune. | ✅ Named volume preserved |
| 3 — Fresh | `make start REFRESH=1` | Everything — destroys volume via `compose_teardown -v` | ❌ Named volume destroyed |

## Findings

### Finding 1 — prune must not prune the named volume

`prune.sh` was initially changed to include `--volumes` on `docker system prune`, but this would remove the named `sandbox-data` volume if unused and older than 3 days (checked by creation date, not last-used date). Since the only volume belonging to this project is the named persistent volume, `--volumes` would only ever destroy data we want to keep. Volumes removed from scope — prune handles containers, images, and networks only.

### Finding 2 — cross-project volume cleanup removed

The original `docker volume prune --filter "label!=agent-sandbox.project-name"` was removed in the initial pass. Confirmed this is correct: it was touching volumes outside the project scope.

### Finding 3 — only one volume exists per project

The compose template defines exactly one named volume (`sandbox-data`) per project. Docker Compose reuses the same volume across runs — it is not overwritten, it persists. Different projects have different volume names (project-scoped). The named volume is only destroyed on `make start REFRESH=1` or `docker compose down -v`.

## Scope

- `scripts/prune.sh` — Scope to current project only; remove `--volumes` (named volume not for pruning); remove cross-project volume cleanup
- `scripts/stop.sh` — Update `--prune` description to match actual prune scope
- `AGENTS.md` — Add final acceptance gate (Gate 3) from iteration_policy.md
- `devlog/discussions/design_session_identity_hash_based.md` — Rename to modern naming format, mark superseded
- `docs/adr/20260722-adr-settled-session_identity_and_container_markers.md` — New ADR distilling session identity decisions
- `devlog/discussions/story_session_identity_and_harness_versioning.md` — Update superseded link to point to ADR

## Acceptance criteria

| # | Criterion | Verifiable by |
|---|---|---|
| 1 | `prune.sh` does not prune volumes | `grep -c volumes\|--volumes` in `scripts/prune.sh` = 0 |
| 2 | `prune.sh` header/usage accurately describes scope | Manual review |
| 3 | `stop.sh` `--prune` description matches prune scope | Manual review |
| 4 | `AGENTS.md` has Gate 3 rule | `grep -c` passes |
| 5 | Discussion file renamed and superseded | File exists at new path, status is Superseded |
| 6 | ADR created with session identity decisions | File exists at `docs/adr/20260722-adr-settled-session_identity_and_container_markers.md` |
| 7 | Tests pass | 418 passed, 0 failed, 6 skipped |
