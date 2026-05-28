# Agent Handover

**Session date:** 2026-05-28
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Impl
**Status:** Closed

## Objective

Add property-based tests against the now-clean module interfaces from the boundary cleanup (Step 1). Add direct unit tests for `resolve_channel_base_dir` in `test_routing.sh`. Extend existing `test_draft_workflow.sh` coverage to exercise the new `draft_state.sh` module boundaries. No behaviour changes.

## Scope

**In scope:**
- Add dispatch oracle tests: source `agent-sandbox.sh`, mock backend functions, call `main()` with synthetic flag combinations, assert correct functions called with correct args
- Add `test_resolve_channel_base_dir` to `tests/test_routing.sh` — cover all 4 channel names plus invalid input
- Update `tests/test_draft_workflow.sh` source paths to reflect new module layout

**Not in scope:**
- Dispatch model refactor itself (Step 3)
- `parse_flags` extraction
- Interactive/non-interactive duplication removal
- `draft_run` decomposition
- Any other deferred items

**Design questions:** How to mock backend functions for dispatch oracle tests? Three options:
  1. Override expected shell functions (e.g. `build_sandbox() { ... }`) before calling main() — works for functions, not for exec'd scripts
  2. Override expected scripts with mocks on PATH — works for exec'd scripts like stop.sh, start_agent.sh
  3. A combination of both

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | `test_dispatch.sh` exists with dispatch oracle tests for all subcommands | `ls tests/test_dispatch.sh` — file exists | Agent ✅ |
| 2 | Dispatch tests pass: build (default, sandbox, single provider, provider+sandbox, multi-provider), start/serve/dry-run modes, apply with diff/branch/force, confirm with/without target, reject, stop, onboard, unknown subcommand, missing subcommand | `bash tests/test_dispatch.sh` — 21 passed, 0 failed | Agent ✅ |
| 3 | `test_resolve_channel_base_dir` added to `test_routing.sh` covering session, autosave, diffs, bundles, invalid | `bash tests/test_routing.sh` — routing tests pass incl. 5 new base_dir tests | Agent ✅ |
| 4 | No test regressions in full suite | `bash scripts/run_tests.sh` — previous: 357/363, current: 383/389, 0 failed | Agent ✅ |
| 5 | Dispatch oracle tests document a known gap: build without required args does not validate | Read test: `test_build_missing_args` comment says "known gap" | Operator

## Hot files

| File | Why in scope |
|---|---|
| [`tests/test_routing.sh`](../../tests/test_routing.sh) | Add `test_resolve_channel_base_dir` |
| [`tests/test_draft_workflow.sh`](../../tests/test_draft_workflow.sh) | Verify/update source paths for draft_state.sh module split |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Dispatch oracle tests mock at the invocation boundary (functions + exec + scripts) | Current dispatch uses 3 invocation methods; mocks capture all three via function shadowing + source/exec overrides + script PATH intercept | Chat (2026-05-28) |
| Known gap: build case missing --name/--project/--sandbox validation | Documented in test assertion; dispatch refactor should add it | `tests/test_dispatch.sh` test_build_missing_args |
| `exec` can be overridden with a bash function for test purposes | Proven: `exec() { echo ... }` shadows the builtin and captures calls | Proven in test suite |

## Mid-session findings

None.

## Completed this session

| File | Change summary |
|---|---|
| `tests/test_dispatch.sh` | New file — 21 dispatch oracle tests mocking all backend functions and exec'd scripts |
| `tests/test_routing.sh` | Added 5 resolve_channel_base_dir tests (session, autosave, diffs, bundles, invalid) |

## Deferred items

Items deferred from the full redesign plan (future sessions):
- `parse_flags` extraction to `libs/flags.sh` (dispatch refactor)
- Interactive/non-interactive dispatch duplication removal
- `draft_run` decomposition
- `set -euo pipefail` cleanup
- `exec` inconsistency standardisation
- `require_run_args` naming consistency
- Dispatch model refactor (Step 3)

## Next session

M2.7 — Session Identity and Harness Versioning — dispatch model refactor:
- Convert workflow functions (apply_run, draft_run, confirm_run, reject_run) to `exec`'d scripts with `main()` wrappers
- Give `build.sh` a `main()` for the `agent-sandbox build` entry point (with `--targets` plural, `--rebuild` support, proper validation)
- Keep `build_sandbox`, `build_agent`, `preflight` as library functions for `start_agent.sh`
- Add `TARGETS` validation: error on missing --name/--project/--sandbox for build case
- Update `docs/architecture/tool_interface.md` with `TARGETS` semantics

**Conclusions from this session:**
- Dispatch oracle tests created (21 tests, all passing) — provide behaviour oracle before refactor
- resolve_channel_base_dir unit tests added (5 tests, all passing)
- Mock infrastructure proven: function shadowing + source/exec overrides + script PATH intercept works for all 3 invocation methods
- Full test suite: 383/389 passed, 0 failed (up from 357/363 pre-cleanup)
- Known gap documented: build case does not validate --name/--project/--sandbox before proceeding
