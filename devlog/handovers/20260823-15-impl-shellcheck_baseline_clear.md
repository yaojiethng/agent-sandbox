# Agent Handover

**Date:** 2026-08-23
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Clear the ShellCheck warning baseline recorded at handover `20260823-07` (31 warnings) and flip `scripts/check_lint.sh` from advisory to blocking per its documented flip criterion.

## Background

`check_lint.sh` currently runs ShellCheck in observe-and-report mode; its header documents the criterion for making it a hard gate. Warnings were never cleaned because the baseline predated the lint script.

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | ShellCheck reports zero findings on the linted file set | `check_lint.sh`: 0 warnings across 90 files | accepted |
| AC2 | Lint gate flipped to blocking with rationale documented | exit = warning count; header records history + suppression policy; Makefile comment updated | accepted |
| AC3 | Suite green and deterministic x2 (no behavior change) | 634 tests / 39 files / 0 failed x2 | accepted |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Baseline had drifted to 36 findings (31 at `-07`) from later iterations; counted via gcc format for reliable per-file attribution | measurement note | All cleared; gate now prevents regrowth |
| snapshot.sh SC2064 was an intentional expand-now trap (function-local var must be baked into trap body before return); my first fix (single-quote, deferred resolution) would have leaked the temp file -- caught by checking variable scope before trusting the linter. Suppressed with directive + rationale instead | linter FP class | Documented in check_lint.sh suppression list |
| draft_state.sh SC2034 x8: known printf -v dynamic-target false-positive class, suppressed with targeted directives as pre-agreed | linter FP class | Documented |
| Two dead-code removals surfaced real cruft: unused SCRIPTS assignment in test_dispatch (mock_exec never reads it), unused RC captures in test_common_lib (`&& RC=$? \|\| RC=$?` writes but never reads) | cleanup | Deleted with explanatory comments where intent was non-obvious |
| test_draft_workflow TIME out-var was populated but never asserted -- now asserts non-empty instead of deleting (strengthens the test) | improvement | Applied |

## Completed

| File | Change |
|---|---|
| 27 files across scripts/ src/ tests/ | All 36 findings cleared: SC1090 targeted directives (runtime-resolved sources, -f validated), SC2188 bare redirects -> `: >`, SC2155 split declarations, SC2034 dead vars removed or directive-suppressed, SC2010 ls\|grep -> glob loops, SC2120 dead `"$@"` removed, SC2064/SC2209/SC2125 fixed in place |
| [`scripts/check_lint.sh`](../../scripts/check_lint.sh) | Gate flipped: exits with warning count; header documents history + suppression policy |
| [`Makefile`](../../Makefile) | lint target comment updated to blocking status |

## Deferred items

_(none)_
