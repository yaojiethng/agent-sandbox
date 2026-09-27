# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Workflow
**Status:** Closed

## Objective

Record the disposition for a bite that survives because the line it targets has no effect on behaviour, and the measurement that shows no gate can cover the class.

## Scope

Two files: the bite requirement and glossary in the read-through brief, and one entry in the feedback record. No code, no tests.

## Carried forward

| Item | From handover |
|---|---|
| The bite-disposition defect the coverage campaign found in three units | [20260925-21-test-config_cli_and_stub_pins](20260925-21-test-config_cli_and_stub_pins.md) |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| The brief classifies a surviving bite into a coverage gap or a code row | the brief's bite requirement and its glossary row | Agent [x] |
| The classification is decidable by running a command, not by argument | the one-liner in the brief prints nothing and exits 1 | Agent [x] |
| The class has one feedback entry carrying the gate measurement | `devlog/AGENT_FEEDBACK.md` | Agent [x] |
| Lint clean | `bash scripts/lint.sh` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`workflow/coding-agent/prompts/read-through-run.md`](../../workflow/coding-agent/prompts/read-through-run.md) | the bite requirement and the glossary: the disposition rule |
| [`devlog/AGENT_FEEDBACK.md`](../AGENT_FEEDBACK.md) | the class entry, with the three mechanisms and the gate probe |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| No gate for the class | SC2317 does not exist in the pinned shellcheck 0.9.0, the adjacent optional check `check-set-e-suppressed` returns zero findings, and SC2320 is already on at warning severity and does not fire | the feedback entry |
| The disposition lives in the read-through brief, and the review-pass mutation step will cite it | the review-pass template has no mutation step yet; roadmap row 103 owns adding it | the feedback entry's `scoped` field |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The probe could not be taken as intended: shellcheck 0.9.0 has no SC2317, so the measurement that would justify a gate does not exist until the pinned version is upgraded. | contradiction | roadmap |
| The three instances are register rows 313, 314 and 316, all open and all deletions, so they belong to a `fix:` unit rather than a test unit. | steering | next iteration |
| Expressing the row-selection rule as a runnable snippet in the fan-out brief is adjacent work and was not done here. | scope change | next iteration |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/read-through-run.md` | the bite requirement now classifies a surviving mutation; the glossary's `survived` row states the same |
| `devlog/AGENT_FEEDBACK.md` | one `[A]` entry: the three mechanisms, the errexit reasoning, and the gate probe |

## Deferred items

None. Roadmap row 103 owns the review-pass mutation step.

## What's Next

The `fix:` lane: register rows 313, 314 and 316 are three one-line deletions, and row 315 is the record key-injection defect.

Read at iteration start: this handover, the brief's bite requirement, and the feedback entry.

**Conclusions from this iteration:** the class has no gate and will not get one from the pinned toolchain; the disposition rule is the whole mitigation, so the brief is the load-bearing artifact.
