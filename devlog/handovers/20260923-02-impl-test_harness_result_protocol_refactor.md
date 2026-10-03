# Agent Handover

**Date:** 2026-09-23
**Milestone:** M3.1 - Backpressure (last open task: Test-suite read-through and mechanism documentation)
**Type:** Implementation (refactor)
**Status:** Closed

## Objective

Run the test-suite complexity audit; land the resolutions the audit surfaced as a refactor of the harness result protocol; produce the read-through phase-1 mechanism write-up documenting the refactored harness.

## Scope

- Code: the result-protocol refactor -- `scripts/run_tests.sh`, `tests/libs/test_common.sh`, `scripts/check_test_liveness.sh`; retire `scripts/check_test_order.sh`; re-anchor `tests/test_runner_selftest.sh`; add the real-path skip test to `tests/test_common_lib.sh`.
- Docs: `docs/development/test_harness_mechanism.md` (new, phase-1 write-up); `docs/development/testing-conventions.md` and `testing_policy.md` aligned; `workflow/coding-agent/audits/test-assertion-sweep-brief.md`.
- Records: `devlog/discussions/20260923-study-active-test_suite_complexity_audit.md` (new); `devlog/roadmap.md` phase-0/1 progress note.

Blockers: none.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | The result protocol has no silent-green path: skip is a warning; counts ride a strictly-validated `UNIT:` report; no-report / zero-unit / malformed / rc-0-no-report are hard failures | suite exit 0 plus manual drift checks (malformed `UNIT:` and old-marker files fail loudly) | accepted |
| 2 | The order gate is retired and `REVERSE_RUN` is gone | `grep -rn "REVERSE_RUN\|check_test_order" tests scripts` (non-historical) empty | accepted |
| 3 | One gate owns the registration contract; the runner has no inline `check_liveness` | `grep -n "check_liveness" scripts/run_tests.sh` | accepted |
| 4 | The mechanism write-up exists at `docs/development/test_harness_mechanism.md` | `ls` | accepted |
| 5 | The audit record exists at `devlog/discussions/20260923-study-active-test_suite_complexity_audit.md` and records all six findings and resolutions | `ls`; operator review | accepted |
| 6 | Markdown and shell gates pass with zero findings | `bash scripts/lint.sh` | accepted |

## Hot files

None.

## Decisions

- The audit's six findings resolve in code this iteration; see the study record.
- Skip is a warning, not a failure (the intended zero-skip model was underbuilt).
- Counts ride a self-describing `UNIT:` report; drift is a loud failure, not a silent zero.
- The registration contract belongs to one gate, not two files.
- The worker-to-parent record is strictly-validated key-value; no version field (same-file handshake, no cross-version risk).

## Findings

| Finding | Type | Impact |
|---|---|---|
| The order gate was a landed-but-unowned leftover; retired | technical finding | resolved this iteration |
| The zero-skip model is intentional; `skip()` was missing and is now implemented | technical finding | resolved this iteration |
| Assertion-vocabulary split is benign; doc-honesty reword only | technical finding | resolved this iteration |
| Marker-grep counting hid a silent-green hazard; counts now ride a validated report | technical finding | resolved this iteration |
| Registration shape duplicated; one gate now owns the contract | technical finding | resolved this iteration |
| Worker-to-parent record positional; now strictly-validated key-value without a version | technical finding | resolved this iteration |
| Operator steering: structural fixes over guards; the mechanism write-up documents the refactored harness; iteration retyped to Implementation (refactor) | steering | this iteration |

## Completed

| File | One-line change summary |
|---|---|
| `tests/libs/test_common.sh` | `skip()` + `SKIP` counter; `test_done` emits `UNIT: pass=... fail=... skip=...`; `REVERSE_RUN`/`_RUN_QUEUE` stripped; assert-helper honesty reword |
| `scripts/run_tests.sh` | counts read a strictly-validated `UNIT:` report; skip-is-WARN; no-report/zero-unit/malformed are hard failures; key-value validated worker record; inline `check_liveness` deleted |
| `scripts/check_test_liveness.sh` | owns the full registration contract (unregistered, dangling, dead-after-`test_done`); accepts a `TESTS_DIR` arg |
| `scripts/check_test_order.sh` | deleted |
| `tests/test_runner_selftest.sh` | cases re-anchored to the report/gate; skip-is-warning; case 3b (rc-0-no-report fails); case 12 to the gate |
| `tests/test_common_lib.sh` | added `test_skip_counts_as_skipped_unit` (hermetic real-path proof) |
| `docs/development/test_harness_mechanism.md` | created: phase-1 mechanism write-up (runner, unit contract, result protocol, gates, selftest) |
| `docs/development/testing-conventions.md`, `testing_policy.md` | order-gate dropped; `skip()` and the `make test` invariant aligned; `UNIT:` channel documented |
| `workflow/coding-agent/audits/test-assertion-sweep-brief.md` | order-gate references dropped |
| `devlog/discussions/20260923-study-active-test_suite_complexity_audit.md` | created: the audit (complection map, F1-F6, resolutions, unknowns) |
| `devlog/roadmap.md` | M3.1 read-through row gains the phase-0/1 progress note |
| `devlog/handovers/20260923-02-impl-test_harness_result_protocol_refactor.md` | this handover |

## Deferred items

None.

## What's Next

M3.1 - Test-suite read-through, phases 2 to 4 (per-file inventory against the fixed frame), one test file per session, captured in a read-through discussion record. Phase 2 is the small `src/libs/*` units (ordering leaf-first). The audit record is the running reference; the mechanism write-up is the phase-1 deliverable.

Roadmap maintenance: the M3.1 read-through row is updated with phase-0/1 progress; it stays open until all four phases land.

Grep at next start: `ls tests/test_*.sh`; `grep -n "read-through" devlog/roadmap.md`.

**Conclusions from this iteration:** the audit surfaced six findings; all six resolved in code. The order gate was retired as a landed-but-unowned leftover; `skip()` was implemented under a warning-not-failure model; the unit-result path now rides a strictly-validated `UNIT:` report and key-value record, so a drift or a silent-green is structurally impossible; one gate owns the registration contract. Phase 0 (audit) and phase 1 (mechanism write-up) of the read-through are done; phases 2 to 4 remain.
