# 20260919-07-impl-interface_contract_authoritative

- **Handover:** 20260919-07
- **Type:** Implementation
- **Milestone:** M2.6 / M2.6.7 (Interface Contract Compatibility)
- **Dates:** 2026-09-19
- **Status:** Closed

## What this iteration does

Makes the interface-contract mismatch policy authoritative: strict fail-closed
is now the only behavior. The one reversible warn/strict flag is REMOVED
entirely, not toggled -- there is no `INTERFACE_CONTRACT_STRICT` override and no
`interface_contract_strict()` function. This is the strict flip that
`20260919-06` scheduled, executed by removing the switch rather than flipping
its default.

## Decision

The operator directed: remove the flag entirely rather than keep an override.
Rationale (operator's): an override is a backdoor to the very interface the
contract is protecting, weakens the contract, and grows the maintenance surface.
Live proof had already been run (`INTERFACE_CONTRACT_STRICT=1 REFRESH=1 make
start` succeeded under the strict regime), so the escape hatch had no remaining
use.

## Files in scope

**Code:**

- `src/libs/interface_contract.sh` -- delete `interface_contract_strict()`;
  update the Provides/header comment (self-documenting: authoritative, no
  escape hatch).
- `scripts/build.sh` -- `_check_interface_contract` now refuses unconditionally
  on a drift or missing label (no flag branch); preflight propagates the
  refusal (`|| return 1`).
- `src/reasoning/entrypoint.sh` -- `_check_container_contract` hard-stops
  unconditionally on a definite container<->container mismatch (no flag branch);
  missing record key/file still warns; missing lib skips silently.

**Tests:**

- `tests/test_interface_contract.sh` -- remove the three `interface_contract_strict`
  flag units; rewrite the `_check_interface_contract` tests to assert
  authoritative refusal (no env override).
- `tests/test_trace_build.sh` -- rewrite the interface-contract stub test to
  assert refusal/pass without the env override.
- `tests/test_reasoner_container_contract.sh` -- drop the parallel-warn test;
  mismatch hard-stop is the only mismatch behavior; drop the env override from
  the missing-record tests.

**Docs:**

- `docs/adr/interface_contract_compatibility.md` -- status to authoritative;
  add the 20260919-07 note; update the missing-label edge case (refuses, not
  warns).
- `docs/concepts/sandbox_host_interface.md` -- comparison points to
  authoritative, no flag.
- `docs/architecture/sandbox_lifecycle.md` -- preflight policy wording.
- `devlog/roadmap.md`, `devlog/roadmap_future.md` -- authoritative; P3 next.

**Not changed (deliberately):** container-sig and its tooling (`container_sig.sh`,
`install.sh`, `prune.sh`), the capability entrypoint, the docker/stub fixtures.
Those retire in P3.

## Decision (why remove, not toggle)

Rejected alternative: flip the flag default to strict but keep
`INTERFACE_CONTRACT_STRICT=0` as a hand-reversible escape hatch (proposed
option A in the handover draft). The operator overrode it: any runtime override
is a backdoor. A single default in the lib, with the flag function deleted, is
the smallest surface that keeps the contract authoritative. The pre-flight and
entrypoint enforcement code no longer branches on policy; there is exactly one
behavior.

## Expected post-change behavior

| Condition | Behavior |
|---|---|
| Image label == host constant | preflight passes, silent |
| Image label != host constant | preflight refuses (rc 1, named surface + remedy) |
| Image label missing | preflight refuses (rc 1, named cause + remedy) |
| Agent bake == sandbox record | entrypoint silent |
| Container<->container mismatch | entrypoint hard-stops (FATAL, exit 1) |
| Record key missing | entrypoint warns (upgrade path, never blocks) |
| Record file missing | entrypoint warns (never hard-aborts an unavailable check) |
| Lib unavailable | entrypoint skips silently |

## Verification

- Suite green (expect 912-ish; the flag units are removed and the assert texts
  collapse).
- `bash -n` clean on the three code files.
- Test liveness: 0 findings.
- container-sig / install / prune / capability entrypoint / stubs untouched.
- Operator live proof already accepted: strict-regime start ran clean before
  removal; the remaining live matrix is a deliberately drifted start that must
  refuse pre-flight and a mixed-build container<->container hard-stop.

## Acceptance criteria

| # | Criterion |
|---|---|
| AC1 | `interface_contract_strict()` and every `INTERFACE_CONTRACT_STRICT` branch are deleted (zero references outside closed handovers) |
| AC2 | Preflight refuses on drift/missing label; passes on aligned (default behavior, no override) |
| AC3 | Agent entrypoint hard-stops on container<->container mismatch (default behavior) |
| AC4 | Missing record key/file still warns; missing lib skips (upgrade path preserved) |
| AC5 | container-sig untouched (P3 deferred) |
| AC6 | Suite green; parity checks hold |

## What's next

- **P3 -- strip container-sig**: remove `container_sig` bake + compare, label
  injection, `sig_helpers.sh`, container-sig tests, install `xargs` dependency
  note; delete `src/libs/container_sig.sh`; rewrite the `sandbox_identity.md`
  interim section; close the drift_state_coherence / harness_versioning interim
  status; then close the interface-contract ADR.
- Operator-run gate: live strict matrix incl. a deliberately drifted start that
  must be refused pre-flight, and a mixed-build container<->container hard-stop.
