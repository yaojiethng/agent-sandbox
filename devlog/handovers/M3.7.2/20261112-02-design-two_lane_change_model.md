---
date: 2026-11-12
milestone: M3.7.2 - The change model and its refinements
type: Design
status: Closed
---

# Handover - The change model is two lanes

## Objective

Reframe the change model as two lanes with the bundle and draft worktree as
the handoff, evidence every transition, and model delivery as a parameter of
the agent lane.

## Scope

The reference, its TLA+ appendix, the ADR, the transition-table gate and the
delivery matrix. Out of scope: the convention's history-as-commons rewrite,
the prompt retirement and the carrier sweep, the model's placement beside the
tests, the unified fork-to-deletion lifecycle, recovery and the concluded
record's retirement.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The reference and TLA+ show the agent and host lanes, the bundle and draft handoff, and the delivery parameter. | The reference's lane table and the TLA+ `lane` variable | Agent [x] |
| Every transition has an id, lane, actor, event, guard, invariant, a falsifiable case including the blocked path, and a mutation row; the table and chart agree. | `scripts/check_change_model.sh` and the table | Agent [x] |
| The gate fails on a missing row or an unlabelled actor. | `tests/test_change_model.sh` mutates the fixture and asserts the failure | Agent [x] |
| The delivery matrix runs the same pipeline transitions for copy and mount, full and flatten. | `tests/test_change_model_delivery.sh` | Agent [x] |
| The host lane models operator-led git and the reject-and-redraft remediation, and a manual host row names its remediation. | The transition table and the gate | Agent [x] |
| The ADR carries a dated entry for the two lanes, the operator-led git and the remediation. | The ADR's 2026-11-12 entry; the prompt retirement and the carrier sweep are B3 and B6, open | Pushed (B3, B6) |
| TLC reaches the recorded states and the invariants hold. | The statechart skill's TLC runner; not run: this container has no Java, TLC or TypeScript runner | Pushed |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The host lane is the operator's and includes raw git; a mistake is remediated by `make reject` then `make draft`. | The operator does run git; a model that denies it is false, and the existing verbs compose the repair. | The ADR's 2026-11-12 entry |
| Delivery is a parameter of the agent lane's entry, not a second pipeline. | The diff pipeline is delivery-indifferent; copy and mount change the workspace and the visibility assertions. | The ADR's 2026-11-12 entry; the reference |
| The prompts are not retired in this iteration. | A prompt that mirrors a host verb is a second surface, but the prepare artifact does not exist yet; retiring them first would leave an undefined primitive. | The roadmap B3; this record |
| The prompt retirement, the model's placement and the unified lifecycle are separate rows. | Each lands its own implementation; the model commit does not decide them. | The roadmap; the plan handover's finding |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| TLC is not available in this container: no Java, TLC or TypeScript runner. | environment | the TLA+ appendix is not machine-checked here; the table/chart gate is the mechanical check | the next environment with the runner; the operator |
| The delivery matrix exercises the shared `snapshot_deliver` under the four entry labels; the container-level volume/worktree mechanics stay in the entrypoint tests. | scope | the matrix proves the diff is delivery-independent, not the bind/volume plumbing | this record; `test_capability_entrypoint_mount.sh` |
| The model commit retired the two prompts before a prepare artifact existed. | process | the prompts are restored, B3 and B6 are reopened, and the retirement is left to the row that lands the prepare artifact | the roadmap B3 and B6; the plan handover's finding |

## Completed

| File | One-line change summary |
|---|---|
| `docs/reference/change_model.md` | the two lanes, the delivery parameter, the operator-git remediation, the transition table, the chart and the TLA+ |
| `docs/adr/change_model.md` | R6 and R7, and the 2026-11-12 entry |
| `scripts/check_change_model.sh` | the change model gate |
| `scripts/lint/change_model.mjs` | the table/chart/catalog scanner |
| `scripts/lint.sh` | the gate in the umbrella |
| `tests/test_change_model.sh` | the gate's fixture and real-tree cases |
| `tests/test_change_model_delivery.sh` | the delivery matrix |
| `devlog/roadmap.md` | the model and delivery rows closed; B3 and B6 reopened; the model-placement and unified-lifecycle rows added; B5 re-scoped |
| `devlog/handovers/M3.7.2/20261112-01-plan-open_m3_7_2.md` | the scope finding |
| `devlog/handovers/M3.7.2/20261112-02-design-two_lane_change_model.md` | this record |
