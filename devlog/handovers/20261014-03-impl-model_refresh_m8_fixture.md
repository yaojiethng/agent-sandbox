---
date: 2026-10-14
milestone: T12 - Pi Dependency and Extension Upkeep
type: Implementation
status: Closed
---

# Handover - The model-refresh M8 label fixture

## Objective

Make `tests/test_model_refresh.sh` green by restructuring invariant M8 to test the transport derivation rule with synthetic inputs, replacing the live-catalog-versus-hand-map reconciliation that made the test fail on external data drift.

## Scope

The failing `tests/test_model_refresh.sh` node suite at HEAD, recorded out of scope in handovers `20261014-01` and `20261014-02`, then widened at the scope gate on an operator direction (2026-10-14).

The M8 invariant reconciled three representations of one external fact: a hand-typed copy of models.dev's provider SDK labels, pi's installed baked `opencode-go` catalog, and the extension's `derivedTransport` rule. The label map was measured 2026-10-03; pi's baked catalog (data `generatedAt` 2026-10-12) serves three more ids over `anthropic-messages` than the map labelled, so the derivation fell to the unlabelled `openai-completions` default and the assertion failed on the first id, `claude-haiku-5-5`. The second red unit, the mutation gate's `control:unmutated-mirror`, was downstream: the control row replays the mirror unmutated and expects every case green.

Measured against the live models.dev blob on 2026-10-14, `opencode-go` labels all five anthropic-baked ids `@ai-sdk/anthropic`, and a derivation over all 31 baked ids with the real labels reproduced pi's adapter with zero mismatches, so the extension's rule was correct and the fixture was the defect.

The operator ruled the live-data reconciliation a test-structure defect and chose to remove it rather than refresh the fixture. Its inputs are external and move independently of the code, so it fails on external data drift while the rule stays correct; and it does not guard served behaviour, because a `baked` entry keeps its own adapter through the union's first-wins fold, so the derivation is only reached for an endpoint or models.dev entry. M8 now asserts the rule with synthetic inputs, and an explicit default assertion replaces the coverage the loop gave the unlabelled case. No drift alarm is kept; the residual risk of a models.dev-versus-pi disagreement is already stated in the extension README.

Out of scope: a `test_prune.sh` flake observed once under the default 8-worker parallel run and not reproduced (recorded under Findings).

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| M8 tests the derivation rule with synthetic inputs and no longer reads pi's baked catalog | the M8 case holds no `getBuiltinModels` call | Agent [x] |
| An id no source classifies is asserted to fall to `openai-completions` | the M8 case's fourth assertion | Agent [x] |
| The three M8 mutation rows still turn the suite red | `bash tests/test_model_refresh.sh` green, which the gate reports only when every row is proven | Agent [x] |
| The M8 registration and the README follow the restructure | `grep "transport follows"` in `invariants.ts` and `invariants.test.ts`; the README transport paragraph | Agent [x] |
| `tests/test_model_refresh.sh` is green | `bash tests/test_model_refresh.sh` | Agent [x] |
| `bash scripts/run_tests.sh` is clean | `bash scripts/run_tests.sh` | Agent [x] |
| `bash scripts/lint.sh` is clean | `bash scripts/lint.sh` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`tests/extensions/pi/model-refresh/invariants.test.ts`](../../tests/extensions/pi/model-refresh/invariants.test.ts) | the M8 case; the live-catalog loop and its hand label map are removed and a default assertion added |
| [`tests/extensions/pi/model-refresh/invariants.ts`](../../tests/extensions/pi/model-refresh/invariants.ts) | the M8 name, statement and source, and its `CLASSIFICATION` entry follow the rule test |
| [`model-refresh/README.md`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md) | the transport-tables paragraph now states the rule test and why the live reconciliation is not in the suite |
| [`catalog.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/catalog.ts) | `derivedTransport`, the rule under test; verified correct and not changed |
| [`tests/test_model_refresh.sh`](../../tests/test_model_refresh.sh) | the harness wrapper that runs the node suite and its mutation gate; the failing unit |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Remove the live-catalog reconciliation rather than refresh the label fixture | the reconciliation's inputs are external and move independently of the code, so it fails on drift while the rule is correct; and a baked entry keeps its own adapter, so the loop does not guard served behaviour | this handover; the rule is restated in the extension README |
| No drift alarm for a models.dev-versus-pi disagreement | operator ruling, 2026-10-14; the residual risk is already stated in the extension README | this handover |
| Add an explicit default-to-completions assertion | the removed loop covered every unlabelled baked id implicitly, so the default branch would otherwise be untested | the M8 case |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| `tests/test_prune.sh` unit `test_unknown_args_rejected` failed once in the full 8-worker parallel run, then passed 22/22 in isolation and the suite passed clean on a re-run. A flake outside this iteration's surface; the first observation. Triaged to: [`AGENT_FEEDBACK.md`](../AGENT_FEEDBACK.md), a new entry, because the failure mode differs from the 2026-09-25 deadline-expiry entry. | obstacle | out of scope - AGENT_FEEDBACK.md |

## Completed

| File | Change |
|---|---|
| [`tests/extensions/pi/model-refresh/invariants.test.ts`](../../tests/extensions/pi/model-refresh/invariants.test.ts) | M8 restructured to a synthetic rule test: the live-catalog loop and the hand label map are removed, and the default-to-completions assertion is added |
| [`tests/extensions/pi/model-refresh/invariants.ts`](../../tests/extensions/pi/model-refresh/invariants.ts) | M8 name, statement and source narrowed to the rule, and the `CLASSIFICATION` entry renamed to match |
| [`model-refresh/README.md`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md) | the transport-tables paragraph now describes the rule test and why the live reconciliation is not in the suite |
| [`devlog/AGENT_FEEDBACK.md`](../AGENT_FEEDBACK.md) | new entry: a parallel suite run flaked one unit and it did not reproduce, so the triage is the record and no cause is claimed |
| `devlog/handovers/20261014-03-impl-model_refresh_m8_fixture.md` | this handover |
