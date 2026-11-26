---
date: 2026-11-25
milestone: M3.5.1 - The work-log record layer
type: Workflow
status: Closed
---

# Handover - one sub-milestone per record kind

## Objective

Move the feedback record and the discussion-record corpus out of M3.5.1 into a sub-milestone each, so the work-log record layer owns the handover track alone.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No feedback or cutover-corpus row sits under M3.5.1. | `awk '/^##### M3\.5\.1/,/^##### M3\.5\.2/' devlog/roadmap.md` | Accepted: 0 rows match. |
| Two sub-milestones exist, each naming one record kind and the rows it owns. | `grep -n '^##### M3\.5\.[56]' devlog/roadmap.md` | Accepted: `610:##### M3.5.5 - The feedback record`, `620:##### M3.5.6 - The discussion record corpus`. |
| The summary table carries both rows after M3.5.4. | `sed -n '51,57p' devlog/roadmap.md` | Accepted: both rows follow the M3.5.4 row, `Not started`. |
| The umbrella, the record gates and the suite are clean. | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | Accepted: lint clean across 31 gates; 1754 passed, 0 failed. |
| Every decision this record carries is realized in the files. | Step 7 read of the Decisions table | Accepted: the two sections carry the moved rows unchanged, both `Not started`, both `Depends on: M3.5.1`. |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Two sub-milestones, not one: `M3.5.5 - The feedback record` and `M3.5.6 - The discussion record corpus`. | Each owns one record kind, so a reader of either section holds one subject. | This record |
| The numbering follows M3.5.4 and both read `Not started`, with `**Depends on:** M3.5.1`. | Neither is cut into iterations, and neither is blocked by M3.5.3's rules. | This record |
| The rows move unchanged, including the two feedback children. | Their text was settled on operator direction; this iteration changes their home, not their content. | This record |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Operator direction, 2026-11-25: the feedback record and the discussion corpus are a different sub-milestone each. | steering | M3.5.1 keeps the handover track and the seam; the other two record kinds leave it. | This record |
