# Agent Handover

**Date:** 2026-09-22
**Milestone:** M3.1 - Backpressure
**Type:** Plan
**Status:** Closed

## Objective

Produce the unified test-harness improvement plan: the design record, the roadmap task entry, and the plan-iteration findings.

## Scope

M3.1 test-suite work, consolidated into one task. Produces the design document for the harness improvement (per-test isolation, untyped per-test allocation, unified teardown, authoring bar, work units U1-U7, deferred comparison), the roadmap task row updated to this unified scope, and the Findings entries. Two-branch re-port and the harness decision stay deferred.

## Carried forward

| Item | From handover |
|---|---|
| Harness-migration and per-test-timeout decision via the two-branch comparison (branch A keep-current vs branch B bats-core). Superseded pending the unified main-line harness improvement; re-port mechanic (rebase or re-branch) open. | 20260921-13-study-test_suite_duration_and_bash_harness, 20260921-14-impl-m3_1_test_parallel_and_deadline, 20260921-14-impl-m3_1-bats_branch_b |

## Acceptance criteria

Not yet defined.

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/discussions/20260922-design-settled-test_harness_improvements.md`](../discussions/20260922-design-settled-test_harness_improvements.md) | The unified plan deliverable. |
| [`devlog/roadmap.md`](../roadmap.md) | Test-authoring-parity row superseded by the unified scope. |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Main-line landing; two-branch re-port deferred, mechanic open | List-1 items are harness-independent and benefit the suite regardless of harness choice. | Design doc, Purpose and scope |
| Per-test isolation pulled forward, full package (subshell-per-test + fail-fast + unit accounting) | Order-dependent green undermines trust in every verdict; isolation is a prerequisite, and it equalizes the later comparison. No parity record; the commit history is the record. | Design doc, Design decisions |
| Untyped per-test allocation (`get_fixture_dir` / `get_test_dir`, no reuse, unified teardown, `FIXTURE_DIR` compat handle) | Fixture and scratch are both just directories; no reuse between tests is the only structured guarantee. | Design doc, Design decisions |
| Authoring bar (a) plus a final full per-assertion sweep | Model-and-measured-violations now; completeness as a fresh-subagent review pass. | Design doc, Authoring bar |
| Order-independence as a verification probe (reversed-run gate) | With per-test subshells order cannot matter; a probe proves it. | Design doc, Design decisions |
| Clean, readable commit units; optional final squash | The commit history is the record; readability over a back-and-forth audit trail. | Design doc, Commit style |
| Design documents record the completed design, not the questionnaire | A Q&A transcript is a record of effort, not reasoning; it adds length without understanding benefit. Amend at the policy root. | This handover, Findings; AGENT_FEEDBACK at close |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Design documents must not record the open-questions-and-replies transcript. Write the answers back into the design body; include a short "designs considered and rejected" section; put the completed final design at the forefront. The questionnaire form reads as a record of effort, not a record of reasoning, and is how the previous discussion doc was drafted. Amend the design-document / documentation conventions to prohibit the pattern at the root. | steering | next iteration (policy amendment) |
| Allocator must guarantee no reuse between tests; teardown synchronised to just before the test's teardown, no guarantee after. `FIXTURE_DIR` stays as the per-test default-root compat handle. | scope change | current iteration |

## Completed

| File | One-line change summary |
|---|---|
| `devlog/discussions/20260922-design-settled-test_harness_improvements.md` | Drafted the unified harness-improvement design. |
| `devlog/roadmap.md` | Test-authoring-parity row superseded by the unified scope (pending). |

## Deferred items

Omit any item that is already a named task in `roadmap.md` or `roadmap_future.md`.

None.

## What's Next

M3.1 - Backpressure. Implementation of the work units U1-U7 from the design doc, on the main line.

**Conclusions from this iteration:** the plan is the record of the design. The final design sits first in the document, answers folded in, with the rejected designs and their reasons. The questionnaire style is dropped per the Finding.
