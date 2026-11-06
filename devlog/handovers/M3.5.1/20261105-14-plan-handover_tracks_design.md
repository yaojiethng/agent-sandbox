---
date: 2026-11-05
milestone: M3.5.1 - The work-log record layer
type: Plan
status: Closed
---

# Handover - Handover tracks and the record read seam

## Objective

Settle the design that makes parallel milestone tracks legal, and scope the roadmap task it lands under, before any work unit is cut.

## Scope

Pulled forward from T5 into M3.5.1 as its stopgap slice, and consumed by M3.5.3's parallel-milestone rule and the T5 record-storage rewrite. This session is documents only: a design record, its eventual ADR, a scoped roadmap row, and this handover. The `active-milestone` scalar is set to M3.5.1 for the session and returns to M3.3 at close, per the `20261021-08` precedent.

Out of scope, with reasons: every implementation carrier in the design's propagation table belongs to the units `/scope` cuts after this plan; the 240-file migration belongs to the second unit; and the full track dimension of [`docs/reference/workflow_statechart.md`](../../docs/reference/workflow_statechart.md) stays with the chart-skill row.

**Scope amendment (2026-11-05).** The M3.5 reorganization was added after the scope gate: M3.5 splits into M3.5.1 (work-log), M3.5.2 (task-list) and M3.5.3 (unified), and T5 is absorbed into M3.5. It rides this plan's single commit and produces no separate commit.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The design settles the record model and the read seam | the design record states the invariants, the smell family, the options, the chosen seam and the rejected alternatives | Agent [x] |
| The design concludes into an ADR | `docs/adr/work_log_record_seam.md` carries the decision, and the design record's state is `concluded` | Agent [x] |
| The roadmap task is scoped, and no unit is cut | the M3.5.1 row names the outcome, the mechanism, the evidence and the end state; the unit table is left to `/scope` | Agent [x] |
| The plan's carriers are consistent | `bash scripts/lint.sh` clean and `bash scripts/check_handover_format.sh` clean | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The seam's final scope is `work-log`, not the task list | task-list violations have had no real consequence; work-log violations cause administrative churn | the design record |
| Handovers first, with the data shape built to extend to discussions and the feedback record | one tool proves the seam before it generalizes | the design record |
| A task-list tool is a separate, later decision | taken only if the work-log tool works well | the design record |
| M3.5 is split into M3.5.1 (work-log), M3.5.2 (task-list) and M3.5.3 (unified), and T5 is absorbed into M3.5 | the work-log layer is the stopgap that unblocks tracks; the task list and the spanning rules follow it | `devlog/roadmap.md` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Where is the record layout declared? | every gate and the tool | `src/build/container-interface.json`; a new `src/build/record-layout.json`; absorb `recordTrees` from `.markdownlint-cli2.mjs` |
| Where is a track's reserved id block recorded? | the id rule and the migration | the track folder's `README.md`; the roadmap row; a `devlog/tracks/` ledger |
| When is the cutoff tag cut? | the fork point for the first track | after the contract unit; after the migration unit |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `scripts/lint/handover-format.mjs` scans `devlog/handovers` flat, so nested folders would pass unchecked | defect | the gate would report clean over an unscanned tree | the contract unit |
| `runbooks/chain.md` Step 4 validates `Active` only on the most recent handover, and Step 1 reads order from the filename | defect | the chain audit would misreport every track but the last | the contract unit |
| The migration is cheaper than it looked: `scripts/lint/numbering.mjs` walks recursively, so bare ids survive the folder move and only relative links re-path | scope | the migration is a link re-path, not an id rewrite | the migration unit |
| The "latest or scalar" list is one instance of a class: a skill or gate re-derives state `work-log` owns, and the layout is restated in many carriers | scope | the plan must settle the read seam, not patch eight prompts | this record |

## Completed

| File | Change |
|---|---|
| [`20261105-14-plan-handover_tracks_design.md`](20261105-14-plan-handover_tracks_design.md) | this record |
| [`../discussions/20261105-design-concluded-handover_tracks.md`](../discussions/20261105-design-concluded-handover_tracks.md) | opened the design record with the confirmed model and the smell family, and concluded it into the ADR |
| [`../../docs/adr/work_log_record_seam.md`](../../docs/adr/work_log_record_seam.md) | the standing decision: the work-log layout is declared once and derived reads go through one tool |
| [`../roadmap.md`](../roadmap.md) | `active-milestone` set to M3.5.1 for the session; the M3.5 reorg into M3.5.1/2/3; T5 absorbed; the scoped stopgap row added |
