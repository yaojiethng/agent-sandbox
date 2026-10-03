# Agent Handover

**Date:** 2026-09-21
**Milestone:** M3.1 - Backpressure
**Type:** Design
**Status:** Closed

## Objective

Deliver the lint-and-tests-duration investigation as a study discussion: measure the 30s `scripts/lint.sh` run, confirm the staged-file hook scope, and present approaches. No fix without operator input.

## Scope

- Measure the three lint gates separately and the test suite wall time on the 16-core host.
- Confirm the copy-delivery hook lints only staged files, not the repository.
- Investigate why `check_shell.sh` dominates; probe batch vs per-file ShellCheck behavior.
- Write `devlog/discussions/20260921-study-settled-lint_and_tests_duration.md` with findings, open questions, and constraints.
- Roadmap write-back: record the investigation delivery on the "Lint and tests take forever" row, keeping the row open for the operator's approach selection.

**Deferred:** any improvement to the gate or test runner (per the operator's direction, no fix without input). The 8-file strict-mode reconciliation is part of the future fix task.

**Questions:** None for delivery - the approach selection is the operator's, and the study surfaces it as an open question.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | The study measures every lint gate and the test suite separately | read `devlog/discussions/20260921-study-settled-lint_and_tests_duration.md` | Agent [x] -- table in Findings: shell ~30s, markdown ~3s, lib-contract ~0.04s, tests ~37s |
| 2 | The study states whether the staged-file hook re-lints the repository | read the study; live hook evidence in this session's commits | Agent [x] -- confirmed staged-only; hook printed `Linting: 2 files` on the last commit |
| 3 | The study reports the batch-vs-per-file ShellCheck discrepancy with the affected file count | read the study | Agent [x] -- batch ~30s lenient; per-file ~9s serial, ~1.1s `-P16`, 8 files affected |
| 4 | The study presents approaches and open questions and implements nothing | `git diff` shows only the study, the roadmap row, and this handover | Agent [x] -- `git status` shows exactly the three files |
| 5 | The roadmap row records the investigation delivery and stays open | `grep -n "Lint and tests take forever" devlog/roadmap.md` | Agent [x] -- row open at line 71 with the study link |

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/discussions/20260921-study-settled-lint_and_tests_duration.md`](devlog/discussions/20260921-study-settled-lint_and_tests_duration.md) | the study: measurements, approaches, open questions |
| [`devlog/roadmap.md`](devlog/roadmap.md) | investigation delivery recorded on the open row |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The study reports measurements and approaches but implements nothing | the operator's direction: no lint/test fix without input | this handover; the study's Open Questions |
| The batch ShellCheck invocation is the primary subject, with per-file as the sharpest candidate | measurement shows batch ~30s and lenient; per-file ~9s serial and strict | the study, Findings |

## Findings

| Finding | Type | Impact |
|---|---|---|
| `shellcheck` multi-file invocation treats file 1 as the script and the rest as libraries, suppressing script-context warnings (SC2154) on 134 of 135 files | discovery | next iteration - decides the fix shape; 8 files fail per-file strict mode and need reconciliation |
| The ShellCheck gate, not Markdown or lib-contract, dominates the lint total | discovery | current iteration - shapes every approach |
| The test suite cost is wait time (docker stubs, sleeps), not CPU | discovery | separate track, T2-adjacent |

## Completed

| File | Change | Status |
|---|---|---|
| `devlog/handovers/20260921-09-study-lint_and_tests_duration.md` | opened this handover | done |
| `devlog/discussions/20260921-study-settled-lint_and_tests_duration.md` | new study: timed gates, batch-vs-per-file finding, hook-scope confirmation, approaches, open questions | done |
| `devlog/roadmap.md` | "Lint and tests take forever" row records the study delivery, stays open | done |

## Deferred items

None.

## What's Next

M3.1 - Backpressure. Roadmap maintenance: none pending.

The next iteration picks the approach from the study's Open Questions (operator input required before any fix): batch-parallel (small) or strict per-file ShellCheck (medium, includes the 8-file reconciliation). Follow-up watch-outs: (1) per-file strict mode surfaces `SC2154`-class references in 8 files (`scripts/start_agent.sh`, `scripts/workflows/reject.sh`, six tests) that need a real-defect vs sourced-context call per file; (2) parallel gates change lint output ordering; (3) the pre-commit hook stays staged-scoped regardless of the full-gate change.

Feedback-entry disposition at the M3.1 pre-close review (pending): `[O]` library return-not-exit (durable fix landed in `20260921-08`), `[A]` shellcheck-directive (durable fix in the gate and hook), `[A]` doc-format (lint rule row still open), `[A]` record-write-back and `[A]` mechanical-edit families (unchanged).
