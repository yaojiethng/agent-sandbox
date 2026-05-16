# Agent Handover

**Session date:** 2026-05-13
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Study
**Status:** Closed

## Objective

Settle the container-sig design and investigate harness-sig requirements. Both outcomes achieved.

## Scope

**Container-sig: settled.** What to hash (`/opt/sandbox/` + `/opt/workflow/`), where to check (preflight), rebuild trigger (any source file change). Warns, doesn't block.

**Harness-sig: investigation complete — deferred.** Scenarios reframed as broad change classes. Comparison of self-contained binary vs semantic versioning showed both are needed. Preconditions documented in `roadmap_future.md` §Harness Packaging and Versioning.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Container-sig design settled and written to design doc | ✅ |
| 2 | Harness-sig grill outcome — deferral confirmed or design path identified | ✅ |

## Hot files

| File | Why in scope |
|---|---|
| `libs/containers.sh` | Where build functions live — context for container-sig hash targets |
| `scripts/start_agent.sh` | Where preflight checks run — where container-sig check would go |
| `docs/devlog/discussions/design_session_identity_hash_based.md` | Container-sig design added in prior session |
| `docs/devlog/discussions/investigation_harness_sig_requirements.md` | Investigation document to be grilled |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Container-sig hashes the contents of /opt/sandbox/ + /opt/workflow/ at build time | These two directories contain everything the harness bundles. Base image (provider binary, OS) is a separate concern tracked by `--rebuild`. | design doc §Container-sig |
| Container-sig is computed at build time and baked as Docker label | Standard pattern for build-time metadata. Label survives container lifecycle. | design doc §Container-sig |
| Container-sig is checked at preflight by start_agent.sh; warns, doesn't block | A hard gate is too aggressive for development workflows where the operator wants to test without rebuilding. | design doc §Container-sig |

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| Harness-sig scenarios were per-file, not per-class | analysis error | Reframed to broad change classes (script dispatch, lib dispatch, command shape, templates, install contract) |
| Self-contained binary and semver are complementary, not alternatives | scope discovery | Both needed for harness-sig viability. Scoped as standalone future milestone in roadmap_future.md |
| Harness-sig is not M2.7 work | scope change | Moved to roadmap_future.md §Harness Packaging and Versioning. Container-sig stays in M2.7 item 5. |

## Completed this session

| File | Change |
|---|---|
| `docs/devlog/discussions/investigation_harness_sig_requirements.md` | Reframed from per-file scenarios to change class analysis. Added candidate comparison (self-contained binary vs semver). Status → Complete. |
| `docs/devlog/discussions/design_session_identity_hash_based.md` | Harness-sig placeholder replaced with deferral reference to investigation doc and roadmap_future.md |
| `docs/devlog/roadmap_future.md` | Added §Harness Packaging and Versioning with self-contained binary + semver scope |
| `docs/devlog/roadmap.md` | Updated known limitations: harness-sig reference replaced with deferred note to roadmap_future.md |
| `docs/devlog/handovers/20260513-11-plan-rescope_items_1_7.md` | Updated final plan — container-sig design noted, harness-sig removed from scope |
| `docs/devlog/handovers/20260513-12-design-two_sig_model.md` | Deleted (absorbed into handover 13) |

## Deferred items

| Item | Reason |
|---|---|
| Harness-sig design | Deferred pending self-contained binary + semantic versioning. Scoped in roadmap_future.md. Not part of M2.7. |

## Next session

M2.7 item 1 (run_id derivation) or item 7 (context_dir removal) — both are dependency-free and ready to implement.
