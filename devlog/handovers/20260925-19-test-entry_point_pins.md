# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Pin the rules the three entry-point rows name: the agent-sandbox dispatcher, run_agent and start_agent.

## Scope

Unit U7 of the coverage campaign (roadmap row 83), test files only. Register rows 199, 200, 201, 204, 205, 206, 177, 178, 182, 183, 167, 168, 169, 171.

## Carried forward

| Item | From handover |
|---|---|
| The coverage campaign, unit U7 | [20260925-18-test-diff_pipeline_pins](20260925-18-test-diff_pipeline_pins.md) |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| The thirteen test-class rows are pinned by a unit that fails when their rule is removed | the bites | Agent [x] |
| Row 171 stays open | the register | Agent [x] - partial |
| Production files are unchanged | `git diff` and `cmp` | Agent [x] |
| Lint clean and the suite green | both gates | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`tests/test_dispatch.sh`](../../tests/test_dispatch.sh) | the dispatcher's argument and forwarding rules |
| [`tests/test_run_agent.sh`](../../tests/test_run_agent.sh) | the agent-invocation rules; declares `# TEST_DEADLINE: 20` |
| [`tests/test_start_agent.sh`](../../tests/test_start_agent.sh) | the start rules; declares `# TEST_DEADLINE: 15` |
| `scripts/agent-sandbox.sh`, `scripts/run_agent.sh`, `scripts/start_agent.sh` | mutation subjects, unmodified |
| [`devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl`](../discussions/20260924-design-active-test_suite_readthrough.jsonl) | thirteen rows resolved |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Two suites declare a longer deadline | their new units drive the shipped scripts, which costs more wall-clock than the default allows under parallel load | the file headers |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Row 171 is only partially pinnable and stays open. | contradiction | next iteration |

## Completed

| File | Change |
|---|---|
| `tests/test_dispatch.sh`, `tests/test_run_agent.sh`, `tests/test_start_agent.sh` | units for the rules the thirteen rows name, and the two deadline declarations |
| `devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl` | thirteen rows resolved |
| `devlog/roadmap.md` | row 83 records the slice |

## Deferred items

None beyond the register.

## What's Next

Unit U8: the capability and build layer (the entrypoint, compose, the commit hook, snapshot, seed_volume, image).

Read at iteration start: this handover, register row 171, and roadmap row 83.

**Conclusions from this iteration:** the entry points are the densest remaining group; each rule needed the shipped script driven rather than a sourced function.
