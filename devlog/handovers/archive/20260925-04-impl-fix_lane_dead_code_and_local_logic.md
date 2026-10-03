# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Remove the dead code and dead parameters and correct the local logic defects the read-through named in the libraries and the host leaves.

## Scope

Fix lane F3 of the read-through close, 19 assigned rows (4, 10, 11, 24, 25, 27, 35, 36, 41, 46, 47, 50, 56, 100, 106, 123, 130, 156, 157).

## Carried forward

| Item | From handover |
|---|---|
| The dead-code and local-logic rows of the immediate fix lane | roadmap M3.1 (`Read-through close: operator review, then a findings-to-tasks plan session`) |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| The named dead code and dead parameters are gone | grep for each symbol | Agent [x] (`_self_env_dir` and `parse_base_flags` absent) |
| Each behavioural correction is paired with a unit that fails before and passes after | the new and strengthened units | Agent [x] |
| Lint clean and suite green | both runs | Agent [x] (775 units at this unit's close) |

## Hot files

| File | Why in scope |
|---|---|
| `src/libs/env.sh`, `env_resolve.sh`, `common.sh`, `resume_list.sh`, `session_save_policy.sh`, `diff.sh`, `routing.sh`, `interface_contract.sh`, `session_env.sh` | dead code, dead parameters, unreachable arms, local logic |
| `scripts/prune.sh`, `onboard.sh`, `build.sh`, `run_agent.sh`, `start_agent.sh` | host-leaf logic and argument surface |
| `tests/test_env.sh`, `test_routing.sh`, `test_compose_wait.sh`, `test_onboard.sh`, `test_capability_entrypoint_mount.sh`, `test_trace_build.sh`, `test_session_hints.sh` | the units for the above |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Delete `parse_base_flags` and its two units | no caller remains; the leaves parse identity through `cli.sh`'s spec and the dispatcher uses `parse_args_collect` | this handover |
| Reject a boolean flag that carries a value rather than interpreting it | no caller passes such a form; value interpretation would be a separate contract decision | this handover's Findings |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Deleting `parse_base_flags` leaves stale references in files outside this unit: the `start_agent.sh` header comment and the command-flag-parsing ADR. | bug | next iteration |
| The row 41 change contradicts that ADR's bare-value edge case, which says a bare value flag is consumed with an empty value; the ADR needs the matching entry. | contradiction | next iteration |
| Row 46(b)'s boolean-shape choice is not a documented contract; if value interpretation is wanted instead, that is a separate decision. | blocker | next iteration |
| Row 130 needs a decision: the flag-conversion owner is the CLI-to-workflow boundary, and the named ADR entry lives outside this unit. | blocker | next iteration |

## Completed

| File | Change |
|---|---|
| `src/libs/env.sh`, `env_resolve.sh`, `common.sh`, `resume_list.sh` | dead variables, a dead parameter and its branch, and an uncalled parser removed; a dead `CREATION_TS` parameter dropped |
| `src/libs/session_save_policy.sh` | two unreachable `*)` arms removed |
| `src/libs/session_env.sh`, `routing.sh`, `interface_contract.sh`, `diff.sh` | local logic defects and a partial-record resolution corrected |
| `scripts/onboard.sh` | the `rsync --chmod` call corrected and the dead `.env.example` branch removed |
| `scripts/build.sh` | the unnecessary `--sandbox` requirement dropped from the usage text |
| `scripts/run_agent.sh` | the unused `project_name` argument dropped from `compose_sandbox_wait` |
| `scripts/prune.sh`, `scripts/start_agent.sh` | argument-surface and help-surface corrections |
| `tests/test_compose_wait.sh`, `tests/test_session_hints.sh` | new test files |

## Deferred items

None beyond the roadmap; row 130's decision and the ADR entries are recorded in Findings.

## What's Next

The next fix lane: documentation and operator-guidance drift.

**Conclusions from this iteration:** the dead code was invisible to ShellCheck because sourced files may expose top-level variables, so the read-through's per-file read is the only detector this tree has for that class.
