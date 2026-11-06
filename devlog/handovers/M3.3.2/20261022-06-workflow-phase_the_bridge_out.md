---
date: 2026-10-22
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - Phase the testing bridge out

## Objective

Delete the two emptied testing bridge documents, retarget the records that still name them, and close the `Retire testing_policy` slice and the membership row.

## Scope

Continues the `Retire testing_policy` slice under `Retire the policy form`, unit 3 of three, after the content moves at handovers `20261022-02` and `20261022-05`.

In scope: deleting `docs/development/testing_policy.md` and `docs/development/testing-conventions.md`; retargeting the two audit records that still name them; closing the unit row, the `Retire testing_policy` parent, the policy-member row, and the slice and sequencing text in the roadmap.

Out of scope: the `adr_policy` slice, next in the sequence; the historical citations in `devlog/` records and the archive, which state what was true when written.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Both files are deleted | `test ! -e docs/development/testing_policy.md` and the same for `testing-conventions.md` | Agent [x] |
| No instruction or code surface names either file | `grep -rln` both names across `docs scripts tests workflow src .agents` prints nothing | Agent [x] |
| The two audit records name the skill and the mechanism document | `grep -n 'testing/SKILL.md\|test_harness_mechanism.md'` both | Agent [x] |
| The `Retire testing_policy` parent is `[x]` with one outcome line and no sub-rows | `grep -n` the parent; `grep -c` of the three unit titles prints 0 | Agent [x] |
| The policy-member row is `[x]` and states the outcome | `grep -n` the row | Agent [x] |
| The slice row names three slices done and `adr_policy` next, and the sequencing line agrees | `grep -n` both lines | Agent [x] |
| `bash scripts/lint.sh` and `bash scripts/run_tests.sh` clean | the commands | Agent [x] |
| The handover format gate is clean | `bash scripts/check_handover_format.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Historical citations stay; only instruction surfaces retarget | The `devlog/` records and the archive state what was true when written, and rewriting them would rewrite the record. The `AGENT_FEEDBACK.md` entry is an append-only finding, not an instruction | this record |
| The `Retire testing_policy` parent and the policy-member row close at this unit | The deletion is the last ending either row named: the file is gone and the membership test has no subject left | this record; the roadmap |

## Decisions pending

None.

## Findings

None.

## Completed

| File | Change |
|---|---|
| `docs/development/testing_policy.md` | deleted |
| `docs/development/testing-conventions.md` | deleted |
| [`.agents/audits/test-quality-campaign.md`](../../.agents/audits/test-quality-campaign.md) | its authority list now names the skill and the harness mechanism document |
| [`.agents/audits/surface-area-report.md`](../../.agents/audits/surface-area-report.md) | the campaign row names the skill and the harness mechanism document |
| [`devlog/roadmap.md`](../roadmap.md) | the unit closed, the `Retire testing_policy` parent compacted, the policy-member row closed, the slice text and the sequencing updated |
