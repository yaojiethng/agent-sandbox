---
date: 2026-10-21
milestone: M3.3.4 - The prose standards as principles
type: Implementation
status: Closed
---

# Handover - The judgement map stores the reading and derives the arithmetic

## Objective

Remove the tautological rows from the norm ledger's judgement map, leaving the file holding only what a computation cannot supply.

## Scope

The roadmap row **The judgement map stores the reading and derives the arithmetic.** It answers the question the operator asked before the milestone close: whether `norm-judgements.tsv` is tautological.

The answer was one third of it. Of 62 rows, 20 carried `j-source-of-truth-<skill>` and the note `skill:<skill>`, and both are computed by `--regroup` from the skill the line cites. A row whose only possible failure is disagreeing with the derivation that would have produced it stores nothing. The other 42 rows record a reading: which judgement a line states is not derivable from the line.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The map holds no derived row | `awk -F'\t' '$2 ~ /^j-source-of-truth-/' scripts/lint/norm-judgements.tsv` prints nothing | Agent [x] |
| The sourced groups are still reported | `bash scripts/check_norm_ownership.sh --groups` prints 16 `j-source-of-truth-` groups | Agent [x] |
| A stored sourced row fails, with the reason | `bash tests/test_norm_ownership.sh` prints `17 passed, 0 failed`, one case of which is that row | Agent [x] |
| The ledger still balances | `bash scripts/check_norm_ownership.sh --check` prints `clean across 140 row(s)` | Agent [x] |
| Every gate passes | `bash scripts/lint.sh` prints `Lint: clean` and `bash scripts/run_tests.sh` prints `1287 passed, 0 failed` | Agent [x] |

## Decisions

The gate now fails a stored row for a sourced line rather than comparing it. Comparison was the tautology: two sides computed from one input can only agree or reveal a bug in the comparator. Refusing the row says what the file is for.

`--groups` derives the sourced groups at read time, so the reported map is unchanged in content and 20 rows smaller in storage. The 16 groups, their site counts and their `sourced` class are what the 20 rows used to supply.

The policy states the rule now. `documentation_policy.md` described the ledger and said nothing about the map, so the map's subject was stated only in the script's header. The sentence landed on a line the ledger already marked a description, which is the mark for prose that states what is rather than how to decide.

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Twenty of the map's 62 rows were a copy of a derivation, and the file's header already said so | defect | the file contradicted its own comment. It holds 42 readings now and the derivation has one home | fixed in this unit |
| A test asserted that `--regroup` writes the derived row, so a test was holding the tautology in place | result | the case now asserts the row's absence and the derived group, and a second case asserts the failure a stored row earns | fixed in this unit |
| The map's subject was stated in the script's header and nowhere a writer reads | gap | the policy paragraph carries it now. The grouping rules are a reader's business, because a reader is who decides which judgement a line states | fixed in this unit |

## Completed

| File | Change |
|---|---|
| [`scripts/check_norm_ownership.sh`](../../scripts/check_norm_ownership.sh) | `--regroup` stores only a judgement that cites no skill; a stored row for a sourced line fails; the header states the division |
| [`scripts/lint/norm-judgements.tsv`](../../scripts/lint/norm-judgements.tsv) | 62 rows to 42, all readings |
| [`docs/policies/documentation_policy.md`](../../docs/policies/documentation_policy.md) | the grouping rule stated where a writer reads it |
| [`tests/test_norm_ownership.sh`](../../tests/test_norm_ownership.sh) | the tautology case replaced by an absence case and a failure case, 17 cases |
| [`devlog/roadmap.md`](../roadmap.md) | the row filed and closed |
