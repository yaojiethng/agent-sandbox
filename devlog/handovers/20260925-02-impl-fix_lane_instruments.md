# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Clear the read-through's instrument fix rows: the test runner and the liveness gate, the guard and lint gates, the dry-run probes, and the Makefile template.

## Scope

Fix lane F1 of the read-through close, 45 assigned rows (267 to 311, plus 21, 33, 45, 135, 262). Rows 267-274 the Makefile template; 275-284 `guards.sh`; 286-291 the lint gate set; 292-303 the dry-run probes; 304-311 the runner.

## Carried forward

| Item | From handover |
|---|---|
| The immediate fix lane of the read-through close | roadmap M3.1 (`Read-through close: operator review, then a findings-to-tasks plan session`) |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| The liveness gate reports its verdict without suppressing a healthy run | `tests/test_runner_selftest.sh` | Agent [x] |
| The stale-lock probe refuses a lock it did not create and names its age and holder | `tests/test_guards.sh` | Agent [x] |
| The Makefile template's undeclared variables and `.PHONY` gaps are corrected | `tests/test_makefile_template.sh` | Agent [x] |
| The runner's fault contracts (deadline, kill, report) are pinned | `tests/test_runner_contract.sh` (new) | Agent [x] |
| Lint clean and suite green | both runs | Agent [x] (782 units, 0 failed, 0 skipped) |

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/run_tests.sh`](../../scripts/run_tests.sh), [`scripts/check_test_liveness.sh`](../../scripts/check_test_liveness.sh) | the runner and the liveness gate |
| [`scripts/guards.sh`](../../scripts/guards.sh) | the stale-lock fail-open and the three refusals |
| [`scripts/check_markdown.sh`](../../scripts/check_markdown.sh), [`scripts/lint.sh`](../../scripts/lint.sh) | the gate set, forwarding and counts |
| [`scripts/dry_run_capability.sh`](../../scripts/dry_run_capability.sh), [`scripts/dry_run_reasoning.sh`](../../scripts/dry_run_reasoning.sh) | the probe checks and the shared preamble |
| [`scripts/templates/Makefile.template`](../../scripts/templates/Makefile.template) | the argument surface |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Fix the liveness gate's abort and reporting path, not its matching mechanism | the false-finding mechanism is load-sensitive and unconfirmed on an idle host | this handover |
| Replace the gate's `printf \| grep -q` membership test with an associative array | the pipeline status is what a `grep -q` consumer that exits early turns into a false not-found under `set -o pipefail` | the runner and its selftest |
| Refuse an unowned lock instead of deleting it | the previous probe failed open when `lsof` was absent, which deleted a live lock | `guards.sh` and its header |

## Findings

| Finding | Type | Impact |
|---|---|---|
| `lsof` is required by the stale-lock probe but was declared in no requirements document; it is now declared in the `guards.sh` header, and the installation requirements document still needs the line. | bug | next iteration |
| `make` is absent from this image, so the Makefile-template rows are pinned by static template reads and must be confirmed with `make` on a host that has it. | blocker | next iteration |
| The Makefile template's argument-conversion owner is a design choice (a 0-aware Make predicate against a Make-layer normalisation); the CLI half lives outside this unit's boundary. | blocker | next iteration |
| Seven assigned rows could not be landed here: 8, 18, 33, 285 and 300 own files outside this unit, and 290 needs a new ADR entry; 45 needs the decision above. | scope change | next iteration |

## Completed

| File | Change |
|---|---|
| `scripts/run_tests.sh`, `scripts/check_test_liveness.sh` | the gate reports its verdict and no longer suppresses a run; the runner's fault contracts pinned |
| `scripts/guards.sh` | the lock probe fails closed and names the age and holder; `lsof` declared; the three refusals made distinguishable |
| `scripts/check_markdown.sh`, `scripts/lint.sh` | gate-set, forwarding, count and run-directory defects |
| `scripts/dry_run_capability.sh`, `scripts/dry_run_reasoning.sh` | the check mechanics, the shared preamble, the marker lifetime |
| `scripts/templates/Makefile.template` | undeclared variables and `.PHONY` gaps |
| `tests/test_runner_contract.sh`, `tests/test_makefile_template.sh` | new test files |
| `tests/test_guards.sh`, `tests/test_lint_umbrella.sh`, `tests/test_runner_selftest.sh`, `tests/test_dry_run_probe.sh`, `tests/test_dry_run_record.sh` | units added or strengthened |

## Deferred items

None beyond the roadmap; the unresolved rows are recorded in Findings.

## What's Next

The next fix lane: the host-eval injection (rows 38 and 242).

**Conclusions from this iteration:** a gate that aborts the whole run on its own verdict is worse than a gate that reports and continues, because one false finding suppresses every real one.
