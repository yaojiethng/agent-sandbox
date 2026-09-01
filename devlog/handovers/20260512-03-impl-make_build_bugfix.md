# Agent Handover

**Date:** 2026-05-12
**Milestone:** M2 — Reasoning/Capability Layer Separation
**Type:** Implementation
**Status:** Closed

## Objective

Fix the `make build` bug (swapped arguments in `build_agent` call for comma-separated target branch) and streamline the build and rebuild code flows — dropping unused parameters, removing pass-through modules, and consolidating the rebuild decision into a single owner.

## Scope

- Fix bug: swapped `$SANDBOX_DIR` / `$AGENT_SANDBOX_REPO` on `build_agent` call for comma-separated targets.
- Drop `sandbox_dir` arg from `build_sandbox` signature.
- Remove dead `build_all` function.
- Inline `build_container.sh` logic into `build_agent`/`build_sandbox` in `containers.sh`; delete the script.
- Consolidate rebuild logic: remove `rebuild_if_requested()` from `agent-sandbox.sh`, add `rebuild_flags()`, move rebuild block into `start_agent.sh`.
- Update documentation references.
- Add unit tests for argument validation and rebuild flags.

## Completed this session

- `libs/containers.sh`: `build_sandbox` dropped `sandbox_dir` param; `build_all` removed; `build_agent` and `build_sandbox` inlined `build_container.sh` logic (Dockerfile validation, context management, base-skip logic).
- `scripts/agent-sandbox.sh`: Fixed swapped arg bug; all `build_sandbox` callers updated; `rebuild_if_requested` replaced with `rebuild_flags()`.
- `scripts/start_agent.sh`: Added `--rebuild`/`--rebuild-base` flag parsing; rebuild block before preflight.
- `scripts/build_container.sh`: Deleted.
- `tests/test_build_context.sh`: Added argument validation tests; fixture updated for `routing.sh` dep.
- `tests/test_start_agent.sh`: Added rebuild flag parsing tests.
- `docs/operations/provider_onboarding_guide.md`: Updated references.
