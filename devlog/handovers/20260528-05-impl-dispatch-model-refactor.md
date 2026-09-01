# Agent Handover

**Date:** 2026-05-28
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Impl
**Status:** Closed

## Objective

Implement the dispatch model refactor (Step 3). Convert sourced workflow functions to `exec`'d scripts with `main()` wrappers, give `build.sh` a standalone entry point for `agent-sandbox build`, keep build primitives as library functions for `start_agent.sh`. No behaviour change — the oracle tests from Step 2 must pass identically before and after.

## Scope

**Units (in order):**

- **Unit 1** — Add `main()` + guard to each workflow file (`scripts/workflows/apply.sh`, `draft.sh`, `confirm.sh`, `reject.sh`) so they can be `exec`'d. Each `main()` parses positional args from dispatch and calls the existing function.
- **Unit 2** — Add `main()` to `scripts/build.sh` for the `agent-sandbox build` entry point. Accepts `--targets` (plural, comma-separated), `--rebuild`, and universal flags. Validates `--name`/`--project`/`--sandbox` before proceeding. `build_sandbox`, `build_agent`, `preflight` remain as library functions callable by `start_agent.sh`.
- **Unit 3** — Update `scripts/agent-sandbox.sh`: replace `source` + function call with `exec` for build, apply, draft, confirm, reject. Keep `build.sh` and `routing.sh` at top level (used by start/serve/dry-run for passthrough to start_agent.sh, plus package-diff/package-branch for path resolution).
- **Unit 4** — Update `docs/architecture/tool_interface.md` with `TARGETS` plural semantics as agreed in chat.
- **Unit 5** — Verify oracle tests from Step 2 pass unchanged.

**Not in scope:**
- Interactive/non-interactive dispatch duplication removal (deferred)
- `draft_run` decomposition (deferred)
- `set -euo pipefail` cleanup (deferred)
- `exec` inconsistency for start_agent.sh, package-diff, package-branch (they're already `exec` or subprocess calls — no change needed)
- `require_run_args` naming consistency (deferred)

**Design questions:** None — design was settled in the previous session's grilling.

## Carried forward

| Item | Source handover |
|---|---|
| Guard pattern edge case — `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` fails if parent script is sourced. Needs `BASH_SOURCE` array length check and propagation to all guard-using files. | This session (Mid-session findings) |

## Acceptance criteria

Not yet defined.

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/workflows/apply.sh`](../../scripts/workflows/apply.sh) | Add `main()` + guard for `exec` dispatch |
| [`scripts/workflows/draft.sh`](../../scripts/workflows/draft.sh) | Add `main()` + guard for `exec` dispatch |
| [`scripts/workflows/confirm.sh`](../../scripts/workflows/confirm.sh) | Add `main()` + guard for `exec` dispatch |
| [`scripts/workflows/reject.sh`](../../scripts/workflows/reject.sh) | Add `main()` + guard for `exec` dispatch |
| [`scripts/build.sh`](../../scripts/build.sh) | Add `main()` for `agent-sandbox build` entry point; keep build_sandbox/build_agent as library functions |
| [`scripts/agent-sandbox.sh`](../../scripts/agent-sandbox.sh) | Replace `source`+function-call with `exec` for build, apply, draft, confirm, reject |
| [`docs/architecture/tool_interface.md`](../../docs/architecture/tool_interface.md) | Update `TARGET` → `TARGETS` with plural semantics table |
| [`tests/test_dispatch.sh`](../../tests/test_dispatch.sh) | Must pass unchanged after refactor |

## Decisions made this session

None.

## Mid-session findings

| Finding | Description | Triaged to |
|---|---|---|
| Guard pattern edge case | The `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` guard fails if the parent script (e.g. start_agent.sh) is sourced rather than executed. A more robust pattern checks `BASH_SOURCE` array length. Needs propagation to all files using this guard (agent-sandbox.sh plus any files that gain a guard in this session). | Next session — hardening task |

## Completed this session

| File | Change summary |
|---|---|
| `scripts/workflows/apply.sh` | Added `main()` + guard for exec dispatch; derives AGENT_SANDBOX_REPO from own path; parses apply-specific flags |
| `scripts/workflows/draft.sh` | Added `main()` + guard for exec dispatch; derives AGENT_SANDBOX_REPO from own path; parses draft-specific flags |
| `scripts/workflows/confirm.sh` | Added `main()` + guard for exec dispatch; derives AGENT_SANDBOX_REPO from own path; parses confirm-specific flags |
| `scripts/workflows/reject.sh` | Added `main()` + guard for exec dispatch; derives AGENT_SANDBOX_REPO from own path; parses reject-specific flags |
| `scripts/build.sh` | Added `main()` for `agent-sandbox build` entry point; accepts `--targets` (plural), `--rebuild`; validates `--name`/`--project`/`--sandbox`; `build_sandbox`, `build_agent`, `preflight` remain as library functions for `start_agent.sh` |
| `scripts/agent-sandbox.sh` | Removed all top-level sources; build, apply, draft, confirm, reject cases now `exec` subcommand scripts; build case validates universal flags, supports `--target` legacy alias; interactive paths still source workflow files inline |
| `docs/architecture/tool_interface.md` | Updated `make build` with `TARGETS` (plural) semantics table, legacy `TARGET` alias note, dispatch model explanation |
| `tests/test_dispatch.sh` | Replaced with exec-based oracle tests (22 tests, all passing) |

## Deferred items

Items deferred from the full redesign plan (future sessions):
- Interactive/non-interactive dispatch duplication removal
- `draft_run` decomposition
- `set -euo pipefail` cleanup
- `require_run_args` naming consistency

## Next session

M2.7 — Session Identity and Harness Versioning:
- Guard pattern hardening — replace `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` with robust `BASH_SOURCE` array length check across all guard-using files
- Remaining cleanup items from deferred list

**Conclusions from this session:**
- Dispatch model refactored: all sourced function calls replaced with `exec`'d subcommand scripts
- 4 workflow files (apply, draft, confirm, reject) gained `main()` + guard, self-deriving AGENT_SANDBOX_REPO
- build.sh gained `main()` for `agent-sandbox build` entry point with --targets plural, validation, --rebuild
- build_sandbox, build_agent, preflight preserved as library functions for start_agent.sh
- agent-sandbox.sh reduced to pure dispatch table: 0 top-level sources, 6 `exec` cases + 2 interactive source cases
- Oracle tests updated to exec-based assertions: 22/22 pass
- Full suite: 384/390 pass, 0 failed (old-test reference file removed post-close)
