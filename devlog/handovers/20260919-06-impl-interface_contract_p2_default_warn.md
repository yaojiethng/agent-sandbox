# 20260919-06-impl-interface_contract_p2_default_warn

- **Handover:** 20260919-06
- **Type:** Implementation
- **Milestone:** M2.6 / M2.6.7 (Interface Contract Compatibility)
- **Dates:** 2026-09-19
- **Status:** Closed

## What this iteration does

Lands the P2 piece of the interface-contract mechanism (ADR
`interface_contract_compatibility.md`, design `20260919-03`) **default-warn**, so
existing behavior stays intact after the change. The strict flip is deliberately
NOT applied here; it is scheduled for a follow-up iteration.

## Context

The P0 (landed `20260919-04`) declared the version, baked the image label, and
stamped the record, with a warn-only preflight check alongside `container-sig`.
P2 adds the two pieces that complete the mechanism: the one reversible
warn/strict flag, and the agent-entrypoint container<->container check. The
operator directed: land it default-warn so the implementation continues to work
after landing; schedule a next iteration to flip the flag and fix any errors.

## Files in scope

**Code:**

- `src/libs/interface_contract.sh` -- add `interface_contract_strict()` (one
  reversible flag; default warn; runtime override `INTERFACE_CONTRACT_STRICT=0/1`).
- `scripts/build.sh` -- `_check_interface_contract` honors the flag: warn on
  drift/missing-label in the parallel phase, hard refusal (return 1, named
  surface + rebuild remedy) under strict; preflight propagates the refusal.
- `src/reasoning/entrypoint.sh` -- add `_check_container_contract`, the
  container<->container check, called during entrypoint preflight.

**Tests:**

- `tests/test_interface_contract.sh` -- add strict-flag x3 and strict-check x3.
- `tests/test_trace_build.sh` -- add 2 strict assertions.
- `tests/test_reasoner_container_contract.sh` (new) -- container<->container check.

**Docs:**

- `docs/adr/interface_contract_compatibility.md` -- P2 note; status wording.
- `docs/concepts/sandbox_host_interface.md` -- comparison-points wording.
- `docs/architecture/sandbox_lifecycle.md` -- preflight policy wording.
- `devlog/roadmap.md`, `devlog/roadmap_future.md` -- P2 status.

**Not changed (deliberately):** `src/libs/container_sig.sh`,
`scripts/install.sh`, `scripts/prune.sh`, the capability entrypoint, the
`tests/stubs/docker` and `tests/stubs/libs/session_state.sh` fixtures. The
container<->container check needs no new fixture: it sources the real repo lib via
a `CONTRACT_LIB` test seam and reads a fixture `SESSION_STATE`.

## How the container<->container check works

The agent container has no docker socket, so it cannot inspect the sandbox
image directly. It resolves the comparison through the record: the sandbox
writes its own baked `interface_contract_version` into `SESSION_STATE` at init
(`session_state_write_set`); the agent reads that value from
`/home/agentuser/sandbox/.git/SESSION_STATE` (available via `volumes_from:
sandbox`) and compares it against its own baked `interface_contract_version()`.
A definite mismatch means the two images were built from different contract
revisions -- an orchestration error or corrupt state, not ordinary drift.

Behavior table:

| Condition | Warn (default) | Strict |
|---|---|---|
| Agent bake == sandbox record | silent | silent |
| Definite mismatch | WARN, continue | FATAL, hard-stop (exit 1) |
| Record key missing | WARN (pre-record image, upgrade path) | WARN (never block the upgrade path) |
| Record file missing | WARN, continue | WARN (never hard-abort on an unavailable check) |
| Lib unavailable | silent skip | silent skip |

The record-file-missing guard matters: under the entrypoint's `set -euo
pipefail`, an unguarded `while ... < file` read of an absent `SESSION_STATE`
would abort the shell. The guard prevents that.

## Decisions

1. **Default warn.** `interface_contract_strict()` returns 0 unless
   `INTERFACE_CONTRACT_STRICT=1`. The strict flip is a separate iteration.
2. **One reversible flag in the lib.** The flag travels with the cross-context
   lib the same way the version constant does; runtime env override for a
   hand-reversible flip at deploy time.
3. **Strict refusal is a non-zero return** from `_check_interface_contract`,
   propagated by preflight (`|| return 1`), so a preflight caller under the
   fail-closed regime aborts start with the named surface.
4. **Agent check reads the record, not the sandbox image label** -- no docker
   socket in the agent; the record already reflects the sandbox's bake.
5. **Missing record file/key never blocks** -- keeps the pre-record upgrade path
   open and avoids the recorded past failure (start blocked after an old check
   misbehaved).
6. **container<->container check is inert in test/non-container env** -- the
   `CONTRACT_LIB` seam defaults to `/opt/sandbox/lib/interface_contract.sh`
   (absent outside an image), so `_check_container_contract` skips silently there.

## Verification

- Suite: **914/914 across 51 files** (`bash scripts/run_tests.sh`, rc=0). Baseline
  888/888 across 50 files; +26 (15 units in test_reasoner_container_contract +
  3 units + 6 assertions in test_interface_contract + 2 assertions in
  test_trace_build).
- `bash -n` clean on the three code files.
- Parity: `git diff` of `container_sig.sh`, `install.sh`, `prune.sh` empty;
  capability entrypoint + seed_volume untouched. P0/P2 parallel rule held --
  old check not stripped.
- Test liveness: 51 files / 0 findings.
- Live entrypoint test unchanged and green (15/15) -- the added check is inert
  in that env.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| AC1 | `interface_contract_strict()` is the one reversible flag, default warn | [x] |
| AC2 | `_check_interface_contract` warns under default, refuses under strict | [x] (tests) |
| AC3 | Preflight propagates a strict refusal (non-zero) | [x] `\|\| return 1` |
| AC4 | Agent entrypoint container<->container check added; hard-stops under strict, warns under default | [x] (tests) |
| AC5 | Missing record file/key never blocks start | [x] (tests + guard) |
| AC6 | `container-sig` and its tooling untouched | [x] (diff clean) |
| AC7 | Suite green | [x] 914/914 |
| AC8 | Strict flip scheduled as a follow-up iteration, NOT applied here | [x] roadmap |

## What's next

- **Scheduled next iteration: the strict flip.** Flip
  `interface_contract_strict()` default to `1` (and/or the env override in
  production), run the strict-regime live matrix (copy/mount x flatten x
  start/resume/list/prune + deliberately drifted samples that must be refused),
  and fix any errors the strict regime exposes.
- Then **P3**: strip `container-sig` (bake, compare, label injection, tests,
  install `xargs` note; delete `src/libs/container_sig.sh`; rewrite the
  `sandbox_identity.md` interim section; close the drift_state_coherence /
  harness_versioning interim status).
- Operator-run gates carried forward: live dry-run e2e matrix (AC9),
  container<->container live proof in a real two-container run.
