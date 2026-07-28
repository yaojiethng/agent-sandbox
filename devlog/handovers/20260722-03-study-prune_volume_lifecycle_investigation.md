# Agent Handover

**Session date:** 2026-07-22
**Milestone:** M2.6 — Session Resume and Mount Model Redesign
**Session type:** Study — Prune.sh volume lifecycle investigation
**Status:** Closed

## Objective

Investigate `prune.sh` to verify the three-tier volume removal model is correctly implemented and the boundaries between `stop`, `stop PRUNE`, and `start REFRESH` are clean.

## Three-tier model (current state)

| Tier | Command | What it removes | Volume preserved? |
|---|---|---|---|
| 1 — Stop | `make stop` | Containers only (via `stop.sh`) | ✅ Named volume preserved |
| 2 — Prune | `make stop PRUNE=1` or `make prune` | Aged containers, images, networks for this project (via `prune.sh`); orphaned volumes from other projects | ✅ Named volume preserved |
| 3 — Fresh | `make start REFRESH=1` | Everything — destroys volume via `compose_teardown -v` | ❌ Named volume destroyed |

## Findings

### Finding 1 — prune.sh header/usage overstates volume cleanup

`prune.sh` header says: "Removes orphaned containers, images, and **volumes** for a given project+sandbox instance." The usage repeats this. But `prune.sh` does NOT remove the project's own named volume (`sandbox-data`):

- `docker system prune` (without `--volumes`) removes containers, images, networks — not volumes
- `docker volume prune --filter "label!=agent-sandbox.project-name"` removes volumes from OTHER projects, not this one

The named volume `sandbox-data` carries the `agent-sandbox.project-name` label, so it is never matched by the second prune command (which excludes labeled volumes). This is correct behaviour — the volume should survive pruning — but the documentation inaccurately describes it.

### Finding 2 — No functional gaps in the three-tier model

- Tier 1 (stop): clean after our previous fix — no volumes touched.
- Tier 2 (prune): correctly prunes aged disposable resources while preserving the persistent volume.
- Tier 3 (refresh): intentionally destructive — the user opted in.

The only gap is documentation accuracy in `prune.sh`.

### Finding 3 — `sandbox_lifecycle.md` accurately notes session-diff accumulation

Already documented: `workspace/session-diffs/` accumulates over time and is not auto-pruned. This is about diff files, not Docker volumes. Separate concern, already tracked.

## Scope

- `scripts/prune.sh` — Fix header and usage comment to accurately describe what it does
- Optionally: flag this as a known gap for future improvement if needed

## Acceptance criteria

| # | Criterion | Verifiable by |
|---|---|---|
| 1 | `prune.sh` header accurately describes what it removes | Manual review |
| 2 | `prune.sh` usage text accurately describes what it removes | Manual review |
