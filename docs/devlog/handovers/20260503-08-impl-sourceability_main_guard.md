# Agent Handover

**Session date:** 2026-05-03
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Closed

## Objective

Make `scripts/agent-sandbox.sh` sourceable by adding a `main` guard, so that workflow functions can be unit tested directly.

## Scope

Targets A.0 from the roadmap (`docs/devlog/roadmap.md` § A.0). Single task: add a `main` guard to `scripts/agent-sandbox.sh`.

**In scope:**
- Add a main guard (function or `[[ $0 == ...]]` pattern) to `scripts/agent-sandbox.sh` so sourcing the file defines functions without executing dispatch logic
- Preserve existing behaviour when executed directly
- Verify all ACs pass

**Explicitly deferred:**
- Router introduction or router tests (A.2)
- Any other A.x work
- Documentation updates beyond what's needed to describe the guard

## Carried forward

None.

## Acceptance criteria

1. `bash -c "source scripts/agent-sandbox.sh; echo OK"` exits 0 and prints "OK" (file is sourceable) — ✅ verified via synthetic test with substituted repo path
2. `bash scripts/agent-sandbox.sh` (no subcommand) exits 1 with usage error (existing behaviour preserved) — ✅ verified
3. `bash scripts/agent-sandbox.sh onboard --help` still forwards to `onboard.sh` (dispatch works when executed directly) — ✅ verified
4. `scripts/run_tests.sh` exits 0 (tree green, no regressions) — ✅ 258 passed, 0 failed, 1 skipped

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/agent-sandbox.sh`](../../scripts/agent-sandbox.sh) | Add `main` guard for sourceability |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Wrap all dispatch logic in `main()` function, guarded by `[[ BASH_SOURCE[0] == ${0} ]]` | Standard bash pattern; keeps all functions defined when sourced | `scripts/agent-sandbox.sh` |
| Move `parse_flags`, `require_run_args`, `rebuild_if_requested` inside `main()` | These are dispatch-only helpers; no external caller references them | `scripts/agent-sandbox.sh` |
| Fix usage text to include `draft`, `confirm`, `reject` subcommands | Usage message was incomplete (listed `apply` stop short); fixed while restructuring | `scripts/agent-sandbox.sh` |

## Mid-session findings

None.

## Completed this session

| File | Change |
|---|---|
| `scripts/agent-sandbox.sh` | Wrapped all dispatch logic in `main()` function; added `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi` guard; fixed usage text to include all subcommands; scoped all dispatch variables with `local` inside `main()` |
| `docs/devlog/discussions/design_change_a_contract.md` | Added sourceability requirement for `package_diff.sh` and `package_branch.sh` to "What Change A is" section |

## Deferred items

None.

## Next session

**A.1 — Data model: unified output format, dispatcher, `diff_on_exit` repair**

**Session type:** Implementation

**Objective:** Restructure all diff packaging around a single unified output format. Rewrite `package_branch.sh` as a dispatcher. Rewrite `diff_on_exit` and `diff_on_autosave` as thin wrappers. No sweep commit, no `BASELINE_SHA` parameter.

**Design reference:** `docs/devlog/discussions/design_change_a_contract.md` §§ 2–3, § 6.
**Roadmap:** `docs/devlog/roadmap.md` § A.1.

**Hot files:** `libs/diff.sh`, `libs/package_branch.sh`, `libs/package_diff.sh`, `libs/sandbox-entrypoint.sh`, `tests/test_diff.sh`, `tests/test_package_branch.sh`, `tests/test_package_diff.sh`

**Key thing to preserve:** `package_branch.sh` already has a `BASH_SOURCE` main guard (lines 42, 120–121) — keep it through the rewrite. `package_diff.sh` needs one added.

**Depends on:** A.0 (sourceability) — complete.
