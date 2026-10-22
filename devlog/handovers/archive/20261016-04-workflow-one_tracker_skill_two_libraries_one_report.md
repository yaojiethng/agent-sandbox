---
date: 2026-10-16
milestone: M3.2.3 - Dispatch Workflows as a Command Surface
type: Workflow
status: Closed
---

# Handover - One tracker skill, two libraries, one report

## Objective

Merge the `session-memory` skill into `active-tracker`, split the code into two libraries under one facade, and make the push report a pure function of the two logs and the two views.

## Scope

The skill's files, the tests, the two prompts, the roadmap, repository and installed.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| One skill | `active-tracker` holds `tree.mjs`, `memory.mjs` and the facade, and `session-memory/` is gone | Accepted |
| The facade composes | `active-tracker.mjs` imports both libraries and is the single writer of the tracker file | Accepted |
| The tree diff is derivable | the push event carries `created` and `stateFrom`, and `tree.diff` derives the change from the log since the mark | Accepted |
| The report is pure | `report` composes the tree diff, the memory diff and the memory view, and advances both marks | Accepted |
| A second report shows no change | `test_the_report_advances_both_marks` | Accepted |
| The prompts relay the report | both name the skill and the `report` command, and compose nothing | Accepted |
| Repo and installed copies match | `diff`, identical | Accepted |
| Gates clean | lint clean; the suite green | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| One skill, two libraries | the two share a lifecycle, a file and a mark, so one entry point keeps the state consistent | `README.md` |
| The facade is the only writer of the tracker file | the tree blocks and the memory block are written in order, so the two writers never interleave | `active-tracker.mjs` |
| The tree event carries `created` and `stateFrom` | without them the diff cannot say created-or-updated, or what a state moved from | `tree.mjs` |
| The report is code, not a template | the shape is fixed and small, and a pure function cannot drift; a template earns its place only when the wording must change without a code edit | `README.md` |
| The memory keeps its file names | `SESSION_MEMORY_LOG.jsonl` and its neighbours stay, so the live scratch needed no migration | `memory.mjs` |

## Decisions pending

| Decision | Why it waits |
|---|---|
| Whether the memory's file names become `TRACKER_MEMORY_*` | they carry the retired skill's name, but a rename needs a migration and buys only a name |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The push report was assembled by the model, so the same events could produce different text. The two logs and the two views already held every input, so the report was a pure function waiting to be written. | design | `report` |
| The report needed two fields the log did not carry. `created` cannot be inferred, because the log starts empty against a populated store, so the first push of an id is not necessarily a creation. | defect | the push event |
| The two libraries were only ever used together, so the second entry point was a cost with no caller. | design | the merge |
| The tree diff read `stateFrom` after the mutation and so always equalled the new state. `test_the_report_composes_both` caught it before landing. | defect, fixed before landing | `tree.mjs` |

## Completed

| File | Change |
|---|---|
| [`SKILL.md`](../../../src/reasoning/providers/pi/config/agent/skills/active-tracker/SKILL.md) | the combined contract |
| [`README.md`](../../../src/reasoning/providers/pi/config/agent/skills/active-tracker/README.md) | the combined model |
| [`tree.mjs`](../../../src/reasoning/providers/pi/config/agent/skills/active-tracker/tree.mjs) | the edge list, the log, the diff, the mark |
| [`memory.mjs`](../../../src/reasoning/providers/pi/config/agent/skills/active-tracker/memory.mjs) | the memory library |
| [`active-tracker.mjs`](../../../src/reasoning/providers/pi/config/agent/skills/active-tracker/active-tracker.mjs) | the facade: push, pop, view, report, memory, log |
| [`test_active_tracker.sh`](../../../tests/test_active_tracker.sh) | nineteen cases |
| [`push-task.md`](../../../src/reasoning/providers/pi/config/agent/prompts/push-task.md) | run `report` and relay it |
| [`pop-task.md`](../../../src/reasoning/providers/pi/config/agent/prompts/pop-task.md) | run `report` and relay it |
| [`devlog/roadmap.md`](../../roadmap.md) | the M3.2.3 rows |
| `skills/session-memory/` | removed |
| `$AGENT_HOME/agent/skills/` | the skill installed, and `session-memory/` removed |
