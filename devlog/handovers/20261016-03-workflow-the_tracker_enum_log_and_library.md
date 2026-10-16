---
date: 2026-10-16
milestone: M3.2.3 - Dispatch Workflows as a Command Surface
type: Workflow
status: Closed
---

# Handover - The tracker's enum, log and library

## Objective

Apply four refinements to the `active-tracker` skill: terminology instead of model prose, an enum state, an append-only change log, and a library surface for codemode.

## Scope

The skill's `SKILL.md`, `README.md` and `active-tracker.mjs`; the test; the push prompt; the live store; the roadmap; repository and installed.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The state is an enum | the store holds `open`, `later` or `elsewhere`, and a symbol refuses | Accepted |
| The enum renders directly | the tree prints the enum value and the legend with it, so no cross-reference is needed | Accepted |
| The log is append-only | every push and pop appends one event, and `log --since` trims | Accepted |
| The library drives the tool | `test_library_drives_the_same_operations` imports the module, then pushes and pops | Accepted |
| A bulk pop works | `pop <id> <id>` prunes every named subtree in one call and one render | Accepted |
| The frame model frames the tests | the header states a transition table, each row derives a push/pop pair, and a missed pop shows in the log | Accepted |
| The skill is terminology, not model | `SKILL.md` carries the term table, the commands, the states and the codemode snippet; the model is in `README.md` | Accepted |
| The live store is migrated | symbols converted to the enum, and the file re-rendered | Accepted |
| Repo and installed copies match | `diff`, identical | Accepted |
| Gates clean | lint clean; the suite green | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The enum is the storage, and the render prints the value | a symbol needs a legend, and a legend is a cross-reference the reader must resolve; the enum value is self-describing | `SKILL.md`, `active-tracker.mjs` |
| The model moved to `README.md` | the model is upstream of the implementation and explains the shape; the agent needs the terms, not the rationale | `README.md` |
| The log is a second file | idempotence and history pull in opposite directions, so the store stays idempotent and the log keeps the change record | `README.md` |
| The log is append-only and never edited | a change record that can be rewritten cannot reconcile a missed push or pop | `active-tracker.mjs` |
| The CLI and the library are one file | the CLI wraps the same functions, so the two surfaces cannot drift | `active-tracker.mjs` |
| The destination of an `elsewhere` node is dropped | the roadmap owns filing, and a second copy of the destination goes stale; `elsewhere` already says the node does not continue here | `README.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The first state vocabulary, `[ ]`/`[~]`/`[-]`, needed a legend, so every read paid a cross-reference. | design | replaced by the enum |
| The render had to own the legend as well as the block, or the two drift when the vocabulary changes. | defect, fixed before landing | `splice` |
| The library costs nothing extra: the CLI calls the same functions, so bulk and codemode need no second implementation. | design | `active-tracker.mjs` |
| The migration moved the destination into the label, and did it inconsistently: `B3e` kept `M3.6.3` while the three `B4a-*` rows lost `M3.6.1`. The destination is now dropped from the schema and the live store, so the loss is moot. | defect, resolved by the decision | `README.md` |
| The tests named frames in prose but exercised none. Stating the transition table and deriving the cases from it produced the missed-pop case, which no hand-written case had covered. | design | the frame cases |

## Completed

| File | Change |
|---|---|
| [`SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/active-tracker/SKILL.md) | terminology, commands, states, the log, the codemode snippet |
| [`README.md`](../../src/reasoning/providers/pi/config/agent/skills/active-tracker/README.md) | the model, moved out of the skill |
| [`active-tracker.mjs`](../../src/reasoning/providers/pi/config/agent/skills/active-tracker/active-tracker.mjs) | the enum, the log, the library surface, bulk pop |
| [`test_active_tracker.sh`](../../tests/test_active_tracker.sh) | fifteen cases, three derived from the frame transition table |
| [`push-task.md`](../../src/reasoning/providers/pi/config/agent/prompts/push-task.md) | the bulk-change note |
| [`devlog/roadmap.md`](../roadmap.md) | the M3.2.3 row |
| `<scratch>/ACTIVE_TASK_TRACKER.json` | the enum states |
| `<scratch>/ACTIVE_TASK_TRACKER.md` | re-rendered |
| `$AGENT_HOME/agent/skills/active-tracker/` | the three files installed |
