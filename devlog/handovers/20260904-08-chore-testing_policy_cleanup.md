# Handover 20260904-08 — chore testing policy cleanup (liveness checks)

**Milestone:** M2.6 - Session Persistence
**Type:** chore
**Status:** Closed
**Date:** 2026-09-04

## Objective

Complete the testing-policy cleanup pass (roadmap task, handover `20260902-01`): mechanical liveness checks for the unit suite.

## Scope

| # | Item | Status |
|---|---|---|
| 1 | `discovery_` prefix retirement — resolved `20260904-06` by removal (both probes retired with the legacy seed pipeline); verified no `discovery_*` files remain | done |
| 2 | `test_list_no_sig_when_field_empty` (register or delete) — verified registered and passing; item already resolved | done |
| 3 | Mechanical liveness checks: `scripts/check_test_liveness.sh` (`make test-liveness`) — registration liveness both directions (defined-but-unregistered, registered-but-undefined), docker stub prerequisite (executable + smoke invocation), stub-lib liveness (referenced libs exist, orphaned libs flagged) | done |
| 4 | Registration rule added to `docs/development/testing_policy.md` (Running the Test Suite) | done |

## Findings

| # | Finding | Status |
|---|---|---|
| F1 | **The liveness check caught real rot on its first run:** 15 `test_container_sig.sh` tests (the entire container-sig/current-sig surface) had lost their `run_test` registrations to the line-range deletions in handover `20260904-06` — silently excluded from the suite since then (the suite still reported green). Registrations restored; suite 709 → 728. This is the exact failure mode the AGENT_FEEDBACK `discovery_` entry described ("a run_test registration was renamed by sed and briefly went missing before the suite caught it") — now caught mechanically before delivery. | Resolved |
| F2 | `test_build_context.sh` registered its tests by direct top-level invocation instead of `run_test` — normalized to the policy (registration liveness is only checkable when registration is uniform). | Resolved |
| F3 | `test_trace_start.sh` had a parameterized helper named in the `test_` namespace (`test_teardown_is_last_compose`) invoked by two registered wrappers — renamed to `assert_teardown_is_last_compose`; the `test_` namespace is reserved for registered tests. | Resolved |
| F4 | `resume_agent.sh` parsed `--env=` into a never-read variable (flag accepted for CLI parity) — now explicitly accepted-and-ignored (`: ;;`), resolving the SC2034 lint warning. | Resolved |

## Decisions

| # | Decision | Rationale | Source |
|---|---|---|---|
| D1 | Liveness is a static checker script (`make test-liveness`), advisory like lib-liveness/smoke — not wired into `run_tests.sh`. | Follows the established checker pattern (check_lib_liveness.sh); the runner's job is execution, static hygiene belongs to the checker family. Operator can promote it to gating later. | This iteration |
| D2 | The `test_` namespace is reserved for registered tests; parameterized helpers use `assert_`/other prefixes. | Makes static registration liveness decidable without flow analysis. | This iteration |

## Acceptance criteria (pre-close)

| # | Criterion | Status |
|---|---|---|
| AC1 | Liveness checker runs clean: 43 files, 0 findings | done |
| AC2 | Recovered registrations execute: suite 728/728 (container-sig surface back in the count) | done |
| AC3 | Docker stub + stub-lib prerequisite liveness enforced | done |
| AC4 | Registration rule documented in testing_policy | done |
| AC5 | Lint Clean | done |
