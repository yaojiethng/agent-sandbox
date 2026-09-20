# 20260919-08-impl-interface_contract_p3_strip

- **Handover:** 20260919-08
- **Type:** Implementation
- **Milestone:** M2.6 / M2.6.7 (Interface Contract Compatibility)
- **Dates:** 2026-09-19
- **Status:** Closed

## What this iteration does

Performs P3 of the interface-contract rollover: strips the retired interim
`container-sig` check and tooling, now that the authoritative
`interface-contract-version` mechanism (P0 + P2, flag removed 20260919-07) is
proven. The design record (`20260919-design-interface_contract_compatibility.md`,
`## Rollover / migration plan`, P3 row) gates this on "zero references to
container-sig remain; suite green".

## P3 boundary (from the settled design)

- Remove `_check_container_sig` and its preflight calls.
- Remove the container-sig label bake + injection (`--label
  agent-sandbox.container-sig=`) in `scripts/build.sh`.
- Remove `container_sig()`, `current_sig()`, `image_baked_sig()`, and the
  `_sandbox_sig_sources` / `_agent_sig_sources` source-list helpers.
- Remove `tests/libs/sig_helpers.sh` and the container-sig test units / stubs.
- Remove the install `xargs` dependency note (`check_gnu_xargs`).
- Delete `src/libs/container_sig.sh`.
- Rewrite the `sandbox_identity.md` interim section.
- Update ADR entries (`drift_state_coherence.md`, `harness_versioning.md`) to
  close the interim status; close the interface-contract ADR.

## Critical finding: `image_digest` stays

`image_digest` (image-ID digest, `sha256:...`) is the *replacement* identity
mechanism -- it is recorded per session by `compose_generate` and verified by
the dry-run digest roundtrip. It is **not** the container-sig label and does
**not** retire in P3. It currently lives inside `container_sig.sh` and reaches
`compose.sh` / `dry_run_record.sh` at runtime because `scripts/build.sh` sources
the whole file.

Deleting `container_sig.sh` literally would break record stamping. Resolution:
relocate `image_digest` into `src/build/image.sh` -- already the image-naming
and identity lib, sourced by `run_agent.sh` (line 50) before `compose.sh` and by
`build.sh` (line 20) before `resume_agent.sh` composes. Then delete
`container_sig.sh`. The three `image_digest` unit tests move with it.

## Files in scope

**Code:**

- `src/build/image.sh` -- add `image_digest` (relocated).
- `scripts/build.sh` -- drop the `container_sig.sh` source, the sig label
  injection, the `provider_sig`/`sandbox_sig` source-sweep computation, the
  `_check_container_sig` calls and function, and the header references.
- `src/libs/container_sig.sh` -- delete (after relocation).
- `scripts/install.sh` -- remove `check_gnu_xargs`, its call, and the header
  xargs / container_sig note.
- `scripts/prune.sh` -- fix the stale comment claiming session_inventory
  sources container_sig.sh.
- `src/libs/interface_contract.sh` -- update the "P3 strips it" doc wording.

**Tests:**

- `tests/libs/sig_helpers.sh` -- delete.
- `tests/stubs/docker` -- remove `_sig_for`, `DOCKER_STUB_IMAGE_SIG_*`, and the
  container-sig label branch (contract label branch stays).
- `tests/test_container_sig.sh` -- delete; the 3 `image_digest` tests move to a
  digest-owning test (or into `test_trace_compose_gen.sh` / a small
  `test_image.sh`).
- `tests/test_dry_run_record.sh` -- source the relocated `image_digest` instead
  of `container_sig.sh`.
- `tests/test_interface_contract.sh`, `tests/test_prune.sh`,
  `tests/test_resume.sh`, `tests/test_trace_build.sh` -- remove sig_helpers/sig
  usage; keep contract-based assertions.

**Docs:**

- `docs/concepts/sandbox_identity.md` -- rewrite the `container-sig` interim
  section (retired) to the interface-contract summary.
- `docs/architecture/sandbox_lifecycle.md` -- drop the `_check_container_sig`
  preflight mention.
- `docs/concepts/sandbox_host_interface.md` -- drop the P3-deferred container-sig
  block (now stripped).
- `docs/adr/drift_state_coherence.md`, `docs/adr/harness_versioning.md` --
  close the container-sig interim status (their `image_digest` duty already
  retired separately; reconcile wording).
- `docs/adr/interface_contract_compatibility.md` -- status to ready / closed
  (mechanism authoritative, container-sig stripped, P3 done).
- `docs/concepts/terminology.md`, `docs/development/host_requirements.md` --
  remove container-sig references / the xargs requirement.
- `devlog/roadmap.md` row 117, `devlog/roadmap_future.md` M2.6.7 --
  mark P3 / M2.6.7 complete when this closes.

**Record docs (retired / frozen, not edited):** settled discussion docs and the
closed handovers that narrate the P0-P2 phases and the rollover plan keep their
container-sig references as committed history.

## Acceptance criteria

| # | Criterion |
|---|---|
| AC1 | Zero references to `container_sig` / `container-sig` / `sig_helpers` remain in active code, tests, and non-record docs |
| AC2 | `src/libs/container_sig.sh` deleted |
| AC3 | `image_digest` relocated to `src/build/image.sh` and its consumers (compose.sh, dry_run_record.sh) still resolve it; digest roundtrip test green |
| AC4 | Install no longer requires GNU xargs for container-sig (xargs check removed) |
| AC5 | container-sig ADR entries closed; interface-contract ADR closed/ready |
| AC6 | Suite green; test liveness 0 findings; tree clean |

## Operator gate (live matrix, P2-completed per 20260919-07)

The P2 strict-regime live run (`INTERFACE_CONTRACT_STRICT=1 REFRESH=1 make start`,
recorded 06/07) is the proof that released this strip. Residual operator-run
matrix items (deliberately drifted non-refreshed sample refused pre-flight;
mixed-build container-to-container hard-stop) stand before P3 per the hard rule,
if not yet run.
