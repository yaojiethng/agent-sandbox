# Agent Handover

**Session date:** 2026-06-11
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Implementation
**Status:** Closed

## Objective

Implement the container-sig component of the two-sig model: compute a hash of the `/opt/sandbox/` + `/opt/workflow/` content at build time, bake as a `agent-sandbox.container-sig` Docker label, and check it at preflight with a warning if stale.

## Scope

1. **Add `container_sig()` function** in `scripts/build.sh` — computes SHA-256 hash of files that map to `/opt/sandbox/` + `/opt/workflow/` in the image. Accepts build-type (sandbox/agent) and provider name.
2. **Update `build_image()`** to accept and inject `--label agent-sandbox.container-sig=<hash>` when building sandbox and tier-3 agent images
3. **Update `preflight()`** in `scripts/build.sh` to read the container-sig label from existing images, re-compute from source, and warn on mismatch
4. **Update `sandbox_identity.md`** — document container-sig derivation and preflight behaviour
5. **Update roadmap** — mark two-sig model (container-sig) complete

**Out of scope:**
- Harness-sig — deferred to future milestone
- Hash computation for tier 1 (shared node base) and tier 2 (provider base) images — they don't carry `/opt/sandbox/` or `/opt/workflow/` content, so they don't need container-sig

## Hot files

| File | Reason |
|---|---|
| `scripts/build.sh` | Add `container_sig()` function, update `build_image()` with label, update `preflight()` with check |
| `docs/concepts/sandbox_identity.md` | Add container-sig derivation doc; clean up stale image naming (SANDBOX_ID no longer in image tags) and the `sanbox_id` typo |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | `build_image()` injects `agent-sandbox.container-sig` label | grep finds `--label "agent-sandbox.container-sig=..."` | ✅ Accepted |
| 2 | `preflight()` warns on mismatch (non-blocking) | `grep "WARNING.*container-sig" scripts/build.sh` finds output | ✅ Accepted |
| 3 | No hard error from container-sig check | `exit` or `return 1` not present in `_check_container_sig` | ✅ Accepted |
| 4 | `sandbox_identity.md` has no stale sanbox_id references | grep empty | ✅ Accepted |
| 5 | Image naming table shows project-only image names | `sandbox-<project>` without suffix | ✅ Accepted |
| 6 | `sandbox_identity.md` documents container-sig | grep returns 3 matches | ✅ Accepted |
| 7 | `build.sh` passes `bash -n` | `bash -n scripts/build.sh` exits 0 | ✅ Accepted |

## Completed this session

| File | Change |
|---|---|
| `scripts/build.sh` | Added `container_sig()` function; updated `build_image()` to inject `agent-sandbox.container-sig` label; updated `build_agent()` tier 3 to compute and pass sig; updated `build_sandbox()` to compute and pass sig; updated `preflight()` with `_check_container_sig()` warning on mismatch |
| `docs/concepts/sandbox_identity.md` | Added container-sig derivation doc; fixed stale image naming table (removed SANDBOX_ID from image names); updated SANDBOX_ID description and consumption table |
| `devlog/roadmap.md` | Marked two-sig model (container-sig) complete |

## Mid-session findings

*None.*

## Deferred items

*None.*

## Next session

Track B remaining items:
- Dual-layer seam testing — subsume docker-dependent tests from `test_capability_layer.sh`
- Generic pre-flight validation in shared entrypoint (Proposal 3)
- Autosave/session-save reliability
- Git diff `--no-renames` index conflict
- Makefile variable or CLI flag for diff type
