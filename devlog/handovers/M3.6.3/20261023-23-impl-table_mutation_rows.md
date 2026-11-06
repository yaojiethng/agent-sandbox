---
date: 2026-10-23
milestone: M3.6.3 - Route and decide
type: Implementation
status: Closed
---

# Handover - The table's rules are broken by name

## Objective

Prove the table module's two standing rules are pinned by its suite, by breaking each one and watching its named case go red.

## Scope

The mutation gate at `tests/dispatch/machine/mutation.test.ts`, the two rules it did not cover, and the records that state those rules.

The gate broke each of the route machine's invariants and left `table.ts` untouched, so a green suite proved the machine and only asserted the table. The two rules left over are the ones the operator's defect census named. The runtime follows the model rather than the provider alone, because a paid model on the CLI is a request forwarded to a backend that fails it. And an assignment is constructed from a well-formed entry and nothing else, which is what makes a provider with no model unrepresentable rather than a guess.

Out of scope: `classify.ts`, `machine.ts` and `state.ts`, whose rows already exist, and any change to the table module itself.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The gate breaks the runtime rule and its named case goes red | `node --test tests/dispatch/machine/mutation.test.ts` prints `M5 T1 proven: table.test.ts failed at "a paid model on an OpenCode provider resolves to pi"` | Agent [x] |
| The gate breaks the grammar rule and its named case goes red | same run prints `M6 T2 proven: table.test.ts failed at "a malformed entry refuses the role"` | Agent [x] |
| The control row stays green, so a break is proof and not a mirror the suite cannot run | same run prints `control unedited green` and reports 7 pass, 0 fail | Agent [x] |
| Both rules are stated somewhere other than the test that breaks them | `docs/reference/dispatch.md` `## Requirements` and `docs/reference/terminology.md` `## runtime` | Agent [x] |
| Every decision this iteration recorded is realized in the files | the two rows below, each against its named file | Agent [x] |
| The gate is clean | `bash scripts/lint.sh` across 12 gates, `bash scripts/run_tests.sh` at 1311 across 95 files | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The two rows join the existing gate rather than a second harness | the gate already breaks `classify.ts`, so its subject is the module directory and not the machine alone; one mirror keeps one control row and one replay | [`mutation.test.ts`](../../tests/dispatch/machine/mutation.test.ts) and this record |
| The rows are labelled T1 and T2 instead of continuing the invariant ids | a machine transition carries its invariant's id, so those rows cite one; the table's rules are prose, and inventing I7 and I8 would name ids no record declares | the rows' comment |
| The runtime rule is stated in `dispatch.md ## Requirements` and the reserved term is corrected | a mutation row has to name the rule it breaks, and the term said the runtime came from the provider alone, which the library has not done since the model joined the decision | [`dispatch.md`](../../docs/reference/dispatch.md) and [`terminology.md`](../../docs/reference/terminology.md) |
| The file header says the dispatch library rather than the dispatch machine | the gate has broken a second module since M4 landed, so the old subject line described two thirds of its rows | the header comment |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The reserved term `runtime` said the library chose it from the provider alone, and the `assignment` term said the same, while the library has keyed on the provider and the model since handover `20261022-16` | doc | a reader learning the vocabulary met a rule the code had retired, on the page that is the vocabulary's source of truth | fixed here: both entries state the provider and the model, and each carries a fresh `Last updated` |
| The mutation gate's header named the dispatch machine as its subject while M4 already broke the classifier | test | a reader scoped the gate's coverage from a line that was wrong by one module | fixed here: the header names the library |

## Completed

| File | Change |
|---|---|
| [`tests/dispatch/machine/mutation.test.ts`](../../tests/dispatch/machine/mutation.test.ts) | two rows, `M5 T1` over the runtime rule and `M6 T2` over the grammar rule; the header names the library; the rows' comment says where each rule is stated |
| [`docs/reference/dispatch.md`](../../docs/reference/dispatch.md) | `## Requirements` gains the runtime rule: provider and model together, `-free` on the CLI, an empty model refuses |
| [`docs/reference/terminology.md`](../../docs/reference/terminology.md) | `## runtime` and `## assignment` state the provider and the model, dated 2026-10-23 |
| [`devlog/roadmap.md`](../roadmap.md) | a row for this unit, closed here |
