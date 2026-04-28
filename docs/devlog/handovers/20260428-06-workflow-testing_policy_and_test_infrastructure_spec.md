# Agent Handover

**Session date:** 2026-04-28
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Workflow
**Status:** Closed

## Objective

Evaluate the current `testing_policy.md` against gaps exposed by the apply_workspace refactor, produce an updated policy document, and produce an implementation spec for the test infrastructure improvements recommended during the evaluation.

## Scope

1. `docs/development/testing_policy.md` — add four missing areas: test file self-containment rule, shared fixtures (`tests/lib/`) conventions, unified runner reference, staleness check rule; extend checklists; add Anti-Pattern 4 (cross-test-file sourcing).
2. `spec_test_infrastructure.md` — implementation-ready spec for `scripts/run_tests.sh` and `scripts/check_test_coverage.sh`; pre-commit lint script explicitly descoped with rationale.
3. `docs/development/roadmap.md` — add "Pending — test infrastructure" task group to M2.3; add `make test` acceptance criterion.

## Carried forward

None — this is a standalone workflow session.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | `testing_policy.md` contains a self-containment rule: test files source only from `tests/lib/`, never from other test files | ✅ Accepted |
| 2 | `testing_policy.md` contains a "Shared Fixtures" section documenting `tests/lib/git_fixtures.sh` and `tests/lib/session_fixtures.sh` and their rules | ✅ Accepted |
| 3 | `testing_policy.md` contains a "Running the Test Suite" section referencing `make test` as the required full-suite verification step | ✅ Accepted |
| 4 | `testing_policy.md` contains a "Keeping Tests Current" section with the grep pattern and the staleness rule | ✅ Accepted |
| 5 | Both checklists (new tests, lib/script changes) updated with runner and staleness items | ✅ Accepted |
| 6 | `spec_test_infrastructure.md` produced; acceptance criteria are operator-runnable | ✅ Accepted |
| 7 | Roadmap M2.3 updated with test infrastructure task group and `make test` acceptance criterion | ✅ Accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/development/testing_policy.md`](docs/development/testing_policy.md) | Primary output — policy amendments |
| [`spec_test_infrastructure.md`](docs/discussions/spec_test_infrastructure.md) | New — implementation spec for runner and coverage check |
| [`docs/development/roadmap.md`](docs/development/roadmap.md) | Updated — test infrastructure task group and acceptance criterion added to M2.3 |

## Decisions made this session

| Decision | Rationale |
|---|---|
| Pre-commit lint script descoped | Runner + checklist provide sufficient enforcement at current scale; lint script adds maintenance surface not justified by test suite size |
| Coverage check is informational, not a gate | Human judgement required to assess adequacy; grep output is a prompt, not a verdict |
| `tests/lib/` files must contain helpers only — no test execution | Sourcing a test file executes its tests as a side effect; lib files must be safe to source without side effects |

## Completed this session

| File | Change |
|---|---|
| `docs/development/testing_policy.md` | Added Principle 4 (self-containment); new "Shared Fixtures" section; new "Running the Test Suite" section; new "Keeping Tests Current" section; Anti-Pattern 4 (cross-test-file sourcing); updated test structure template with `tests/lib/` source lines; two new checklists (new tests, lib/script changes) |
| `docs/discussions/spec_test_infrastructure.md` | New — spec for `scripts/run_tests.sh` and `scripts/check_test_coverage.sh`; pre-commit lint descoped with rationale |
| `docs/development/roadmap.md` | Added "Pending — test infrastructure" task group to M2.3; added `make test` acceptance criterion |

## Deferred items

None.

Next session
Milestone: M2.3 — Apply Workflow: Capability Layer Diff Pipeline
Task: Test suite repair
Test suite repair is the immediate next task. Running make test against a broken suite produces noise rather than signal — repair first so the runner has a clean baseline to verify against when test infrastructure is implemented.
Remaining M2.3 task groups in dependency order:

Test suite repair — test_checkpoint.sh (8 failures, worktree scoping regression), test_build_context.sh (missing lib), test_capability_layer.sh (unclear), test_provider_entrypoint.sh (missing env vars). Investigate each independently before fixing — root causes are not confirmed.
Test infrastructure — scripts/run_tests.sh, scripts/check_test_coverage.sh, make test Makefile target. Spec at docs/discussions/spec_test_infrastructure.md. Runner auto-discovers tests/test_*.sh via glob — no hardcoded file list. Coverage check is informational only. Both scripts are independent of each other; implement runner first.
Interactive confirmation flag — --interactive for make apply and make draft

Deferred — link testing_policy.md into repo nav:
docs/development/testing_policy.md exists and is complete but is not linked from any entry-point document. The correct fix is a handoff link in Step 6 of the minor loop table in docs/development/iteration_policy.md — "tests alongside" becomes "tests alongside per testing_policy.md". This is the natural repo nav entry point: the policy is referenced at the moment it is actionable. Apply this change in the test infrastructure session.
Files to read at session start:

tests/test_checkpoint.sh — 8 failures, likely worktree scoping regression in checkpoint_latest
tests/test_build_context.sh — script error; libs/build_context.sh may have been deleted or moved; grep libs/ before assuming

Watch-outs:

Diagnose before fixing — each test file failure may have a different root cause; do not batch-fix without confirming
tests/lib/ directory may not exist yet; it is created as part of test infrastructure, not test suite repair