# The experiment specification

The questions a run must answer, the measure each answer is in, the field it is read from, and the one condition that makes the number untrustworthy. The harness exists to fill this table: a field no row names is not added, and a row is added with the decision that reads it and removed with that decision.

Why each row is here, and what the run's rules answer, are recorded in [`eval_harness_contract.md`](../../../../docs/adr/eval_harness_contract.md).

## The table

| # | Question | Measure | Field | Invalid when |
|---|---|---|---|---|
| A1 | Did the instruction set change behaviour? | pass rate over assertions, per configuration, with sd | `measure-<config>.json`: `correctness`, `correctness_sd`, `runs_detail[].rules` | the delta is inside the A/A spread, or smaller than the minimum detectable effect the run's n supports ([`methods.md#the-minimum-detectable-effect`](methods.md#the-minimum-detectable-effect)) |
| A2 | Is this cell evidence at all? | invalid cells, escaped paths | `runs.jsonl`: `valid`, `session.invalid`, `session.escapes` | a path resolves outside the cell's root, or a turn ends on an abnormal stop reason |
| A3 | Is the record attributable? | cells with a transcript, and the author on each commit | `session.attributed`, `session.sessions`, git author | no transcript, or an identity the harness did not set |
| A4 | How much of the job got done? | found over the declared set | not measured yet: the case measure is to print `found` and `declared` | `declared` is zero, so the ratio has no scale |
| A5 | What did it cost? | input, output and total tokens; wall seconds | `session.tokens`, `elapsed`, `wall_seconds` | the sum covers only part of the run's sessions |
| A6 | Did the harness behave? | cells run, invalid rate, harness commit, fixture hashes | the aggregate header | the commit or the two fixture hashes are missing, so the run cannot be placed |
| A7 | Where did the cost go? | input tokens, tool calls and opened paths with byte sizes, per assistant turn | `session.turns_detail[].input_tokens`, `.tool_calls`, `.paths[].bytes` | a turn carries no usage record, or a path inside the clone cannot be sized |

A harness defect a run finds becomes a case, a gate, or a prose entry in [`../antipatterns/README.md`](../antipatterns/README.md), not a note in a report: that is the route by which this table grows.

## The proofs

A row is only a measurement if the harness can be shown to read it correctly. These runs show that, and they are cheap because they use stubs rather than a model:

1. **A known answer.** Two configurations, one that must win and one that must lose; A1 has to separate them in the direction already known.
2. **An A/A pair.** The same configuration twice; A1's delta and sd have to come out at zero, so a later delta is read against a measured floor rather than an assumed one.
3. **A severed stream.** A run whose transcript ends on an abnormal stop reason; A2 has to mark the cell invalid, and `--require-valid` has to refuse the run.
4. **The escape counter**, because it is the row that protects every other: a run that opens a path outside its clone is not evidence, whatever else it reports.

A7's proof is the stub session in `tests/test_eval_harness.sh`: one synthetic transcript with usage, tool calls and byte-sized paths, and one outside path that the test asserts is invalid.
