---
date: 2026-10-26
type: Report
status: draft
---

# What the eval has to provide

## Objective

State the problems an eval for the instruction corpus runs into here, in a form the session that builds it can act on. This is a requirement list derived from one failed attempt, not a design and not a harness. Each item names what an eval must provide, the observation that forces it, and where the evidence lives.

## 1. Isolation of the subject from the rulings

A run must read the subject and the files that run is allowed to consult, and nothing that holds an answer.

**What happened.** The carriers live in `.agents/audits/`, inside the tree that holds the census record, the comparison records, the feedback log and the earlier fault lists. Thirty of the thirty-five completed cells of the ablation attempt read a file outside the carrier, and thirty read a prior record or an earlier fault list. The worst cell opened seventeen outside files. The vector was the shell rather than the file read: 472 `bash` calls against 71 reads, because the model orients by shelling over the tree.

**Consequence.** A brief that names one file bounds nothing, and a rule in prose that forbids reading other files is not a control. Only the directory the process runs from is.

**Evidence.** [`20261026-report-draft-ablation_problems_found.md`](20261026-report-draft-ablation_problems_found.md), and the census sessions that read the census handover before judging a carrier.

## 2. A pinned fixture, distinct from the live tree

The case's inputs must be a dated copy, and a result must name the copy it was measured on.

**What happened.** Both halves of the case are in flux during the milestone that builds the eval. The consolidation folds, splits and deletes the six carriers, and it deletes or rewrites sections of `instruction-cleanup.md`. A fixture pointed at the live tree silently becomes a different case, and a later comparison measures a corpus nobody chose.

**Evidence.** The roadmap's own ordering: the consolidation is one unit and the case set is another, and the eval row states that it depends on the census for its assertions.

## 3. Assertions that have an author

An `expected_output` must trace to a ruling recorded before the case was written.

**What happened.** The eval grades against the operator's rulings, and at the time the case set was drafted the rulings did not exist. The only answer key available was the goal-only draft's own output, which would have made one prompt the truth about the other.

**Consequence.** The order is forced: candidate sites, then rulings, then cases. An eval built before its rulings either asserts nothing or asserts a draft.

**Evidence.** The eval case set row of [`devlog/roadmap.md`](../roadmap.md), and the comparison record's own note that grading against the draft makes the draft the answer key.

## 4. A named outcome for every cell

A cell that produced nothing must not be scored, and a cell's outcome must be one of a declared set rather than whatever the runner happened to notice.

**What happened.** Three failures all looked like completion. A child process consumed the plan file and the grid ended after one cell with a zero exit code. A refusal arrived as `{"type":"FreeUsageLimitError"}` in one path and as `AI_APICallError: Free usage limit reached` in another, so the detector missed it and cells hung to their wall cap. An assignment at `--variant high` spent thirty-two thousand reasoning tokens, wrote no text, and exited zero, which read as a successful cell carrying an empty result.

**Evidence.** [`../handovers/20261026-05-workflow-opencode_run_harness_defects.md`](../handovers/20261026-05-workflow-opencode_run_harness_defects.md), and the refusal vocabulary at [`../../docs/reference/terminology.md`](../../docs/reference/terminology.md), which already names `transient`, `quota`, `capability`, `timeout` and `unknown`.

## 5. Per-cell provenance that outlives the process

For each cell: which model, which variant, which backend, which fixture copy, how many output tokens, how long. Readable without querying a vendor store.

**What happened.** The only place the empty turn was visible was the OpenCode session store, in a `data` column, because the run's own log carried the error line and nothing else. The token counts that distinguish "answered nothing" from "never asked" were one `node:sqlite` query away and nowhere else.

## 6. A stated denominator for every claim

**What happened.** The same leakage was counted twice with two instruments and two answers: a log grep over rendered tool lines found thirty of thirty-five cells reading outside the carrier; a query over the session store found thirty-six of forty-four sessions referencing a non-carrier path. Both are defensible and neither was declared, so the record carried one number and the store held another.

## How a run is stopped

**What happened.** Every stop was ad hoc and every one of them was mine, in the runner: a grep for one refusal string, a wall-cap timeout, and a loop that reached end of file and exited as if finished. Nothing recorded which cells had run, which had not, or why the run ended. Two of the three silent failures produced a smaller result set that looked like a completed one.

An eval must provide one stop channel with a declared class per stop, and a stop must leave the plan with its remaining cells named, so that a stopped run is legible as stopped rather than as small.

### Which failures are worth stopping the run for

Grouped by the response each forced, as observed:

| Response | Failure | Why |
|---|---|---|
| Stop the run | entitlement or quota exhaustion | every later cell is void, so continuing produces cells that cannot answer |
| Stop the run | a harness defect found mid-run that invalidates completed cells | the completed cells and the later cells are then measuring different things, and the difference is the defect |
| Stop the run | a configuration that cannot produce output at all, such as an assignment whose variant returns an empty turn | the same failure repeats on every remaining cell, and each repetition is scored as a success |
| Record and continue | one cell's transient failure: a lock, a wall-cap timeout, a refused attempt that a retry may clear | the failure is a property of that cell, and the run's plan is still executable |
| Invalidate and restart | the subject or the fixture changed while the run was in progress | the run then holds cells measured against two different inputs |

## What this record does not do

It proposes no harness, no case formatting, no grading mechanism and no runner. Those belong to the session that builds the eval, after the rulings exist and after the consolidation has settled the corpus.
