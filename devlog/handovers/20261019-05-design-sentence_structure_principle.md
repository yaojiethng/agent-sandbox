---
date: 2026-10-19
milestone: M3.3.4 - The prose standards as principles
type: Design
status: Closed
---

# Handover - the sentence-structure principle

## Objective

Derive one sentence-structure principle that subsumes the three lines active voice, noun before command, and no thin subject, and ground it in primary standards, the parsing literature, a corpus, and a measurement.

## Scope

A study under the M3.3.4 plan row **Plan the `communication` standard into principle specs**, deepening three of the rows in [`20261019-design-draft-prose_standards_specs.md`](../discussions/20261019-design-draft-prose_standards_specs.md). The deliverable is a draft design and its evidence. No skill is filed and `documentation_policy.md` is not edited, per the row's own instruction.

Out of scope: filing the principle, and the other nine proposed principles.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The three lines resolve to one principle at a named stratum | read `## Decision` in the design | Operator [ ] |
| The principle carries a pattern table, a why, and a test, in the exemplar's shape | read `### The principle` and `### The pattern table` | Operator [ ] |
| The boundary names the cases that override the principle | read `### The boundary` | Agent [x] |
| The corpus carries a failure class per sentence | the design's corpus table, 18 rows | Agent [x] |
| The measurement separates the corpus from the control on comprehension | two blind corpus readers, 17 of 18 reproduced; one control reader, 6 of 6 recovered | Agent [x] |
| Each surface move reconciles to a fetched public standard | read `### The reconciliation` | Agent [x] |
| The principle is classified in the norm-ownership ledger | `bash scripts/check_norm_ownership.sh --check` clean; recorded as a judgement | Agent [x] |
| The gates and the suite are clean | `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The principle is one mechanism with the three lines as its pattern table | the three share one cause, so three principles duplicate the test; one imperative is a no-op | the design, `## Options Considered` |
| The stratum is incremental, resource-limited integration | each line lowers a different integration cost on the same budget | the design, `### The stratum` |
| The principle is a judgement, observer `none` | no gate detects that a passive is wrong in this sentence, and no dispatched reading procedure names the check | the design, `### The classification` |
| The length proxy is retired | the corrected control sentences are longer than the corpus, so word count does not separate the sets | the design, `### The measurement` |
| The absent dependency parse is named as the largest gap | the container has no parser; the dependency claim rests on the mechanism and the reader outcome | the design, `### The measurement` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Does the operator accept one principle for the three lines, and the name `communication-principle-attach-as-you-read`? | filing the principle in the plan's tranche | accept; keep three separate principles; rename |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Two blind readers on different models reproduce the same failure on 17 of 18 corpus sentences, and their reasons match the failure class. | result | the corpus is real, not the mining worker's claim |
| The six corrected sentences are longer than the corpus, and the length proxy does not separate the sets. | negative result | a later session cannot satisfy the principle by shortening sentences |
| The control reader still supplies referents, so inference alone is not the predicate. The predicate is whether the recovered proposition matches the intended one. | method | the test is specified by the outcome, not by the inference count |
| The container carries no parser, so mean dependency distance was not measured. | limitation | the dependency claim is unmeasured; a follow-up can measure it |
| ASD-STE100 Issue 9 and ISO 24495-1 are not publicly fetchable, so the two primary sources behind the repo lines are unquoted. | limitation | the reconciliation rests on the public standards alone |
| The mining worker is read-write on the main tree, and two of three parallel dispatches hit the free-tier refusal. | process | one retry serially recovered the corpus; the free tier is quota-limited under parallel load |

## Completed

| File | Change |
|---|---|
| `devlog/discussions/20261019-design-draft-sentence_structure_principle.md` | new draft design; the stratum, the principle, the pattern table, the boundary, the corpus, the measurement, the reconciliation, the classification |
| `devlog/discussions/20261019-report-draft-sentence_structure_evidence.md` | new draft report; the three reader transcripts, the scoring, and the raw corpus, standards and literature |
| `devlog/roadmap.md` | the plan row references the study |
