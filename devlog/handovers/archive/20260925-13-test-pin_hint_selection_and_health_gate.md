# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Finish the test-placement work the rectification campaign named as its next slice: pin the export-directory selection rules behind the shutdown hint pair, and pin the sandbox health gate.

## Scope

Register rows 34 and 181 of `devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl`, the two rows the campaign handover (`20260925-12`) deferred to its next slice. Unit U1 of the seven-unit coverage campaign. Test files only; the production files are mutation subjects.

## Carried forward

| Item | From handover |
|---|---|
| Rows 34 and 181 - the campaign's deferred next slice | [20260925-12-test-rectification_campaign](20260925-12-test-rectification_campaign.md) |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| The newest-wins rule is pinned: with two exports for one session the hint names the newer, and removing `\| sort \| tail -n 1` fails a named unit | the bite, then the unit | Agent [x] - PROVEN, `tests/test_run_agent.sh` |
| The session filter is pinned: an export directory for another session is never selected, even when newest, and removing the `-name` filter fails a named unit | the bite, then the unit | Agent [x] - PROVEN, `tests/test_run_agent.sh` |
| The draftability gate reads the selected directory: a newest export holding no `patches/` and no `uncommitted.diff` suppresses the hint even when an older export is draftable, and removing the gate fails a named unit | the bite, then the unit | Agent [x] - PROVEN, `tests/test_run_agent.sh` (plus the session-hint and stop suites) |
| The health gate is pinned: the trace carries no `compose run` of the agent, the refusal names the sandbox container on stderr, and teardown still runs; deleting the `compose_sandbox_wait` call fails a named unit | the bite, then the unit | Agent [x] - PROVEN, `tests/test_run_agent.sh` |
| The hint lines arrive on stdout and the health-gate refusal on stderr | the units' stream assertions | Agent [x] |
| Register rows 34 and 181 read `resolved`, and the roadmap records the slice | the register's `status` field and the roadmap text | Agent [x] |
| Lint clean and the suite green | `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | Agent [x] - clean; 802 units, 64 files, 0 failed |

## Hot files

| File | Why in scope |
|---|---|
| [`tests/test_run_agent.sh`](../../tests/test_run_agent.sh) | holds the hint units and the health-gate unit; the fixtures were the defect |
| [`src/libs/session_hints.sh`](../../src/libs/session_hints.sh) | the three selection rules; a mutation subject, unchanged |
| [`scripts/run_agent.sh`](../../scripts/run_agent.sh) | the `compose_sandbox_wait` call site; a mutation subject, unchanged |
| [`src/build/compose.sh`](../../src/build/compose.sh) | `compose_sandbox_wait`'s refusal text, read to write the assertion |
| [`devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl`](../discussions/20260924-design-active-test_suite_readthrough.jsonl) | the two rows' status write-back |
| [`devlog/roadmap.md`](../roadmap.md) | row 83 records the slice and the unit plan |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The production files are mutation subjects and were restored byte-identical | both rows are coverage gaps: the code is correct, the fixtures were too thin to notice a change | this handover |
| One fixture family holding several export directories, not one fixture per rule | the defect was that every fixture held exactly one directory, so the rules could not disagree | this handover |
| A local helper captures stdout and stderr separately | the existing helpers merged `2>&1`, which is why a hint moved to the wrong stream was unobservable | the test file's helper |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Row 181's defect was a bite already taken: deleting `compose_sandbox_wait` from `run_agent.sh` left the suite green, because the unit asserted only the last trace line. The unit was named for the health gate and never observed it. | bug | current iteration |
| The register named `tests/test_run_agent.sh` for row 34, but the hint units it means live in that file only because the misnamed trace suite merged into it; a reader following the register before this slice would have looked in the removed `tests/test_trace_start.sh`. The path fix landed in the check-in before this iteration. | contradiction | roadmap |
| One markdown-lint failure was in this handover, not the change: a raw pipe inside a code span in a table cell. The pre-commit gate caught it and the pipes are escaped. | bug | current iteration |

## Completed

| File | Change |
|---|---|
| [`tests/test_run_agent.sh`](../../tests/test_run_agent.sh) | three new hint units (newest-wins, the session filter, the draftability gate on the selected directory), the health-gate unit strengthened (no agent `compose run`, the refusal on stderr, teardown kept), a two-stream capture helper, and the file's numbered coverage list updated |
| `devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl` | rows 34 and 181 flipped to `resolved` |
| `devlog/roadmap.md` | row 83 records the slice and the six remaining units |

## Deferred items

None. The six remaining campaign units are named in roadmap row 83.

## What's Next

M3.1 - Backpressure remains active. Unit U2 follows: the diff workflows (draft, apply, confirm, reject, interactive), grouped by subject file.

Read at iteration start: this handover, register rows 34 and 181, and `docs/development/testing_policy.md` section Test Placement.

**Conclusions from this iteration:** a coverage-gap row that names a test file is a statement about the fixture, not the code, so the fix is to make the fixture able to disagree with the code; all four rules here were correct and none needed changing.
