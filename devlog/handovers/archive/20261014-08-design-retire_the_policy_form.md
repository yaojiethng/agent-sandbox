---
date: 2026-10-14
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Design
status: Closed
---

# Handover - Retiring the policy form

## Objective

Settle, for each policy, which content is the mechanism, the convention, or the protocol, and where each lands, so the policy form can be retired.

## Scope

The design stage of the roadmap row **Retire the policy form**. The row's end condition: no policy document remains as a form, and each maintenance skill's convention has left its shipped body.

The model is settled. The mechanism lives in the procedure that runs; the convention lives in the project's convention-skill. What is not settled is the per-document content map: which sections move where, and what becomes of each document. That map is this iteration's deliverable, recorded as a design document and an ADR section.

In scope: for each policy in `docs/policies/` and `docs/development/testing_policy.md`, the assignment of its sections to mechanism (the owning procedure), convention (the project's convention-skill), or protocol (a shipped rule); the fate of the document; and the order the implementation runs in.

Out of scope: the prose edits and deletions (the implementation this map guides); `Drop the policy bundle`; the instruction-root reference gate.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every policy's mechanism, convention, and remainder are identified by subtraction | the mapping table in the design document | Operator [x] |
| The fate of each policy document is stated by the remainder rule | the design document | Operator [x] |
| The implementation is ordered, one slice per policy | the design document | Operator [x] |
| The decision is recorded in the ADR | the ADR section | Operator [x] |
| Architecture documents in scope describe the system as built | read the changed sections | Operator [x] |
| `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are clean | run both | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/policies/`](../../../docs/policies/) | the seven policies whose content is mapped |
| [`docs/development/testing_policy.md`](../../../docs/development/testing_policy.md) | a policy outside the policy folder; its scope is a design question |
| [`workflow/coding-agent/skills/`](../../../workflow/coding-agent/skills/) | the procedures that receive the mechanism, and whose convention leaves |
| [`.agents/skills/`](../../../.agents/skills/) | the convention-skills that receive the convention |
| [`docs/adr/coding_agent_project_bindings.md`](../../../docs/adr/coding_agent_project_bindings.md) | the decision is recorded here |
| [`devlog/roadmap.md`](../../roadmap.md) | the row write-back at close |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The split is by subtraction: strip the mechanism and the convention, and the remainder is the rule | a section often carries both at once, so assigning it one label forces an artificial choice | this handover; the ADR |
| A rule a procedure enforces is stated where it is enforced; a rule that binds the procedures keeps a document | the remainder decides the fate, so no extra judgement is needed | this handover; the ADR |
| `iteration_policy` keeps a protocol document; `documentation_policy`'s Communication Standards keep the `communication` standard; the other six dissolve | the invariants bind every runbook, and the standards govern every text, so no single procedure holds either | this handover; the design document; the ADR |
| One slice per policy, ordered `handover_policy` first and `iteration_policy` last | the pattern is set on the most self-contained document, and the protocol moves last | this handover; the design document |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The design doc's policy-split table predates the convention-skill decision: it says the convention "shrinks to a binding value with a workflow default", which the convention-skill handoff supersedes. | contradiction | current iteration |
| The parallel suite's per-file deadline flaked again: one run reported two expiries (`test_dry_run_probe.sh`, `test_lint_umbrella.sh`), both passing standalone and the next run green. A recurrence of the `2026-10-03` deadline entry. | obstacle | next iteration; Triaged to: `AGENT_FEEDBACK.md` |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../../roadmap.md) | roadmap maintenance check: the roadmap reflects the close of handover `20261014-07`; M3.3.1 is `In progress`. No maintenance edit was needed. |
| [`devlog/discussions/20261014-design-settled-retire_the_policy_form.md`](../../discussions/20261014-design-settled-retire_the_policy_form.md) | new: the per-policy mechanism/convention/remainder map, the fates and the order |
| [`docs/adr/coding_agent_project_bindings.md`](../../../docs/adr/coding_agent_project_bindings.md) | new dated section: the policy form is retired by subtraction |
