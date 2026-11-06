---
date: 2026-11-06
milestone: M3.5.4 - The git and change model
type: Housekeeping
status: Closed
---

# Handover - Retire the record-entity unit

## Objective

Remove the record-entity `unit` from the project's instruction text and add the lint that holds the carrier vocabulary, so the text names the iteration, the delivery commit, the branch, the handover, the roadmap row or the numbered item.

## Scope

The record-entity uses on the project's instruction surfaces and the agent layer under `src/reasoning/agent`, and the new lint that holds the carrier vocabulary. The test-unit domain -- the test harness, the testing skill, `close-read` -- is the quantifier and stays; the pi provider's config skills are excluded to a T12 row.

Out of scope, with reasons: the pi provider's config skills, filed under T12; `docs/adr/`, `devlog/` and `.agents/drafts/`, which are historical or unshipped; the concurrency proof and the milestone close, which follow.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The shipped instruction text carries no record-entity `unit` | the lint over the surface roots: `unit vocabulary: clear across 163 file(s)` | Agent [x] |
| The lint fails on a synthetic bare use and passes on the tree | `tests/test_unit_vocabulary.sh`, five cases | Agent [x] |
| The agent-layer skills under `src/reasoning/agent` are swept; the pi provider's config is filed under T12 | the lint's roots and the T12 row | Agent [x] |
| The roadmap bare-unit row closes | `devlog/roadmap.md` | Agent [x] |
| The gates are clean | `scripts/lint.sh` 22 gates; `scripts/run_tests.sh` 1469 passed, 0 failed | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The carrier map: work cycle to iteration, landed change to delivery commit, carrier to branch, record to handover, test to test case, numbered entry to item, document subject to subject | the carriers the usage rule names | this record |
| The lint allows the quantifier (`unit of work`, `unit of a pass`, `unit of measure`, `unit of a turn`, `unit of instruction`, `unit of isolation`) and the compounds (`unit test`, `unit suite`, `unit harness`, `unit contract`, `test unit`, `unit under test`) | the rule's quantifier exception; those are not the record entity | `docs/reference/terminology.md` Usage |
| The test-unit domain -- the test harness, the testing skill, `close-read` -- is exempt from the lint | its `unit` is the test case, the quantity the suite counts | `scripts/lint/unit.mjs` |
| The pi provider's config skills are excluded; the pstack's quantum is the provider layer's and is filed under T12 | the project's vocabulary rule does not govern the provider layer | the T12 row |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The pi provider's config skills use the pstack's `unit` | observation | the provider's quantum, not the project's record entity | the T12 row "The pi provider's config skills use the pstack's `unit`" |
| The test harness's `unit` is the test-unit quantifier, not the work unit | observation | the earlier row listed it as a violation; the quantifier exception keeps it | `docs/reference/terminology.md` Usage |

## Completed

| File | Change |
|---|---|
| `docs/reference/workflow_statechart.md` | the `unit` region and prose name the iteration |
| `.agents/skills/numbering/SKILL.md` | the numbered item |
| `docs/reference/documentation_taxonomy.md` | the numbered item |
| `.agents/skills/{project-documentation,decision-records,instruction-authoring,skill-fork}` | the item, record, iteration and change |
| `workflow/coding-agent/skills/{check-in,history-cleanup,code-review,recovery,handover-maintenance,roadmap-maintenance,initialize,record-correction}` | the row, commit, component, iteration and handover |
| `AGENTS.md` | the item and the iteration |
| `docs/reference/{autonomous_agent_loop,dispatch}.md` | the iteration |
| `docs/development/instruction-surface-conventions.md` | the handover record |
| `src/reasoning/agent/{prompts/package-branch.md,skills/domain-modeling/ADR-FORMAT.md,skills/write-locations/SKILL.md}` | the change, granularity and caller |
| `docs/reference/terminology.md` | the usage rule |
| `devlog/roadmap.md` | the row closes; the T12 row files the provider |
| `scripts/lint/unit.mjs`, `scripts/check_unit_vocabulary.sh`, `tests/test_unit_vocabulary.sh`, `scripts/lint.sh` | the lint and its fixture |
| `devlog/handovers/M3.5.4/20261106-02-chore-unit_vocabulary.md` | this record |
