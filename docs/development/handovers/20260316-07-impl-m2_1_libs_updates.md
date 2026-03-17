# Agent Handover

**Session date:** 2026-03-16
**Milestone:** M2.1 — General Capability Layer Prototype
**Session type:** Implementation

## Objective
Audit and update `libs/` files and their tests for M2.1 two-container model compatibility.

## Scope
Libs-only: `diff.sh`, `image.sh`, `snapshot.sh` and their test files. All other M2.1 implementation task groups deferred to next session.

## Acceptance criteria
- `diff.sh` references `sandbox-entrypoint.sh` (capability layer), not `container-entrypoint.sh` — **accepted**
- `snapshot.sh` already references `sandbox-entrypoint.sh`, all paths are argument-based — **accepted (no change needed)**
- `image.sh` interface already accepts absolute `IMAGE_FILES_TXT` path, compatible with two-image staleness — **accepted (no change needed)**
- `test_image.sh` calls match current `image_compute_digest` signature (absolute path, not provider name) — **accepted**
- `test_image.sh` fixture `image-files.txt` paths resolve correctly against `base_dir` logic — **accepted**
- `test_diff.sh`, `test_snapshot_host.sh`, `test_snapshot_container.sh` — no changes needed, confirmed by grep — **accepted**

## Hot files

| File | Why in scope |
|---|---|
| [`libs/diff.sh`](libs/diff.sh) | Comment update: entrypoint reference |
| [`tests/test_image.sh`](tests/test_image.sh) | Signature fix + fixture path fix |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| `snapshot.sh` needs no changes | Header already correct, all paths are args — no hardcoded dir names | This handover |
| `image.sh` needs no functional changes | Interface already takes absolute `IMAGE_FILES_TXT` path; two-image staleness is a caller concern | This handover |
| `test_image.sh` was stale against `image.sh` interface | Tests passed provider name string where function expects absolute path; fixture paths used repo-root-relative where function resolves file-location-relative | This handover |
| `handover_policy.md` missing roadmap handoff at session close | Agent following handover population rules at close missed the parallel roadmap update because the handoff only existed in `iteration_policy.md` Step 8 | `handover_policy.md`, `agent_context_brief.md` |

## Completed this session

| File | Change |
|---|---|
| `libs/diff.sh` | 3 comment lines: `container-entrypoint.sh` → `sandbox-entrypoint.sh (capability layer)` |
| `tests/test_image.sh` | All `image_compute_digest` calls updated from `"opencode"` to absolute `image-files.txt` path; fixture paths fixed to file-location-relative; stale `PROVIDER` label → `IMAGE_FILES_TXT` |
| `docs/operations/handover_policy.md` | Added roadmap update handoff as first item in "At session close (Step 8)" population rules |
| `agent_context_brief.md` | Broadened `iteration_policy.md` trigger to include any session (minor loop open/close) |
| `roadmap.md` | Marked `snapshot.sh` and `diff.sh` tasks complete; noted `image.sh` tests updated |

## Deferred items

| Item | Reason | Next |
|---|---|---|
| Capability layer container (Dockerfile, entrypoint) | Out of session scope — libs only this session | Next session |
| Reasoning layer container (Dockerfile changes, `container-entrypoint.sh` elimination decision) | Out of session scope | Next session |
| Orchestration & lifecycle (compose files, `start_agent.sh` rewrite) | Out of session scope | Next session |
| Path alignment in `start_agent.sh` (`.agent-input/` → `.snapshot/`) | Caller-side change, not libs | Next session |
| Build & staleness (two-image `image-files.txt` split, per-image rebuild dispatch) | Caller-side change in `start_agent.sh` / `build_agent.sh` | Next session |
| Dry-run update (`scripts/dry_run.sh`) | Out of session scope | Next session |
| Validation (end-to-end test) | Requires all containers built | Next session |

## Next session
**M2.1 — General Capability Layer Prototype** (continue implementation).

All libs are confirmed ready. Next session scope: **capability layer container only** — Dockerfile and entrypoint. This layer is self-contained and can be built, run, and tested standalone before any reasoning layer or orchestration changes.

**Scope:**
1. `libs/_template/dockerfile-default.sandbox` — capability layer Dockerfile template
2. `scripts/sandbox-entrypoint.sh` — capability layer entrypoint (sources `snapshot.sh` and `diff.sh`; runs entrypoint sequence per `execution_model.md`)
3. Manual test: build image, `docker run` with mounted `.snapshot/` and `.workspace/`, verify `staged.diff` output

**Rationale:** The capability layer has no dependency on the reasoning layer, compose, or `start_agent.sh`. Proving it standalone first means the migration plan falls into place: clean up the current combined container to be reasoning-layer-only, then integrate with the proven capability layer.

**Remaining M2.1 tasks (return to roadmap for scoping after capability layer is proven):**
- Reasoning layer Dockerfile changes
- `container-entrypoint.sh` elimination decision
- Docker Compose files (dogfood first, then template)
- `start_agent.sh` rewrite for two-container lifecycle
- Two-image staleness dispatch in build/start scripts
- `scripts/dry_run.sh` two-container update
- Path alignment in callers (`.agent-input/` → `.snapshot/`)
- End-to-end validation

**Watch-out items:**
1. Capability layer `sandbox/` path is `/home/agentuser/sandbox/` — per `execution_model.md`
2. Entrypoint must register EXIT trap before `wait` — diff pipeline runs on any exit
