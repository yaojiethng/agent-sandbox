# Agent Handover

**Date:** 2026-09-28
**Milestone:** M3 - Autonomous Task Execution, Manual Review Workflow
**Type:** Implementation
**Status:** Closed

## Objective

Close the T1 duplicate-test-name roadmap row: the registration liveness gate must flag a test name that is defined or registered twice, and the runner-contract suite must pin that behavior with a negative fixture test.

## Scope

The T1 row "Duplicate test name check in the registration gate": `scripts/check_test_liveness.sh` gains the duplicate check, `tests/test_runner_contract.sh` gains the negative fixture case, and the roadmap row closes with a landing note. One unit, one commit.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | The gate reports a test name defined twice as `DUPLICATE-DEFINITION` and a name registered twice as `DUPLICATE-REGISTRATION`, each on the raw lists before `sort -u` collapses them | synthetic fixture run | Agent [x] accepted |
| AC2 | A fixture file carrying both duplicate classes fails the gate with rc 1 and both findings named | `test_runner_contract.sh` Case 9 | Agent [x] accepted: 9 passed, 0 failed |
| AC3 | The real suite passes the gate with zero findings (no false positive from the new pass) | `scripts/check_test_liveness.sh` on `tests/` | Agent [x] accepted: 66 files, 0 findings |
| AC4 | The roadmap row closes `[x]` with a landing note naming this handover | read `devlog/roadmap.md`, row 120 | Agent [x] accepted |
| AC5 | Lint clean, suite green, one delivery commit carrying the handover with Status Closed | `lint.sh`, `run_tests.sh`, `git log` | Agent [x] accepted: lint clean, 1002 passed, 0 failed |

## Hot files

| File | Why in scope |
|---|---|
| `scripts/check_test_liveness.sh` | the registration gate gains the duplicate-name check |
| `tests/test_runner_contract.sh` | the gate's registration-contract cases live here; the negative fixture case joins them |
| `devlog/roadmap.md` | the T1 duplicate-check row closes with a landing note |
| `devlog/handovers/archive/20260928-02-impl-duplicate_test_name_check.md` | this handover, rides the commit |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The duplicate pass runs on the raw grep lists before `sort -u` | the membership checks collapse duplicates by construction, so the duplication is invisible against them; checking the raw list first is where the doubled name still exists | this handover |
| `DUPLICATE-DEFINITION` and `DUPLICATE-REGISTRATION` are separate findings | last-definition-wins and run-twice are different failure modes with different causes | `check_test_liveness.sh` |
| The negative fixture lives in `test_runner_contract.sh` | that file already owns the gate's contract cases (membership stability, failing-liveness routing) | this handover |
| Delivery commit typed `fix:` | the gate silently accepted a duplicate; the change corrects that broken behaviour | `git_policy.md`, Active Types |

## Findings

None.

## Completed

| File | Change |
|---|---|
| `scripts/check_test_liveness.sh` | per-file pass gains the `DUPLICATE-DEFINITION` / `DUPLICATE-REGISTRATION` checks on the raw lists; header contract text updated |
| `tests/test_runner_contract.sh` | Case 9 negative fixture: a file defining and registering one name twice fails the gate with both findings named |
| `devlog/roadmap.md` | the duplicate-test-name row closes `[x]` with a landing note |
| `devlog/handovers/archive/20260928-02-impl-duplicate_test_name_check.md` | this handover |

## Deferred items

None.

## What's Next

M3, the T1 rows. The duplicate-check row lands this iteration; the remaining T1 open rows (brief construction, evidence-validation, correction-marker ordering, the scope-to-unit open half) hold the next candidates. The next iteration runs the roadmap maintenance check against the milestone summary table.

**Conclusions from this iteration:** the gate now fails on a name defined or registered twice before the membership checks collapse the lists; the negative fixture lives with the gate's contract tests in `test_runner_contract.sh`; the real suite stays green with zero findings.
