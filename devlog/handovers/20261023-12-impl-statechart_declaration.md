---
date: 2026-10-23
milestone: M3.3.2 - Retire the policy form
type: Implementation
status: Closed
---

# Handover - The statechart's single state declaration

## Objective

Declare the statechart's state set once and generate its legend from that declaration, so a state added to one side and not the other is a gate finding rather than a silent drift.

## Scope

The roadmap row **The statechart states its state set twice**, under M3.3.2. The row's end offers two routes, one declaration plus a query or one statement removed; this iteration takes the first, because the operator asked for the reader's table to survive.

The diagram's declarations are the declaration. The `## States` id and region columns are generated from them and checked by a gate. The gloss column stays authored prose and is not compared, per `principle-guard-derived-state`'s column test: a cell that carries a description is authored, and a gate that regenerated it would replace a judgement with a generator.

The other nine queries in `## Checks` stay read by hand.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The id and region columns are generated from the chart, and an authored gloss survives a regeneration | `bash scripts/check_statechart.sh --write` leaves the table unchanged in `git diff`, and a fixture whose gloss differs from the label passes the gate | Agent [x] |
| The gate names a state declared only in the chart, a row only in the table, a region moved in the table, and rows out of declaration order | `bash tests/test_statechart.sh` reports 9 passed, 0 failed | Agent [x] |
| The tree is clean and the gate runs in the umbrella | `bash scripts/lint.sh` prints `statechart: clean across 40 state(s)` and `Lint: clean ... across 11 gates` | Agent [x] |
| The document states which columns are generated and which is authored | `grep -c 'The id and region columns are generated' docs/reference/workflow_statechart.md` returns 1, and `## Checks` carries the legend-drift row | Agent [x] |

## Decisions

- **The diagram is the declaration.** The table cannot generate the diagram, and no code in this tree writes a tracked file, so the direction that survives is chart to table. The table is a gated copy: `principle-guard-derived-state` classifies a statechart as one.
- **The gloss column is authored.** The id and region columns restate the chart; the gloss is design prose. The unit of derivation is the column, so the gate compares two columns and leaves the third alone. `--write` keeps every existing gloss and seeds a newly declared state's gloss from its label.
- **The gate is `workflow`, not `feat`.** Merging it makes the next contributor regenerate the table rather than type it, which is the `workflow` versus `chore` test.

## Decisions pending

None.

## Findings

- **The row's premise was wrong.** It said the table "adds a gloss the diagram cannot hold". Of the 40 rows, 24 match the chart's label and 16 differ only in punctuation, backticks and phrasing, so the gloss is the same description in a different register, not new knowledge. The row's text is corrected as it closes.
- **The `## Checks` intro was stale for one row.** It said every check is read by hand; legend drift is now a gate. The intro names the exception.

## Completed

| File | Change |
|---|---|
| `scripts/lint/statechart.mjs` | the scanner: derives id and region from the declarations, compares them, and rewrites the table with `--write`, keeping authored glosses |
| `scripts/check_statechart.sh` | the gate entry, with a `--doc` seam for fixtures |
| [`scripts/lint.sh`](../scripts/lint.sh) | the gate registered; 11 gates |
| `tests/test_statechart.sh` | nine cases: clean, declared-only, ghost row, region move, order, authored gloss, missing section, write, the real tree |
| [`docs/reference/workflow_statechart.md`](../docs/reference/workflow_statechart.md) | the generation statement and the legend-drift check row |
| [`devlog/roadmap.md`](../roadmap.md) | the row ticked with its outcome |
| [`devlog/roadmap_future.md`](../roadmap_future.md) | the live census no longer claims the removed duplicate |
