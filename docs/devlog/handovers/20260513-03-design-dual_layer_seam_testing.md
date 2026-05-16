# Agent Handover

**Session date:** 2026-05-13
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Design
**Status:** Closed

## Objective

Design a mechanism for dry-run (`make dry-run`) to assert host-container seam behaviour in both the reasoning layer and the capability layer — closing the coverage gap identified in the prior implementation session, where `dry_run.sh` only validates the reasoning layer side of mounts and paths.

## Scope

M2.7 item 11 — Dual-layer seam testing via dry-run. Design only (no implementation). Split the work into five implementable units for subsequent sessions.

- 11a. Design (this session) — settled design document
- 11b. Pre-flight script (critical invariants in sandbox-entrypoint)
- 11c. dry_run_capability.sh (capability layer deep checks, bind-mounted into sandbox)
- 11d. dry_run.sh rewrite (reasoning layer deep checks, bind-mounted into agent)
- 11e. Host-side verification (after both containers, check artifacts landed on host)

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Design document produced at `docs/devlog/discussions/design_dual_layer_seam_testing.md` | ✅ |
| 2 | Five implementation units scoped and sequenced | ✅ |
| 3 | M2.7 item 11 updated in roadmap with sub-items (11a–11e) | ✅ |
| 4 | AGENTS.md injection finding added to roadmap as M2.7 item 12 | ✅ |
| 5 | Design document covers: pre-flight checks, capability checks, reasoning checks, host-side verification, compose overlay changes, orchestration flow | ✅ |

## Hot files

| File | Why in scope |
|---|---|
| `scripts/dry_run.sh` | Current round-trip assertion (reasoning layer only) — to be rewritten in 11d |
| `scripts/dry_run_capability.sh` | **New** — capability layer checks (11c) |
| `libs/sandbox-entrypoint.sh` | Pre-flight checks to be injected (11b) |
| `libs/docker-compose.yml` | Compose template — may need mount changes for AGENTS.md (item 12) |
| `libs/docker-compose.dry-run.yml` | Dry-run overlay — add sandbox bind mount for capability checks (11c) |
| `libs/compose.sh` | `compose_dry_run` orchestration — three-phase execution (11c, 11d, 11e) |
| `tests/test_capability_layer.sh` | Docker-dependent tests to be subsumed into dry-run capability checks |
| `docs/devlog/discussions/design_workspace_path_resolution.md` | Adjacent design doc — path resolution context for seam testing |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Five-session split (11a–11e) instead of monolithic implementation | Each unit is independently implementable and testable. Pre-flight (11b) can land immediately without waiting for dry-run infra. | This handover |
| Pre-flight is injected at end of sandbox-entrypoint, not separate file | Pre-flight and entrypoint are tightly coupled — both need the same env vars and both gate on the same initialisation sequence. A separate file would duplicate source/include boilerplate for no benefit. | This handover |
| AGENTS.md injection is item 12, not part of 11 | It's a separate concern (mount path vs assertion mechanism). Mixing them would expand scope. | roadmap.md item 12 |

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| **AGENTS.md copy into INPUT_DIR is inefficient** — AGENTS.md is copied into `INPUT_DIR/brief.md` by `start_agent.sh` before agent start. This means the brief is a single file read at session init, not available in the agent's working directory for ongoing reference. It should be bind-mounted into the agent's CWD instead. | scope change | Added to roadmap as M2.7 item 12. Fix separately from dual-layer seam testing. |

## Completed this session

| File | Change |
|---|---|
| `docs/devlog/handovers/20260513-03-design-dual_layer_seam_testing.md` | **New** — this handover (Status: Closed) |
| `docs/devlog/discussions/design_dual_layer_seam_testing.md` | **New** — design document for the full dual-layer mechanism |
| `docs/devlog/roadmap.md` | Item 11 restructured into 11a–11e sub-items; new item 12 (AGENTS.md injection) added |

## Deferred items

| Item | Reason |
|---|---|
| AGENTS.md injection path fix (item 12) | Separate concern from seam testing. Documented and scoped. |
| Workspace path refactor (item 10) | Postponed per earlier session. Not blocking dual-layer testing. |

## Next session

**11b. Pre-flight script.** Add critical-invariant checks to `libs/sandbox-entrypoint.sh` after `snapshot_init_git` completes and before the `wait` loop.

Checks:
- CRITICAL: `.git` exists and SESSION_STATE has `init_sha` + `session_ts` (baseline complete)
- CRITICAL: `CHANGES_DIR` writable (session-diffs bind mount functional)
- CRITICAL: `INPUT_DIR` readable (brief mount functional)
- CRITICAL: `OUTPUT_DIR` writable (output mount functional)
- CRITICAL: `SNAPSHOT_DIR` readable (snapshot mount functional)
- WARN: `brief.md` present in `INPUT_DIR` (AGENTS.md was injected)

All CRITICAL failures exit non-zero (container fails healthcheck). WARN failures log but do not exit.

**Design reference:** `docs/devlog/discussions/design_dual_layer_seam_testing.md`

**Conclusions from this session:**
- Dual-layer dry-run splits into: every-start pre-flight (sandbox-entrypoint) + investigation checks (two scripts, one per container) + host-side verification (after both exit).
- AGENTS.md should be bind-mounted into agent CWD, not copied into INPUT_DIR. Filed as item 12.
