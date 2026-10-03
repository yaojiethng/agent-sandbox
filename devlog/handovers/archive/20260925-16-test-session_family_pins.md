# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Pin the rules the session family's rows name: session inventory, session environment, the autosave save policy, routing, and resume_agent with its suite.

## Scope

Unit U4 of the coverage campaign (roadmap row 83), test files only. Register rows 23, 26, 28, 29, 30, 74, 75, 76, 54, 55, 49, 53, 22, 187, 188, 189, 190, 191, 192, 193, 194, 196.

## Carried forward

| Item | From handover |
|---|---|
| The coverage campaign, unit U4 | [20260925-15-test-confirm_reject_interactive_pins](20260925-15-test-confirm_reject_interactive_pins.md) |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| Each of the nineteen test-class rows is pinned by a unit that fails when its rule is removed | the bites | Agent [x] - twenty rows pinned (the twentieth, row 188, is pinned beside a redundant guard) |
| The resume script is driven as a shipped script, with its forwarded argv observed on the real code | the execution-path helper | Agent [x] |
| Rows 22 and 30 are not test rows and stay open | the register's status | Agent [x] - row 22 is the KV-family design note, row 30 a file-cohesion note |
| Production files are unchanged and byte-identical after every mutation | `git diff` and `cmp` | Agent [x] |
| Lint clean and the suite green | `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | Agent [x] - clean; 861 units, 64 files, 0 failed |

## Hot files

| File | Why in scope |
|---|---|
| [`tests/test_session_inventory.sh`](../../tests/test_session_inventory.sh) | the age and dry-run branches, the identity exports, the container and image names |
| [`tests/test_session_env.sh`](../../tests/test_session_env.sh) | the explicit-argument precedence and the common-init exports |
| [`tests/test_session_save_guard.sh`](../../tests/test_session_save_guard.sh) | the autosave channel, the nothing-to-save verdict, the loop interval |
| [`tests/test_routing.sh`](../../tests/test_routing.sh) | the bundle resolution and the mtime ordering |
| [`tests/test_resume.sh`](../../tests/test_resume.sh) | the picker quit path, the forwarded arguments, the guards, the preflight decision, the workspace directories, the regenerated record |
| `src/libs/session_inventory.sh`, `session_env.sh`, `session_save_policy.sh`, `routing.sh`, and `scripts/resume_agent.sh` | mutation subjects, unmodified |
| [`devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl`](../discussions/20260924-design-active-test_suite_readthrough.jsonl) | twenty rows resolved, one added |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Rows 22 and 30 stay open | row 22 is the KV-family design note and row 30 a file-cohesion note; neither is a coverage gap a unit can pin | the register |
| The redundant picker guard is recorded rather than pinned | the line decides nothing under `set -e` | register row 316 |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The picker call's `\| exit 1` in `resume_agent.sh` is redundant with the script's `set -e`, so no unit can fail on it. | bug | next iteration |
| Row 22's KV-family design row was assigned to a test unit by the campaign's file grouping; design rows must be excluded from coverage units by their `action_kind`. | contradiction | roadmap |

## Completed

| File | Change |
|---|---|
| `tests/test_session_inventory.sh` | units for the age branches, the dry-run skip, the identity exports, and the container and image names |
| `tests/test_session_env.sh` | units for the explicit-argument precedence and the common-init exports |
| `tests/test_session_save_guard.sh` | units for the autosave channel, the nothing-to-save verdict, and the loop interval |
| `tests/test_routing.sh` | units for the bundle resolution and the mtime ordering |
| `tests/test_resume.sh` | an execution-path helper plus units for the picker quit path, the three forwarded arguments, the canonicalisation guard, the guard remedies, the preflight build decision, the workspace directories, and the regenerated record's timestamp |
| `devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl` | twenty rows resolved; row 316 added |
| `devlog/roadmap.md` | row 83 records the slice |

## Deferred items

None beyond the register. Rows 22 and 30 are not test work; row 316 is a code deletion.

## What's Next

Unit U5: the host leaves (prune, onboard, agent-sandbox, install, build, stop, run_agent).

Read at iteration start: this handover, register rows 22, 30 and 316, and roadmap row 83.

**Conclusions from this iteration:** grouping the campaign by subject file pulls in design and organisation notes that share the file, so a unit's row list must be filtered by `action_kind` before work starts.
