# Agent Handover

**Session date:** 2026-05-13
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Implementation
**Status:** Closed

## Objective

Create the capability layer dry-run investigation script (`dry_run_capability.sh`) and wire it into the dry-run compose overlay and orchestration — extending dry-run to assert the sandbox side of the host-container seam.

## Scope

M2.7 item 11c — dry_run_capability.sh.

- Create `scripts/dry_run_capability.sh` with investigation-level checks: image file existence, session state validity, mount writability, diff pipeline invocability, CHANGES_DIR round-trip marker.
- Update `libs/docker-compose.dry-run.yml` to mount the script into the sandbox service (alongside existing agent mount).
- Update `scripts/run_agent.sh` to export `DRY_RUN_CAPABILITY_SCRIPT`.
- Update `libs/compose.sh` to substitute `{{DRY_RUN_CAPABILITY_SCRIPT}}` and execute Phase 1 (capability checks) before Phase 2 (reasoning checks).
- Add Phase 3 placeholder (host-side verification — implemented in 11e).
- Subsumes the image-file-existence checks from `test_capability_layer.sh` (lines 126–137: sandbox-entrypoint.sh, snapshot.sh, diff.sh, dirs.sh).

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | `scripts/dry_run_capability.sh` exists with image file existence, session state, mount, diff pipeline, and round-trip checks | ✅ |
| 2 | `libs/docker-compose.dry-run.yml` mounts script into sandbox service | ✅ |
| 3 | `scripts/run_agent.sh` exports `DRY_RUN_CAPABILITY_SCRIPT` | ✅ |
| 4 | `libs/compose.sh` substitutes `{{DRY_RUN_CAPABILITY_SCRIPT}}` | ✅ |
| 5 | `compose_dry_run` runs Phase 1 (capability) before Phase 2 (reasoning) with abort-on-failure | ✅ |
| 6 | `bash -n` passes on all modified files | ✅ |
| 7 | `make test` passes clean | ✅ |

## Hot files

| File | Why in scope |
|---|---|
| `scripts/dry_run_capability.sh` | **New** — capability layer investigation checks |
| `libs/docker-compose.dry-run.yml` | Added sandbox bind mount for capability script |
| `scripts/run_agent.sh` | Added `DRY_RUN_CAPABILITY_SCRIPT` export |
| `libs/compose.sh` | Added template substitution + three-phase `compose_dry_run` |
| `tests/test_capability_layer.sh` | Image-file checks (lines 126–137) now subsumed by capability dry-run |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Phase 3 is a placeholder in this session | Host-side verification logic (checking artifacts on host after containers exit) is separate work scoped to 11e. The orchestration structure is in place; the verification body comes later. | This handover |
| Capability marker left in CHANGES_DIR for reasoning layer to read | Cross-container communication test — reasoning layer reads what capability wrote. Cleaned up by host-side phase (11e). | Design doc §Phase 1 |

## Mid-session findings

None.

## Completed this session

| File | Change |
|---|---|
| `scripts/dry_run_capability.sh` | **New** — 4 check sections (image files, session state, mounts, diff pipeline, round-trip) |
| `libs/docker-compose.dry-run.yml` | Added sandbox volume ({{DRY_RUN_CAPABILITY_SCRIPT}} → /dry_run_capability.sh) |
| `scripts/run_agent.sh` | Export DRY_RUN_CAPABILITY_SCRIPT; pass to compose_dry_run |
| `libs/compose.sh` | Added template substitution; rewrote compose_dry_run with three-phase orchestration |
| `docs/devlog/roadmap.md` | Marked 11c as ✅ |
| `docs/devlog/handovers/20260513-05-impl-dry_run_capability.md` | **New** — this handover |

## Deferred items

None.

## Next session

**11d. dry_run.sh rewrite.** Rewrite the reasoning-layer checks as a separate, focused script. Remove any capability-layer checks that leaked into it. Fully decouple from capability layer. Subsumes the old `dry_run.sh` completely.
