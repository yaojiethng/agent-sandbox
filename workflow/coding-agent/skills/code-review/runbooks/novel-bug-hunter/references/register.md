# The hunter register

The run writes a pair: a JSON Lines file for labels, a prose report for reasoning. The JSONL carries one object per finding; the report carries the coverage argument and the reasoning. A label is written in one place only.

## The row

| Field | Meaning |
|---|---|
| `id` | stable, never renumbered |
| `title` | one line, the claim |
| `component` | the unit under hunt |
| `contract` | the record the invariant comes from |
| `kind` | `state`, `transition`, `guard`, `policy` |
| `invariant` | the id the contract uses |
| `class` | `gate gap`, `coverage gap`, `code row`, `contract gap` |
| `severity` | `blocker`, `major`, `minor` |
| `status` | `open`, `confirmed`, `dropped` |
| `reproducer` | path that fails today |
| `gate` | `mutation`, `invariant`, `suite` |
| `gate_gap` | why that gate stayed green |
| `check` | the case or row that would catch it |
| `files` | files the finding touches |
| `evidence` | command, output, seed |

## Status

`open` when recorded, `confirmed` when the confirmation pass reproduces it, `dropped` when it cannot. A dropped row stays in the file: the register records what was claimed as well as what survived.

## Integrity

Ids ascend and appear once. The report's counts are read from the file, never stated. A finding the report describes but the file does not carry is a record defect.
