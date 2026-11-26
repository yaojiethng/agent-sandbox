---
date: 2026-11-25
milestone: M3.5.1 - The work-log record layer
type: Implementation
status: Closed
---

# Handover - a handover track's lifecycle

## Objective

End a handover track when its milestone closes: archive it to a git tag, remove its folder from `HEAD`, and put the next one under a gate.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No live folder names a closed milestone; the gate and the umbrella are clean over the tree. | `bash scripts/check_track_lifecycle.sh`; `bash scripts/lint.sh` | Accepted: 13 findings before the removal, 0 after; lint clean across 31 gates. |
| The gate fails a live track whose milestone the changelog closes, naming the folder and the repair. | `bash tests/test_track_lifecycle.sh` | Accepted: `test_closed_milestone_with_a_live_track_fails`. |
| The gate passes an open milestone's track, a work-unit folder and the archive, and stops on a missing changelog. | `bash tests/test_track_lifecycle.sh` | Accepted: the three passing cases and the missing-record case; 5 passed, 0 failed. |
| Every removed record is recoverable from the commit that removed it. | `git show d3160b40:devlog/handovers/M3.4.2/20261122-06-impl-record_read_once.md` | Accepted: the record renders from the base commit. |
| A citation into a retired track is a code span, and no link resolves into a retired path. | `bash scripts/check_record_citations.sh`; `grep -rn 'handovers/M3\.4\.2/'`; `bash scripts/lint.sh` | Accepted: the 13 links became code spans and the citation gate is clean. |
| The roadmap row is `[x]`, the parent task compacted to its outcome, and the landing note names the 13 ids and the archive sha. | `git diff d3160b40 -- devlog/roadmap.md` | Accepted: the diff carries the compaction and the note. |
| Every decision this record carries is realized in the files. | Step 7 read of the Decisions table | Accepted: the predicate, the no-tag archive, the gate's home, the code-span rule, the absent wrapper, the 13 tracks and the untouched archive all hold. |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A milestone is closed when `devlog/changelog.md` carries a `## <id> - <name>` heading; that heading is the one predicate the script, the gate and the reader share. | The summary table links to the changelog and the changelog is the permanent record the row names, so a second status source would be a restatement. | This record |
| No tag: the archive is the delivery commit's parent, and the landing note carries that parent's sha. | A tag cannot be pushed and does not survive the restoration -- the repo holds none, including `track-cutoff-2026-11-05` -- while the parent commit travels with the branch. | This record |
| `scripts/check_track_lifecycle.sh` is a new gate in `scripts/lint.sh`, not a rule inside `handover-format.mjs`. | The subject is a folder and its milestone, not one record's format; the two checks read different facts. | This record |
| A citation into a retired track becomes a code span naming the record id and the tag. | The `linking` convention already says a handover is named, never linked; retirement is when the link stops resolving, and the citation gate reads links only. | This record |
| No wrapper script: each retired track is one `git rm -r`, and the gate is the mechanism. | The operation is one git command; a wrapper that tags nothing would be a passthrough. | This record |
| This iteration retires the 13 tracks whose milestone the changelog closes; a folder that is not a milestone id (`T1`, `T7`, `W2`, and so on) is not the gate's subject. | The parent row's closed-row half owns those work-unit folders; the gate's rule is `closed milestone means no live track`. | This record |
| `devlog/handovers/archive/` stays. | An archive is frozen history, not a live track; the gate reads the live folder alone, the folder half that landed in `20261004-04`. | This record |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The roadmap shows no completed sub-milestone as active: M3.3.6 (17 open rows), M3.4.1 (3), M3.5.1 (6), M3.5.3 (6) and M3.3.8 (12) all carry open work, and M3.6.5 now reads Complete in the summary. The `roadmap-maintenance` pass therefore has no promotion to apply. | check | The roadmap-maintenance step reports clean on its trigger condition; the iteration does not restate the summary table. | Record |
| Tags do not survive the hand-off: the restored repo holds 0, including `track-cutoff-2026-11-05` that `roadmap.md` names as created. | obstacle | The archive is the delivery commit's parent and its sha, not a tag ref. | This record |
| 13 Markdown links resolve into the 13 tracks this iteration retires; the citation gate reads links, so each must become a code span or fail on the removal. | defect | The retirement's own carriers: 9 in `devlog/roadmap.md`, 2 in `.agents/drafts/dispatch-harness-defects-handoff.md`, 1 in `docs/development/build_operational_model.md`, 1 in `devlog/AGENT_FEEDBACK.md`. | This record |
