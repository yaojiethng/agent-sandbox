---
date: 2026-11-16
milestone: M3.7.2 - The change model and its refinements
type: Documentation
status: Closed
---

# Handover - retire the concluded work-log design record

## Objective

Retire the concluded design record `20261105-design-concluded-handover_tracks.md`: move its read surface and feedback read into the seam ADR, re-point its open row, the M3.5.2 source row and the two closed handovers, and delete the record with its evidence link.

## Scope

M3.7.2, the row **The concluded work-log design record is retired**. The record is `concluded`, its row closes here, and `work-log` says a concluded design record is deleted once its row closes because the ADR holds the subject in the same mode. The read-surface table and the feedback read move into [`work_log_record_seam.md`](../../../docs/adr/work_log_record_seam.md); the M3.5.2 **Source** line and the M3.5.1 feedback row cite the ADR; the two closed handovers that link the record strip the link; the ADR's rationale drops the record's evidence link.

The M3.7.2 acceptance criterion still called `history-cleanup` a primitive beside `prepare` after handover [`20261116-05`](20261116-05-workflow-history_cleanup_primitive.md) reframed it as the operator-invoked series pass, independent of `prepare`. That carrier sits in the roadmap this iteration edits, so it is corrected here.

Out of scope: the open M3.5.1 cutover row, the track-folder relative-link re-path row, and the suite-runner deadline row.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The ADR carries `### The read surface` with the seven reads, their consumers and the built-now column; the built rows name the shipped `worklog.sh` commands; the discussion and feedback rows are shape-only. | `grep -n "### The read surface" docs/adr/work_log_record_seam.md`; read the table against `scripts/worklog.sh` | Agent [x] |
| The ADR's rationale carries no link to the record. | `grep -c "20261105-design-concluded" docs/adr/work_log_record_seam.md` is 0 | Agent [x] |
| The M3.5.2 source line and the M3.5.1 feedback row cite the ADR; no open roadmap row names the record. | `grep -n "20261105-design-concluded" devlog/roadmap.md` is 0 | Agent [x] |
| The two closed handovers carry no markdown link to the record: the M3.5.1 row names it as plain text and says it was retired, and the M3.5.3 decision cites the ADR. | `grep -rn "](.*20261105-design-concluded" devlog/handovers/M3.5.1 devlog/handovers/M3.5.3` is 0 | Agent [x] |
| The record is deleted and the lifecycle gate is clean. | `test -e` is false; `bash scripts/check_record_lifecycle.sh` | Agent [x] |
| The M3.7.2 acceptance criterion states the operator-invoked series pass, independent of `prepare`. | `grep -n "history-cleanup" devlog/roadmap.md` | Agent [x] |
| The M3.7.2 row is `[x]` and links this handover. | `grep -n "The concluded work-log design record is retired" devlog/roadmap.md` | Agent [x] |
| Lint is clean and the suite is green. | `bash scripts/lint.sh`; `TEST_PARALLEL=1 bash scripts/run_tests.sh` | Agent [x] |
| Every decision this iteration recorded is realized in the files. | the Decisions table against the Completed table | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The ADR takes the read surface; the feedback read is one row, and the feedback entry's own shape stays in `work-log`. | The ADR is the durable seat for the seam's contract; the entry shape is a rule the convention states for its writer. | this handover and the ADR |
| The built rows name the shipped commands (`latest`, `active`, `track`, `reserve-id`, `list`), not the design's `--kind handover` forms; the discussion and feedback rows are marked shape-only. | The record was written before the tool landed; copying its command names would put a command that does not exist in the ADR. | this handover |
| The closed handovers cite the ADR in plain text, not a link. | The record-tree relative links are the open M3.5.1 re-path row's defect; a new link would join it, and a closed row owns nothing. | this handover |
| The M3.7.2 acceptance criterion is corrected to the series pass, independent of `prepare`. | The landed reframe contradicts the old line, and the roadmap is the carrier this iteration edits. | this handover |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| None. | | |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The concluded record has no owner after its row closes; its read surface and feedback read are facts the ADR needs before the deletion. | record | the deletion would lose the seam's consumer map | this iteration |
| The ADR's evidence link is its only carrier to the record; the deletion breaks it. | record | an ADR reader follows a dead link | this iteration |
| Two closed handovers link the record; a closed row owns nothing, so the links must strip. | record | two dead links survive the deletion | this iteration |
| The record's read-surface commands name a `--kind handover` filter the shipped tool does not take; the ADR must name the built commands. | code | a copied table would document a command that does not exist | this iteration |
| The M3.7.2 acceptance criterion still says `history-cleanup` is a primitive beside `prepare` after handover `20261116-05` reframed it. | record | the milestone's gate contradicts the landed design | this iteration |

## Completed

| File | One-line change |
|---|---|
| `docs/adr/work_log_record_seam.md` | `### The read surface` added; the record's evidence link removed |
| `devlog/roadmap.md` | M3.5.2 source and M3.5.1 feedback row cite the ADR; the AC line corrected; the row is `[x]` |
| `devlog/handovers/M3.5.1/20261105-14-plan-handover_tracks_design.md` | The design record's row names it as retired, with no link |
| `devlog/handovers/M3.5.3/20261106-04-impl-concurrency_proof.md` | The decision cites the ADR instead of the record |
| `devlog/discussions/20261105-design-concluded-handover_tracks.md` | Deleted: its facts are in the ADR, and its row closed |
| `devlog/handovers/M3.7.2/20261116-06-docs-retire_worklog_design.md` | This record |
