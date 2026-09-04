# Handover 20260904-06 — impl seed transport removal (legacy docker cp path)

**Milestone:** M2.6 - Session Persistence
**Type:** impl
**Status:** Closed
**Date:** 2026-09-04

## Objective

Step 3 of the operator plan (handover 20260904-04): the helper-container seeder is live-verified (dry-run ALL PHASES PASSED, parity verified, no seed folder) — remove the legacy `docker cp` seed machinery and align docs and tests. Also lands the mount-path `snapshot_copy_worktree` enumeration fix (ADR mount-path entry, 2026-09-04).

## Scope

| # | Item | Files | Status |
|---|---|---|---|
| 1 | Remove `SEED_TRANSPORT` switch and legacy `seed_sandbox_volume` body; helper is the only path | `scripts/run_agent.sh` | done |
| 2 | Remove `snapshot_seed_tar`, `snapshot_init_git`, `snapshot_archive_head`; keep `snapshot_copy_worktree` + `snapshot_check_case_mismatch` + `filesystem_tracks_exec_bits` | `src/capability/snapshot.sh` (505 → 170 lines) | done |
| 3 | Remove the fresh-init legacy branch; unseeded volume now fails closed with a readable error; fresh-start message distinguishes seeded vs resumed (`RESET_VOLUME` plumbed through compose) | `src/capability/entrypoint.sh`, `src/build/docker-compose.yml`, `scripts/run_agent.sh` | done |
| 4 | Remove the `.agent-sandbox-seed/` ignore line | `.gitignore` | done |
| 5 | Mount-path fix: git enumeration + `--from0 --files-from`; obsolete exclude-list/trap/warning machinery removed; case-mismatch retained and wired into the seeder | `src/capability/snapshot.sh`, `src/capability/seed_volume.sh` | done |
| 6 | Tests: `test_snapshot_container.sh` deleted (seed tar + init git + isolation — guarantees live in `test_seed_volume.sh`); archive-head tests deleted; negation + global-exclude leak tests added; discovery probes deleted (both copies) | `tests/`, `scripts/manual/` | done |
| 7 | Docs: `sandbox_lifecycle.md` Phase 1 rewritten; `execution_model.md`, `system_overview.md`, `sandbox_host_correspondence_model.md`, `mount_delivery.md`, `project_index.md` updated | `docs/` | done |
| 8 | Roadmap: seed-transport task marked done; testing-cleanup task's discovery-rename item resolved by removal | `devlog/roadmap.md` | done |

## Deferred

- Remaining testing-policy cleanup (dead `test_list_no_sig_when_field_empty`, runner liveness checks) — separate roadmap task, unchanged.
- Session-state/message polish in entrypoint beyond the removed branch.

## Findings

| # | Finding | Status |
|---|---|---|
| F1 | `rsync --delete` with `--files-from` does not delete root-level extraneous files in the destination (deletions apply only to listed directories). The old `--delete` pass was vestigial: re-materialization is not a real scenario (fresh mount only; an existing worktree with `.git` is reused directly). `--delete` dropped rather than approximated. | Resolved |
| F2 | The old rsync exclude-list warning pass ("excluded by global gitignore or .git/info/exclude") is obsolete by construction: under git enumeration, global excludes are part of git's ignore resolution and those files were never project content. | Resolved |
| F3 | `test_sandbox_isolation` retired with `test_snapshot_container.sh`: its fixture wrote to a local directory copy, so it asserted local-filesystem isolation, not volume isolation. Volume-level isolation is Docker's guarantee plus the session-labeled volume wiring (R4), not testable through the removed fixture. | Resolved (accepted loss, noted) |

## Decisions

| # | Decision | Rationale | Source |
|---|---|---|---|
| D1 | Retire both `discovery_tar_*` probes rather than rename them. | Pipeline A (the rsync-based seed) is deleted; the parity probe loses its referent and the round-trip probe's coverage moved into `test_seed_volume.sh`. Resolves the `discovery_` prefix cleanup for these two files by removal. | Audit (20260904-03) |

## Acceptance criteria (pre-close)

| # | Criterion | Status |
|---|---|---|
| AC1 | No reference to the legacy seed machinery remains in scripts/src (grep clean; historical mentions only in ADR entries) | done |
| AC2 | `snapshot_copy_worktree` passes negation and global-exclude cases (new tests) | done (2 new tests, leak case green) |
| AC3 | Suite green, lint Clean | done (739/739, lint exit 0) |
| AC4 | Docs describe the helper-container seed as the only transport | done (architecture + concepts swept; zero stale references) |
