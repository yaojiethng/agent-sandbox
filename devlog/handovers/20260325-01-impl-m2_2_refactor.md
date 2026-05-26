# Agent Handover

**Session date:** 2026-03-25
**Milestone:** M2.2 — Reasoning Layer Modularisation
**Session type:** Implementation

## Objective
Complete the two refactoring tasks carried from the previous session, and standardise image name derivation across the harness.

## Scope
Refactoring tasks from prior handover Next session:
1. `onboard.sh` — use `containers.sh` naming functions; remove hardcoded name construction
2. `scripts/start_agent.sh` — remove implicit env var dependencies for image names; derive explicitly

A third task emerged during scoping: `build_sandbox.sh` had the same hardcoded `IMAGE_NAME` pattern and was corrected as part of the same pass.

A fourth change emerged from the image name removal: `SANDBOX_IMAGE_NAME` and `AGENT_IMAGE_NAME` were being written to `.env` and validated as required vars in `start_agent.sh`. The decision was made to never store derived image names in `.env` — they are always computed from `PROJECT_NAME` and `PROVIDER_NAME` via `containers.sh`. This required `start_agent.sh` to derive and export both vars explicitly for docker compose after `.env` load.

## Acceptance criteria

- [x] `make dry-run` passes: both containers start, liveness writes to `workspace/output/`, `staged.diff` lands in `.workspace/changes/`, teardown clean
- [x] `scripts/start_agent.sh` contains no compose invocation
- [ ] A second provider can be added under `providers/<n>/` with no changes to `scripts/` or `libs/` — pushed to next session (verified by provider investigations)

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/onboard.sh`](scripts/onboard.sh) | Hardcoded image name construction removed; `AGENT_IMAGE_NAME` and `SANDBOX_IMAGE_NAME` dropped from `.env` generation |
| [`scripts/start_agent.sh`](scripts/start_agent.sh) | `AGENT_IMAGE_NAME` and `SANDBOX_IMAGE_NAME` removed from `REQUIRED_ENV_VARS`; explicit derivation via `containers.sh` added; `containers.sh` sourced earlier |
| [`scripts/build_sandbox.sh`](scripts/build_sandbox.sh) | Hardcoded `IMAGE_NAME` replaced with `sandbox_image_name`; `containers.sh` sourced |
| [`providers/opencode/run.sh`](providers/opencode/run.sh) | `SERVE_PORT` warning added when unset before fallback to default |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| `AGENT_IMAGE_NAME` and `SANDBOX_IMAGE_NAME` never stored in `.env` | Both are deterministically derived from `PROJECT_NAME` and `PROVIDER_NAME` via `containers.sh`; storing them creates coupling and a stale-value risk | This handover |
| Existing `.env` files with stale `AGENT_IMAGE_NAME`/`SANDBOX_IMAGE_NAME` vars left as-is | No `sed -i` deletions — stale vars are harmless; `start_agent.sh` no longer validates or uses them from env | This handover |
| `start_agent.sh` derives and exports both image name vars explicitly after `.env` load | docker compose still needs them in the environment for template interpolation; derivation moved to harness, not onboard time | This handover |
| `SERVE_PORT` stays as an env var read by `run.sh` | Operator-set, not derived; broad export loop already covers it; warning added for unset case | This handover |
| No subshell around export loop or provider dispatch | `start_agent.sh` ends with `exec` — process replacement means exports never leak back to caller's shell | This handover |
| `onboard.sh` multi-provider support deferred | Requires `--provider` flag and per-provider onboard behaviour; depends on provider investigation outcomes | This handover (deferred item) |

## Completed this session

| File | Change |
|---|---|
| `scripts/onboard.sh` | Removed `SANDBOX_IMAGE_NAME` and `AGENT_IMAGE_NAME` local assignments and `.env` heredoc entries |
| `scripts/start_agent.sh` | Removed both image name vars from `REQUIRED_ENV_VARS`; added image name derivation block via `containers.sh`; moved `containers.sh` source earlier; added exec/sourcing note to header |
| `scripts/build_sandbox.sh` | Added `source containers.sh`; replaced hardcoded `IMAGE_NAME` with `sandbox_image_name "$PROJECT_NAME"` |
| `providers/opencode/run.sh` | Added `SERVE_PORT` resolution block with warning on unset; updated header comment |

## Next session
**M2.2 — Reasoning Layer Modularisation — Provider investigations.**

- `onboard.sh` multi-provider support — add `--provider` flag and provider-scoped onboard behaviour (e.g. per-provider `.env` vars, provider-specific template selection). Depends on provider investigation outcomes. 

Refactoring tasks complete. Open provider investigations:
- `investigation_claude_code.md` — Claude Code provider
- `investigation_claude_desktop.md` — Claude Desktop provider

Trigger B does not fire until investigations are resolved and acceptance criterion 3 (second provider verified) is met.

**Watch-out items:**
1. Provider investigations are one document per provider per `investigation_policy.md`. Both can run in parallel sessions.
2. The deferred `onboard.sh` multi-provider task should be scheduled as a follow-on once investigation findings clarify what provider-specific onboard behaviour is needed.
