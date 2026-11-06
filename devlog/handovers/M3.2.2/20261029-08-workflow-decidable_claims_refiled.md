---
status: Closed
milestone: M3.2.2
type: Workflow
date: 2026-10-29
---

# Handover - the records' decidable claims move to the gates

## Objective

Refile the last open row of M3.2.2 under the milestone that owns the gates, restated so it names an outcome and leaves the method to the agent that takes it.

## Scope

One roadmap row. Its wording and its home changed; the work it describes did not.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The row sits under M3.1.2 | its position follows the gate-upkeep rows | Agent [x] `:128` |
| M3.2.2 holds no open row | the milestone's task range has no unchecked entry | Agent [x] none |
| The row states an outcome and leaves the method open | read it: the check's location and the set of decidable claims are the doer's | Agent [x] restated |
| The substance of the old row survives | the three example claims and the refiling provenance are still there | Agent [x] carried |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The row is restated as an outcome rather than a location | The old text named `scripts/lint.sh` and a single claim, which is one method among several; the requirement is that the decidable half is checked, not that a particular script holds it | this record, roadmap `:128` |
| The row moves to M3.1.2 | The check is gate upkeep, and M3.2.2's instruction-surface work already carries the neighbouring vocabulary and link checks | this record |
| The row is not ticked | Nothing was built; only its home and its wording changed | this record |

## Decisions pending

None.

## Findings

- **M3.2.2 now holds no open row.** Every task item under the milestone is closed, so the milestone is ready for `/milestone-close`, which also carries the eleven-child compaction deferred from the previous one.
- **The row's old text prescribed its own implementation.** It stated that the work lands as one claim in `scripts/lint.sh`, which fixes the method before anyone has read the records to see which claims are decidable. The restatement leaves that open, and the gate's location is now the doer's to settle.

## Completed

| File | Change |
|---|---|
| `devlog/roadmap.md` | The row removed from M3.2.2 and refiled under M3.1.2 |
