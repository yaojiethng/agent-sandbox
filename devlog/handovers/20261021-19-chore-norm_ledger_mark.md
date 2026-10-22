---
date: 2026-10-21
milestone: M3.3.4 - The prose standards as principles
type: Housekeeping
status: Closed
---

# Handover - The norm ledger stores only what nothing can derive

## Objective

Remove the one column of `scripts/lint/norm-ownership.tsv` that a gate could not check, and state the scan's blind spot where a reader meets it.

## Scope

The roadmap row **The norm ledger stores only what nothing can derive**, raised from the question of whether the ledger is tautological and scoped as one unit by the operator. It carries no reach work: the reach row keeps its own unit.

The `kind` column held `rule`, `judgement` or `description` beside the observer. The script already read the label back off the observer, through the consistency matrix that failed a `rule` with no observer and a `judgement` with one. That matrix is the column's only use, and it exists to catch the column disagreeing with the observer. So the column carried one value the observer cannot give, `description` against `norm`, and a three-way label that was a copy the other two-thirds of the time.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The derived label reproduces the stored one | `bash scripts/check_norm_ownership.sh --check` reports the same counts the stored column did, 23 gated and 14 reviewed before this unit's own policy line was rewritten | Agent [x] |
| A column that is neither mark fails | `bash tests/test_norm_ownership.sh` covers the failure through `test_conforming_tree_passes` and the fixture's `UNCLASSIFIED` path | Agent [x] |
| A description may not carry an observer | `bash tests/test_norm_ownership.sh`, `test_description_with_observer_fails` | Agent [x] |
| A norm with no observer is a judgement, not an error | `bash tests/test_norm_ownership.sh`, `test_norm_without_observer_is_a_judgement` | Agent [x] |
| The gate and its own test are clean | `bash scripts/lint.sh` prints `Lint: clean`; `bash scripts/run_tests.sh` prints the suite green | Agent [x] |

## Decisions

The label is derived, so no row states it. `rule` is a norm with an observer, `judgement` a norm without one, and `description` the one mark a reader supplies because nothing else can tell prose that states what is from prose that tells a reader how to decide.

Two failure branches went with the column. A `rule` with no observer and a `judgement` with an observer cannot occur once the label follows the observer, so the check keeps one inconsistency, a description carrying an observer.

The scan's limit is stated rather than closed. `candidate_lines` skips fences, headings, table rows and horizontal rules, and both source documents state rules in tables. Closing it would add rows whose label a reader must supply, which is the guess this unit removes, so the ledger now says what it does not read and no row claims coverage it lacks.

The one lost state is recorded in Findings rather than replaced: a line deliberately marked `rule` with no observer, as a to-do for a gate it needs. Nothing used it, and under the derived label it is indistinguishable from a judgement, so the state is gone until a row asks for it by name.

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Removing the column also removed the only way to record "this line needs an observer" as a to-do, because that state was `rule` with no observer | result | nothing in the ledger used it, and the census states the same fact as its judgement count. A milestone that wants the to-do back needs a mark of its own rather than a label that disagrees with the observer | recorded here |
| The counts in the closed M3.3.2 row and in the handovers that cite it are copies of a value the gate prints, and this unit moves them | noise | every count in a record about this ledger is stale the next time a line changes. The gate's summary line is the value; a record should quote the command | recorded here |
| This file's own sentence about the ledger was rewritten, so its row lost the old classification | result | the old row counted as gated and the new sentence is a description, which is the reading the old sentence deserved as well. The gated count reads one lower for that reason | fixed in this unit |

## Completed

| File | Change |
|---|---|
| [`scripts/check_norm_ownership.sh`](../../scripts/check_norm_ownership.sh) | column 3 holds a mark; the label is read off the observer; the reference-table kind validation and its reader are gone; the header states the scan's limit |
| [`scripts/lint/norm-ownership.tsv`](../../scripts/lint/norm-ownership.tsv) | regenerated with the mark column; `rule` and `judgement` rows read `norm` |
| [`tests/test_norm_ownership.sh`](../../tests/test_norm_ownership.sh) | the fixture marks rather than classifies, the kind table is gone from it, and one failure test became the pair that pins the derived label |
| [`docs/policies/documentation_policy.md`](../../docs/policies/documentation_policy.md) | the sentence that describes the ledger states the observer and the mark |
| [`devlog/roadmap.md`](../roadmap.md) | the row filed and closed |
