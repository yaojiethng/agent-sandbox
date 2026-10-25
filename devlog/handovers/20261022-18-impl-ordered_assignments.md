---
date: 2026-10-22
milestone: M3.6.3 - Route and decide
type: Implementation
status: Closed
---

# Handover - A role resolves to its ordered assignments

## Objective

Replace the shell seam with the TypeScript library, so a role returns an ordered list of assignments, the entrypoint walks it by outcome, and the vocabulary and the behaviour are stated once.

## Scope

The roadmap row **The seam reads only the first entry of a role's line**. The library's table grammar, launcher and command line, the entrypoint and its worker mode, the two deleted shell files, the vocabulary and behaviour documents, both `AGENTS.md` layers and the reference carriers.

The dispatch-rule surface stays open by the run's own ruling: this unit names the defects an extension inherits and adds no schema.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A role prints its ordered assignments, each with the runtime it resolves to | `node src/libs/dispatch/cli.ts table roles` prints three assignments per role | Agent [x] |
| A walk advances by outcome, and a pin is the caller's value | `bash tests/test_dispatch.sh` prints `52 passed, 0 failed` | Agent [x] |
| The shell seam is gone | `test ! -e src/libs/dispatch.sh`, and `scripts/dispatch.sh` asks the library | Agent [x] |
| The vocabulary and the behaviour are stated once | [`terminology.md`](../../docs/reference/terminology.md) defines each term; [`dispatch.md`](../../docs/reference/dispatch.md) defines none | Operator [x] |
| The gates are clean | `bash scripts/lint.sh` prints `Lint: clean in 7s across 12 gates`; `bash tests/test_dispatch_machine.sh` prints `2 passed, 0 failed` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| One entrypoint owns a dispatch; a skill or a prompt carries only the instruction that calls it | the seam, a skill launcher and an inline call each assembled half a decision | [`dispatch.md`](../../docs/reference/dispatch.md) |
| A role resolves to an ordered list of distinct assignments, and a request names how many distinct models it needs | a fallback is the next entry, a default is a value the table does not hold, and heterogeneity is a count | [`terminology.md`](../../docs/reference/terminology.md) |
| The runtime is derived from declared data, and the table prints it | `opencode-go` is served by `pi`, so a prefix's name decides nothing | [`dispatch.md`](../../docs/reference/dispatch.md) |
| A fixed run is outside the mechanism | the reviewer pins its assignments and reads no table, so nothing it pins can drift | [`dispatch.md`](../../docs/reference/dispatch.md) |
| The table's header line is not a role | the old parser's role test matched `Format:` and reported a role named `Format` | [`table.ts`](../../src/libs/dispatch/table.ts) |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The word `backend` survives the rename in `scripts/cost_ledger.mjs:92`, a `table.ts` comment and `reasoning_layer_tiers.md:43` | gap | the vocabulary now names a `runtime`, so two words still name one thing | new roadmap row under M3.6.3 |
| `20261016-design-active-dispatch_ownership.md` is still `active` after the mechanism shipped | record defect | the row **Who owns dispatch logic** names the record as its end | **Who owns dispatch logic** row |
| The `opencode-dispatch` skill remains, and the brief's `dispatch` skill did not land | gap | the skill still carries launcher flags the entrypoint owns; the launch-site gate holds it inside the library | **Who owns dispatch logic** row |

## Completed

| File | Change |
|---|---|
| [`table.ts`](../../src/libs/dispatch/table.ts), [`launch.ts`](../../src/libs/dispatch/launch.ts), [`cli.ts`](../../src/libs/dispatch/cli.ts) | the table's grammar, the one argv builder, and the library's command line |
| [`src/libs/dispatch.sh`](../../src/libs/dispatch.sh) | deleted; its grammar, resolution order and argv shapes moved to the library |
| [`scripts/dispatch.sh`](../../scripts/dispatch.sh), [`dispatch_worker.sh`](../../src/libs/dispatch_worker.sh) | the entrypoint prints, runs, records and inspects, and the worker is a mode of it |
| [`terminology.md`](../../docs/reference/terminology.md), [`dispatch.md`](../../docs/reference/dispatch.md) | the reserved vocabulary and the behaviour of record |
| [`AGENTS.md`](../../AGENTS.md), [`AGENTS.md`](../../src/reasoning/providers/pi/config/agent/AGENTS.md) | the dispatch procedure and the role table's location |
| [`agent_workflow.md`](../../docs/reference/agent_workflow.md), [`execution_model.md`](../../docs/reference/execution_model.md), [`provider_lifecycle.md`](../../docs/reference/provider_lifecycle.md), [`system_overview.md`](../../docs/reference/system_overview.md) | the carriers point at the mechanism instead of restating it |
| [`tests/test_dispatch.sh`](../../tests/test_dispatch.sh), [`table.test.ts`](../../tests/dispatch/machine/table.test.ts) | the walk's cases and the table's grammar |
| [`devlog/roadmap.md`](../roadmap.md) | the row closed, its link moved to `table.ts`, and the `backend` row filed |
