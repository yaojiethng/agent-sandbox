---
date: 2026-10-23
milestone: M3.3.2 - Retire the policy form
type: Implementation
status: Closed
---

# Handover - The derived artifacts this repository stores

## Objective

Settle, by measurement, which stored artifacts in this tree are derived from something the tree already holds, and give each one a home, so the next instance is classified before it is maintained.

## Scope

Operator-directed at the park of the cited-command unit, which is a different task and stays on the roadmap. This iteration is the census and the verdicts; a retirement lands here only where it is one edit with the suite green, and everything larger becomes a row.

In scope: the census query, its output, the per-artifact verdicts, the rule they produce, and the one artifact whose stored fields are derived and read by nobody. Out of scope: building any generator, since the census found none to build on; the mutation corpus's future, which is a feature decision carrying a number and belongs to the operator; and the cited-command gate, whose design record is parked at draft.

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| A1 | The census runs and prints candidates | the run reported in the design record's `## Method` and `## What the tree says`: 27 tables, 3 registries, 0 written paths. The script itself was dropped from the record when the unit was released | Agent [x] |
| A2 | The zero in detector A is true, not an artefact | `grep -rn 'writeFileSync' src/ scripts/` resolved by hand: every write target is a host path, `.compose/`, a run directory or `$AGENT_HOME` | Agent [x] |
| A3 | Every stored catalog above eight rows is classified | the design record's table lists 8 artifact classes; the 27 detected tables are accounted for as catalogs or as authored claims | Agent [x] |
| A4 | The rule names the unit and the test | `## The rule` states the column test and the three homes, with the chart's table and the loop table as the two sides | Agent [x] |
| A5 | The derived header fields are gone and the corpus is intact | `head -1 tests/mutations/catalog.jsonl` carries schema, kind and origin only; the file is 245 lines, 244 rows | Agent [x] |
| A6 | The runner's fixture matches the real header | `tests/test_mutations_runner.sh` writes a header with no derived field; the self-test reports 2 passed | Agent [x] |
| A7 | The records are consistent with the verdicts | the design is `settled`; the cited-command design is `draft` and carries the chart-table and `/auto` amendments | Agent [x] |
| A8 | The roadmap carries what the census produced | the census row is closed; the mutation-corpus row is open with its number; the cited-command row is amended | Agent [x] |
| A9 | The change adds no maintenance surface of its own | no new script, gate or test file; the record keeps the measurements, not the instrument | Agent [x] |
| A10 | The suite and lint stay green | `make test` 1272, `bash scripts/lint.sh` clean | Agent [x] |
| A11 | Every decision this iteration recorded is realized in the files | D1 to D6 read against the record, the catalog and the roadmap | Agent [x] |
| A12 | Two reviewer seats classified blind, and their findings are folded | `review-dispatch.sh` ran both seats at `deepseek/deepseek-flash high`: rc 0, 152s and 41s, both bound the requested model; four corrections folded, one of them a verdict | Agent [x] |
| A13 | No record describes a state the tree no longer has | the design record states the catalog header in the past tense and names the fix; the chart's claim that its table is gate-held is corrected | Agent [x] |
| A14 | The record's vocabulary is the shipped principle's | every classification cell is one of `Authored source`, `Gated copy`, `Derived on read`, `Dead weight`, and the record names the principle as the authority | Agent [x] |

## Decisions

| # | Decision | Rationale | Where recorded |
|---|---|---|---|
| D1 | The census script is not kept at all; the record carries what it measured and what each detector could not see | It ran once per question, it is the wrong shape, and preserving it invites a rerun of the instrument the record rejects | design record |
| D2 | No generator is built | The census found none in the tree, so `regenerate and diff` has nothing to run; a check against the source is a tenth of the code | design record |
| D3 | The unit of derivation is the column, not the file | A row set a directory can enumerate is derived; a row's content is a claim and is authored | design record |
| D4 | The mutation corpus's future is the operator's, priced not decided | 244 unregenerable rows, 7 drifted, one recorded run: a feature question, not a check | roadmap row |
| D5 | The catalog's `count` and `last_updated` are dropped | Derived values stored inside the artifact, read by nothing, free to be wrong | catalog header |
| D6 | The chart's `## States` is authored, not a catalog | A generator over prompts and skills would produce a different graph, not this one | design record |

## Decisions pending

None.

## Findings

| # | Finding | Type | Impact | Triaged to |
|---|---|---|---|---|---|
| 1 | 7 of 244 mutation rows no longer match their subject, and nothing forces action | drift | the tier reports them as `stale` only when someone runs it | the roadmap row **The mutation corpus's home** |
| 2 | `/auto` is carried by two artifacts: the ADR reservation and `.agents/prompts/auto.md` | ambiguity | a token resolving to a file can resolve to the wrong one | the cited-command row's amendment |
| 3 | The chart's `## Commands` table asserts equality with the prompt directory and no gate holds it | ungated catalog | 17 rows hand-maintained against 17 files | the cited-command row's amendment |
| 4 | The churn metric ranks `settings.json` worst and it is authored config | measurement limit | 23 of its 28 commits are version bumps, not upkeep | recorded as the metric's caveat in the design record |
| 5 | No code in the repository writes a tracked file | baseline | `stored and verified` has no generator behind it; every check compares two hand-maintained copies | recorded in the design record |
| 6 | The mutation catalog's derivation chain is broken: the `bite_*.sh` sources are deleted | lost source | the corpus cannot be rebuilt, only hand-edited | the roadmap row **The mutation corpus's home** |
| 7 | `settings.json` names the image's version pin as a literal, so a bump updates two records by hand and one of them silently | duplicated literal | one version in two places | the roadmap row **The settings record holds the image's version pin as a literal** |
| 8 | The reach table's `the project's own setup` row passes `check_reach.sh` when deleted | unverified row | a declared row no gate holds | the roadmap row **The reach table's ... row is not verified** |
| 9 | The statechart carries its 40 state ids twice, in the diagram and in `## States` | duplicated column | a hand-maintained copy inside one file | the roadmap row **The statechart states its state set twice** |
| 10 | The ownership table's `Document` cells are mostly code spans, so the linking gate resolves 3 of 12 | ungoverned reference | nine document names no gate follows | the roadmap row **A table cell that names a document is a link** |
| 11 | The chart claimed its command table was held by a check that is a hand query | false claim | a reader trusts a gate that does not exist | fixed here, in `workflow_statechart.md` |
| 12 | `tests/mutations/catalog.jsonl` carried `count` and `last_updated` in its header: values derived from the rows beside them and read by nothing, with no gate to catch either drifting | stored derived value | the header can disagree with the file it describes and nothing reports it | fixed here: both fields removed, the fixture aligned, the runner self-test green |

## Completed

| File | Change |
|---|---|
| [`devlog/discussions/20261023-design-settled-derived_artifacts.md`](../discussions/20261023-design-settled-derived_artifacts.md) | the census method and its limits, the per-artifact table, the rule, the two reviewer seats, four rejections, and no copy of the script |
| [`devlog/discussions/20261023-design-rejected-cited_command_gate.md`](../discussions/20261023-design-rejected-cited_command_gate.md) | rejected; the citation half is retired and the chart table moves to M3.3.3 |
| [`tests/mutations/catalog.jsonl`](../../tests/mutations/catalog.jsonl) | header reduced to schema, kind and origin: `count` and `last_updated` were derived and read by nobody |
| [`tests/test_mutations_runner.sh`](../../tests/test_mutations_runner.sh) | its fixture header matches the real one |
| [`docs/reference/workflow_statechart.md`](../../docs/reference/workflow_statechart.md) | its command-table claim names the `Command coverage` query and says it is read by hand, instead of claiming a check it does not have |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | census row closed; the mutation-corpus row filed with its numbers; the cited-command row amended; four rows from the reviewer seats |
| [`devlog/roadmap_future.md`](../roadmap_future.md) | the reader graph filed as a deferred milestone: the census's requirements restated for a cold session, then the query, the index, the acceptance and what stays out |
