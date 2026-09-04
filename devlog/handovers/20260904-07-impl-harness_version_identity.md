# Handover 20260904-07 — impl harness version identity (digest, HEAD, symlink)

**Milestone:** M2.6 - Session Persistence
**Type:** impl
**Status:** Closed
**Date:** 2026-09-04

## Objective

Implement the settled harness version identity design (ADR `harness_versioning.md`, 2026-09-01; design `20260831-design-active-image_and_harness_version_identity.md`): per-surface versions — image = docker digest, worktree = git HEAD (no record field), host = symlink install — with the staleness signal retired and the dry-run digest-roundtrip gate.

## Scope

| # | Item | Files |
|---|---|---|
| 1 | Digest stamping: record gains `agent-sandbox.agent-image-digest` + `agent-sandbox.sandbox-image-digest`; `image-sig` label retired from new records | `src/build/docker-compose.yml`, `docker-compose.copy.yml`, `src/build/compose.sh`, `scripts/run_agent.sh` |
| 2 | Retire list-time staleness: `record_image_stale` removed from the `resume LIST` path (kills 2×N docker inspects); recorded digests shown instead | `scripts/resume_agent.sh`, `src/libs/session_inventory.sh`, `src/libs/container_sig.sh` |
| 3 | Prune: image-staleness selection retired (`--stale=image|all` removed; `--stale=sandbox` — worktree HEAD identity — stays) | `scripts/prune.sh` |
| 4 | Dry-run gate: `dry_run_image_verify` becomes the digest roundtrip (running image's digest == record's stamped digest); container-sig recompute leaves the gate | `src/libs/dry_run_record.sh` |
| 5 | Symlink install: `make install` links instead of sed-baked copy; dispatcher self-locates the repo via the resolved symlink | `Makefile`, `scripts/agent-sandbox.sh` |
| 6 | `container-sig` interim role: preflight contract check persists (recompute path kept); image-version and dry-run-gate duty removed | `src/libs/container_sig.sh` |
| 7 | Tests + docs: updated affected tests; `sandbox_identity.md` concept; `project_index.md` | `tests/`, `docs/` |

## Findings

| # | Finding | Status |
|---|---|---|
| F1 | **Design clarification (D2):** the ADR's `<repo>@sha256:` repo-digest exists only for pushed images — locally built, never-pushed images have empty `RepoDigests`. The content-addressed identity for local images is the image ID (`docker inspect .Id` — the config digest, which transitively content-addresses every layer). Implemented with `.Id`; the wiring is identical if the operator prefers post-push repo digests. Clarification recorded in the ADR edge cases. | Resolved (recorded) |
| F2 | `rsync --delete` with `--files-from` cannot remove root-level extraneous destination files (deletion applies only to listed directories). | Resolved (dropped with the mount-path rework, handover 20260904-06) |
| F3 | The list-path rework left `ENV_REL` in `resume_agent.sh` unused (SC2034): the `--env=` flag is accepted for CLI parity and explicitly ignored (`: ;;`). | Resolved |

## Decisions

| # | Decision | Rationale | Source |
|---|---|---|---|
| D1 | Image digest recorded as the image ID digest (`sha256:...` from `docker inspect .Id`), stamped at compose-generation time (post-build) via template substitution. | Post-build timing makes the digest exact for the session; `.Id` is the only docker-native content identity available without a registry push. | F1 |
| D2 | Record digest labels replace `image-sig` forward-only; old records keep their `image-sig` labels (read paths tolerate absence). | ADR: no back-compat; forward-only schema. | ADR |
| D3 | Prune's image-staleness selection is retired with the signal; `--stale=sandbox` (worktree HEAD identity) remains a legitimate exact comparison. | ADR: freshness signal retired; worktree identity is exact, not a drift detector. | ADR |

## Changes

| File | Change |
|---|---|
| `src/build/docker-compose.yml` | `image-sig` label replaced by the two digest labels in the session-labels anchor |
| `src/build/compose.sh` | `{{AGENT_IMAGE_DIGEST}}`/`{{SANDBOX_IMAGE_DIGEST}}` substitutions; digest stamping post-build, hard error when unavailable; phase-3 gate passes record files |
| `src/libs/container_sig.sh` | `image_is_stale` removed; `image_digest` added; `image_baked_sig` reframed for the interim contract check |
| `src/libs/session_inventory.sh` | `record_image_stale` removed |
| `src/libs/dry_run_record.sh` | `dry_run_image_verify` = digest roundtrip (record digest vs image digest), inline label read |
| `scripts/run_agent.sh` | `RESET_VOLUME` exported for the entrypoint's fresh-start message |
| `scripts/resume_agent.sh` | list path: image-staleness column + `[IMAGE_STALE]` marker removed; zero docker calls; `--env=` accepted-and-ignored |
| `scripts/prune.sh` | `--stale=image|all` removed; sandbox-only selection |
| `scripts/build.sh` | `_check_container_sig` reframed as contract-drift check |
| `Makefile` + `scripts/agent-sandbox.sh` | symlink install; self-locating dispatcher (`readlink -f $0`) |
| Tests | stub gains `.Id` digest support; container_sig/session_inventory/dry_run_record/prune/resume/trace tests rewritten for the new contracts; digest-gate tests added |
| Docs | `sandbox_identity.md`, `sandbox_lifecycle.md`, `execution_model.md`, `tool_interface.md`, `system_overview.md`, `quickstart.md`, `e2e-dry-run` doc, `project_index.md`, ADR edge cases |

## Acceptance criteria (pre-close)

| # | Criterion | Status |
|---|---|---|
| AC1 | Fresh session record carries both `*-image-digest` labels; no `image-sig` in new records | done (compose-gen test asserts both labels) |
| AC2 | `make resume LIST=1` performs zero docker calls in the list path | done (`record_image_stale` removed; list reads on-disk labels only) |
| AC3 | Dry-run phase 3 gates on the digest roundtrip | done (3 gate tests: pass/diverge/missing-label) |
| AC4 | `make install` creates a symlink; dispatcher self-locates after `git checkout` of any commit | done (`readlink -f $0` resolution) |
| AC5 | Suite green, lint Clean | done (706/706, lint exit 0) |
| AC6 | Live verification: dry-run phases pass with the roundtrip gate; `make resume LIST=1` snappy | pending (operator) |
