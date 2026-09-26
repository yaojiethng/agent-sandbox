# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Pin the rules the host leaf rows name: prune, onboard, install, build, stop, and the two suite defects in the dispatch and onboard suites.

## Scope

Unit U5 of the coverage campaign (roadmap row 83), test files only. Register rows 139-144, 153, 154, 158-161, 128, 129, 125, 131, 133, 163, 202, 208. Row 121 is a code row and was excluded.

## Carried forward

| Item | From handover |
|---|---|
| The coverage campaign, unit U5 | [20260925-16-test-session_family_pins](20260925-16-test-session_family_pins.md) |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| Eighteen of the twenty rows are pinned by a unit that fails when its rule is removed | the bites | Agent [x] - twenty-seven bites, none survived |
| Row 161's rule is a production change, not a test gap | the register | Agent [x] - left open |
| Row 129 is only partially pinnable | the register | Agent [x] - left open, partial |
| Production files are unchanged and byte-identical after every mutation | `git diff` and `cmp` | Agent [x] |
| Lint clean and the suite green | `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | Agent [x] - clean; 890 units, 64 files, 0 failed |

## Hot files

| File | Why in scope |
|---|---|
| [`tests/test_prune.sh`](../../tests/test_prune.sh) | the orphan-discovery and refusal rules |
| [`tests/test_onboard.sh`](../../tests/test_onboard.sh) | the confirmation and tree rules; declares `# TEST_DEADLINE: 15` |
| [`tests/test_install.sh`](../../tests/test_install.sh), [`tests/test_trace_build.sh`](../../tests/test_trace_build.sh), [`tests/test_trace_stop.sh`](../../tests/test_trace_stop.sh) | the install and build-layer rules, and the stop refusal |
| [`tests/test_dispatch.sh`](../../tests/test_dispatch.sh) | the dispatcher's self-location and forwarding rules |
| `scripts/prune.sh`, `onboard.sh`, `install.sh`, `build.sh`, `stop.sh` | mutation subjects, unmodified |
| [`devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl`](../discussions/20260924-design-active-test_suite_readthrough.jsonl) | eighteen rows resolved, one added |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Row 121 is excluded from a test unit | its `action_kind` is `code`: the behaviour and its documentation disagree, so it needs the change, not a unit | this handover |
| `tests/test_onboard.sh` declares `# TEST_DEADLINE: 15` | its pty-driven units and repeated onboarding runs exceed the suite default under parallel load | the file header |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Row 161 needs a production change; it stays open as a code row. | bug | next iteration |
| Row 129's rule is only partially pinnable; the remainder stays open. | contradiction | next iteration |
| The dispatch suite's `source_harness` sources the dispatcher, which sets `-e` mid-file, so errexit leaks into every later unit of that file. The same class as row 163, outside its assigned file. | bug | next iteration |

## Completed

| File | Change |
|---|---|
| `tests/test_prune.sh`, `test_onboard.sh`, `test_install.sh`, `test_trace_build.sh`, `test_trace_stop.sh`, `test_dispatch.sh` | units for the rules the eighteen rows name |
| `devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl` | eighteen rows resolved; row 317 added |
| `devlog/roadmap.md` | row 83 records the slice |

## Deferred items

None beyond the register: rows 129 and 161 stay open, and row 317 records the errexit leak.

## What's Next

Unit U6: the agent-sandbox dispatcher and the run_agent suite together, then the capability and build layer.

Read at iteration start: this handover, register rows 129, 161 and 317, and roadmap row 83.

**Conclusions from this iteration:** two rows in a test-class batch were not test gaps at all, so the batch's row list must be split by `action_kind` before dispatch, the same lesson unit U4 recorded.
