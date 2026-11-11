---
date: 2026-11-11
milestone: M3.3.5 - The eval pipeline
type: Housekeeping
status: Closed
---

# Handover - M3.3.5 keeps only the rows its close needs

## Objective

Leave M3.3.5 with the rows its close needs: move the three non-eval rows to their owners, add the ruling-table prefactor that gates the separating case, and land the instruction-authoring read-before row.

## Scope

The five open M3.3.5 rows at triage. The decision-records ordering row moves to M3.5.3, the doc-maintenance eval restart moves to `roadmap_future.md`, and the greenfield dispatchability question moves to M4.3. The instruction-cleanup row gains the ground-truth ruling table as a sub-row, and `AGENTS.md` gains `instruction-authoring` in its read-before table.

Out of scope: the ruling table's content and the instruction-cleanup case run, which are the remaining M3.3.5 work.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The three non-eval rows are gone from M3.3.5 and present at their destinations. | `grep -n 'decision-records ordering rule\|doc-maintenance eval restart\|greenfield documentation ever becomes dispatchable' devlog/roadmap.md devlog/roadmap_future.md` | Agent [x] |
| The instruction-cleanup row names its prefactor and the prefactor row exists. | `grep -n 'ground-truth ruling table' devlog/roadmap.md` | Agent [x] |
| `AGENTS.md` routes a skill edit to `instruction-authoring`. | `grep -n 'instruction-authoring' AGENTS.md` | Agent [x] |
| The gates stay clean. | `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The decision-records ordering row moves to M3.5.3. | It is a rule spanning record models, which M3.5.3 owns. | this record; `devlog/roadmap.md` |
| The doc-maintenance eval restart moves to `roadmap_future.md`. | It is a second eval case, not the case M3.3.5's acceptance needs. | this record; `devlog/roadmap_future.md` |
| The greenfield dispatchability question moves to M4.3. | It asks whether work becomes dispatchable, which is a dispatch question. | this record; `devlog/roadmap_future.md` |
| The ruling table is a sub-row of the instruction-cleanup case. | It has its own outcome, acceptance and record, and the case cannot start without it. | this record; `devlog/roadmap.md` |
| The instruction-authoring read-before row lands now. | It is one line and fixes a routing defect the eval work hit. | this record; `AGENTS.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| M3.3.5's only close blocker is now the instruction-cleanup case, and its prefactor is the ruling table. | record | The close sequence is one decision and one case run. | this record |
| The doc-maintenance restart no longer holds the milestone. | record | The milestone does not wait for a case whose contrast has not yet been found. | `devlog/roadmap_future.md` |

## Completed

| File | One-line change summary |
|---|---|
| `devlog/roadmap.md` | Moves the decision-records row to M3.5.3; adds the ruling-table sub-row and the case dependency. |
| `devlog/roadmap_future.md` | Re-files the doc-maintenance restart and the greenfield dispatchability question. |
| `AGENTS.md` | Adds `instruction-authoring` to the read-before table. |
| `devlog/handovers/M3.3.5/20261111-04-chore-m3_3_5_close_moves.md` | This record. |
