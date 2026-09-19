# Agent Handover

**Date:** 2026-09-19
**Milestone:** M2.6 - Session Persistence (M2.6.7 - Interface Contract Compatibility)
**Type:** implementation
**Status:** Closed

## Objective

Land **P0** of the interface-contract version mechanism (design settled
`20260919-03`, ADR `docs/adr/interface_contract_compatibility.md`,
open/pending-impl): `INTERFACE_CONTRACT_VERSION` declared once in
`src/libs/interface_contract.sh`, stamped into tier-3 images at build
(declaration 1) and into the session record (`.compose` label set +
`SESSION_STATE` key, declaration 2), compared by a warn-only preflight check
alongside `container-sig`. `container-sig` is untouched this iteration (P0
parallel rule from the rollover plan).

## Scope (proposed, awaiting confirmation)

- New lib `src/libs/interface_contract.sh`: version constant + comparison
  helpers; registered/sourced where build/start/resume need it.
- `scripts/build.sh`: stamp `agent-sandbox.interface-contract-version` label
  into tier-3 images at build (same injection point as container-sig);
  warn-only `_check_interface_contract` at the same preflight call sites.
- Record stamping: `.compose` label set entry (compose template + compose.sh
  substitution) and a `SESSION_STATE` key via `session_state_write_set`.
- Tests: unit tests for the lib; record-stamp assertions; preflight warn
  behavior (drifted sample warns, aligned sample silent).
- No container-sig removal; no entrypoint check (that is P2, gated behind P1
  live proof); no doc rename (impl-milestone task; confirm below).

## Deferred / out of scope

- P1 live proof (operator-run matrix) - not this iteration.
- P2 flip authoritative + agent-entrypoint container<->container check.
- P3 strip container-sig.
- Doc consolidation (`sandbox_host_correspondence_model.md` ->
  `sandbox_host_interface.md` rename, 17-file propagation; lifecycle doc
  re-scope) - pending operator scope decision below.

## Acceptance criteria (proposed)

| # | Criterion | Status |
|---|---|---|
| AC1 | `src/libs/interface_contract.sh` declares the version; suite tests it | **done** — `interface_contract_version` pinned as positive integer; 9 new units green |
| AC2 | Tier-3 image build stamps the version label | **done** — `build_image` adds `agent-sandbox.interface-contract-version`, same gate as container-sig (tiers 1/2 unchanged) |
| AC3 | Record stamps the version (compose label + SESSION_STATE key) | **done** — x-session-labels entry (compose.sh substitution) + `session_state_write_set` key; compose-gen assertion green |
| AC4 | Preflight warn-only check compares host vs image labels; drifted warns, aligned silent; container-sig untouched | **done** — `_check_interface_contract` at both preflight sites; 3 drift/label states tested (lib + trace_build); prune/install/container_sig.sh untouched |
| AC5 | Suite green (876 baseline + new tests); parity: no behavior change on aligned runs | **done** — **888/888 across 50 files** (+2 assertions in trace_build, +1 in trace_compose_gen, +9 new units) |

## Completed

- `src/libs/interface_contract.sh` (new): `interface_contract_version` (constant, currently 1), `image_contract_version` (baked label via docker), `record_contract_version` (SESSION_STATE stamp, host-readable).
- `scripts/build.sh`: sources the lib; `build_image` stamps `agent-sandbox.interface-contract-version` on tier-3 images; `_check_interface_contract` warn-only at both preflight call sites.
- Record stamping: `docker-compose.yml` x-session-labels entry + `compose.sh` `{{INTERFACE_CONTRACT_VERSION}}` substitution; `session_state_write_set` writes the `interface_contract_version` key; stub mirrors it.
- `tests/stubs/docker`: serves the new label (per-image map + single fallback).
- Tests: `test_interface_contract.sh` (9 units); `test_trace_build.sh` +2 assertions; `test_trace_compose_gen.sh` +1 assertion.
- ADR `interface_contract_compatibility.md`: P0 implementation note added (remains open/pending-impl).

## Findings

- No classes A/B/C this iteration. P0 landed exactly per the settled rollover: `container-sig` bake/check/tests/install-dependency untouched (verified by diff).

## Verification

- Suite **888/888 across 50 files** (baseline 876, +9 units, +3 assertions); run_tests rc=0; lib-liveness 20 libs / 0 orphaned; test-liveness 50 files / 0 findings.
- Parity: aligned contract version stays silent in both `_check_interface_contract` tests; mode overlays inherit the label set from the base (no per-mode redefinition).
- P0 rule: `git diff` of prune.sh / install.sh / container_sig.sh is empty.

## Decisions

- Version constant declared once in `src/libs/interface_contract.sh` (currently `1`); readers for image label and SESSION_STATE stamp.
- P0 parallel: new check warn-only alongside container-sig; P2 flip and P3 strip remain per the settled rollover (operator-released gates).
- Label stamp gated on the container-sig gate (tier-3 only) and inherited from the base compose template by all delivery overlays.

## What's Next
- P1 live proof (operator-run matrix; gates P1/P2 per the design) - ship this P0 first.
- After P1 release: P2 flip authoritative (one reversible flag) + agent-entrypoint container<->container check; then P3 strip container-sig; then the separate doc-consolidation iteration (rename to `sandbox_host_interface.md`).