---
date: 2026-10-23
milestone: M3.3.2 - Retire the policy form
type: Housekeeping
status: Closed
---

# Handover - The mutation-corpus row moves to gate upkeep

## Objective

Restore the mutation catalog unchanged and move the corpus question from the policy-form milestone to M3.1.2, where the gate surface is owned.

## Scope

This iteration reverses handover `20261023-18`'s prune, which the operator withdrew on 2026-10-23, and relocates the roadmap row **The mutation corpus's home**. The corpus, the runner, its test and the `MUTATION=1` tier are left exactly as they were; the only change is where the open question lives.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The catalog is unchanged from before the prune | `git diff 3475947a -- tests/mutations/catalog.jsonl` prints nothing | Accepted: no output |
| The catalog holds its 244 rows | `wc -l tests/mutations/catalog.jsonl` prints `245`, the header and 244 rows | Accepted: prints `245` |
| The row is absent from M3.3.2 | `sed -n '/^##### M3.3.2/,/^##### M3.3.3/p' devlog/roadmap.md \| grep -c "mutation corpus"` prints `0` | Accepted: prints `0` |
| The row is open under M3.1.2 | `sed -n '/### M3.1.2/,/#### M3.2.1/p' devlog/roadmap.md \| grep -c "mutation corpus"` prints `1` | Accepted: prints `1` |
| The row records the move | the row's text names handover `20261023-18` | Accepted: the row reads "moved here from M3.3.2 on operator direction, handover `20261023-18`" |
| The umbrella is clean | `bash scripts/lint.sh` | Accepted: clean across 11 gates |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The prune is dropped rather than superseded | The commit was never delivered and the operator withdrew it, so the corpus returns to its prior state with no residue | this record |
| The row moves rather than closes | The operator ruled the harness stays and the question is gate upkeep, so it belongs beside the gate rows | the M3.1.2 row |
| The row keeps its original measurements | The counts and the drift are still true of the restored corpus, and the new owner needs them | the M3.1.2 row |

## Decisions pending

None.

## Findings

None.

## Completed

| File | One-line change summary |
|---|---|
| [`tests/mutations/catalog.jsonl`](../../tests/mutations/catalog.jsonl) | restored to its 244 rows, unchanged from the commit before the prune |
| [`devlog/roadmap.md`](../roadmap.md) | the row leaves M3.3.2 and opens under M3.1.2 with the move recorded |
