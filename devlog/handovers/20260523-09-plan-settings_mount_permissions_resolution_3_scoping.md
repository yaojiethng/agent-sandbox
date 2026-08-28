# Agent Handover

**Session date:** 2026-05-23
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Planning
**Status:** Closed

## Objective

Scope and design a durable permission strategy to replace the interim ACL-based approach (session 20260523-08). Produce a design document with the final solution, file-change inventory, dependency ordering, user-facing documentation contract, and roadmap task entry.

## Scope

**In scope:**
- Evaluate alternative approaches (shared group bind, UID mapping) against cross-platform requirements
- Produce a design document with final solution, rationale, tradeoffs, surface area
- Update the story document with the selected strategy (Strategy 4: UID Mapping / User Hijack)
- Propose roadmap task entry for M2.7 Track C

**Out of scope:**
- Any implementation of the changes
- Rebuilding pi-base image or testing `@` popup (prior session's task)
- Any other M2.7 Track A or Track B task

## Confirmed surface area

Design document at `docs/devlog/discussions/design_settings_permissions_group_bind.md` contains the full 14-item file-change inventory with dependency ordering.

**Final solution:** UID Mapping (User Hijack) — Strategy 4 in the story document. The container runs as the host user's UID/GID via build args + compose `user:` override. Universal across WSL, macOS, Windows DD, and CI. Replaces the ACL-based approach from session 20260523-08.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | A design document exists at `docs/devlog/discussions/design_settings_permissions_group_bind.md` covering: problem statement (linked to story doc), design considerations, tradeoffs, final solution with rationale, complete 14-item surface area table, documentation needs, and roadmap task | `read` the design doc | Operator |
| 2 | The design document is internally consistent with `story_linux_filesystem_uid_mismatch.md` — no contradictions in problem description or solution scope | manual comparison | Operator |
| 3 | The design document includes a proposed roadmap task entry for M2.7 Track C that encapsulates the implementation work, referencing the surface area table as the file-change plan | `read` the design doc | Operator |
| 4 | `story_linux_filesystem_uid_mismatch.md` is updated with Strategy 4 (UID Mapping / User Hijack) — full technical spec, platform constraints, implementation steps, pros/cons | `read` the story doc | Operator |

## Hot files

| File | Reason | Status |
|---|---|---|
| `docs/devlog/discussions/design_settings_permissions_group_bind.md` | Design document — final solution, surface area, roadmap task | ✅ Produced |
| `docs/devlog/discussions/story_linux_filesystem_uid_mismatch.md` | Story document — updated with Strategy 4, setgid correction | ✅ Updated |
| `docs/devlog/handovers/20260523-08-impl-acl_permissions_baseline.md` | Retroactive handover for the ACL baseline implementation | ✅ Produced |
| `docs/devlog/handovers/20260523-09-plan-*.md` | This handover — session record | ✅ Updated |
| `docs/devlog/roadmap.md` | Added Track C under M2.7 | ✅ Updated |

## Decisions made this session

| Decision | Rationale |
|---|---|
| **UID Mapping (User Hijack) is the final solution**, replacing ACL approach | Only approach that works across WSL, macOS, Windows DD, and CI. Eliminates ACL fragility entirely. |
| Build args + compose `user:` override (not compose-only or group bind) | Compose-only breaks entrypoint (pre-baked files owned by wrong UID). Group bind fails on macOS/Windows DD. Build args are the only complete solution. |
| Collision handling via `usermod` rename (not `|| true` or user deletion) | Renaming preserves existing user's files; `useradd -u ... || true` leaves no `agentuser` user; deletion breaks packages. |
| Numeric UID/GID in `chown` (not username) | If `useradd` was skipped due to collision, the `agentuser` username does not exist; numeric UID always works. |

## Mid-session findings

| Finding | Triaged to |
|---|---|
| ACL-based approach (Resolution 1) suffers mask throttling, metadata reset, and `/mnt/c/` incompatibility | Already documented in `story_linux_filesystem_uid_mismatch.md` |
| Group bind (Resolution 3) works on WSL but fails on macOS/Windows Docker Desktop | Recorded in design doc rule 2.1 (Platform Portability) |
| UID Mapping requires build pipeline threading (`--build-arg HOST_UID`/`HOST_GID`) | Documented in design doc rule 3 surface area items #9–#11 |
| Base images with pre-existing UID 1000 (node, ubuntu) require collision handling in Dockerfile | Resolved via `usermod` rename pattern, documented in design doc rule 2.4 |
| Setgid bit only covers newly created inodes, not files provisioned via cp -r or mv | Correction applied to design doc rule 8.1, rule 8.2, and story doc Strategy 3 |
| rsync --chmod is the recommended replacement for cp -r during provisioning | Documented in design doc rule 8.2 |

## Completed this session

| File | Change |
|---|---|
| `docs/devlog/discussions/story_linux_filesystem_uid_mismatch.md` | Added Strategy 4 (UID Mapping / User Hijack) with full spec: platform breakdown, Dockerfile with collision handling, compose config, pipeline changes, pros/cons. Updated comparison matrix to 4 columns. Added setgid limitation note to Strategy 3. Updated status to "Resolved via Strategy 4". |
| `docs/devlog/discussions/design_settings_permissions_group_bind.md` | New design document: problem statement, 6 design considerations with tradeoff tables, final solution with rationale, 14-item surface area with dependency ordering, user-facing documentation contract (rule 4 with 5 documentation subsections), roadmap task entry for M2.7 Track C, implementation ACs, supplementary techniques (GID+macOS, rsync provisioning), setgid correction. |
| `docs/devlog/handovers/20260523-08-impl-acl_permissions_baseline.md` | Retroactive handover for the ACL baseline implementation (session 08). |
| `docs/devlog/handovers/20260523-09-plan-settings_mount_permissions_resolution_3_scoping.md` | This handover. |
| `docs/devlog/roadmap.md` | Added Track C — Universal Bind Mount Permission Strategy (UID Mapping) under M2.7 with design reference link. |

## Deferred items

None.

## Next session

Implementation session for the UID Mapping strategy. Priority order:

1. **Build pipeline threading** — `libs/build.sh`: `build_sandbox()` and `build_agent()` accept `--uid HOST_UID --gid HOST_GID` and pass as `--build-arg`. `scripts/start_agent.sh`: export `HOST_UID=$(id -u)`, `HOST_GID=$(id -g)`. No behaviour change yet.
2. **Dockerfile updates** — All 5 Dockerfiles: add `ARG HOST_UID`/`ARG HOST_GID`, collision handling via `usermod` rename, numeric `chown -R`. Parallel across providers.
3. **Compose update** — `libs/docker-compose.yml`: add `user: "${HOST_UID:-1000}:${HOST_GID:-1000}"` to both services. Verify provider overlays don't conflict.
4. **Onboard cleanup** — Only after UID Mapping is verified working: remove `setfacl` lines from `scripts/onboard.sh`.
5. **Documentation** — Per design doc rule 4.5.
6. **Tests** — Switch ACL assertions to UID-based checks.

**Pending operator action:** Confirm the commit sequence (ACL baseline as commit 01, design docs as commit 02, implementation as future commits) and close this session.
