---
date: 2026-11-12
milestone: M3.7.2 - The change model and its refinements
type: Audit
status: Closed
---

# Handover - The git-discipline violations are measured and resolved

## Objective

Measure the `git-discipline` rules against the repo's real commit history, its
failure cases and its consumers, resolve the violations the measurement exposes,
re-evaluate the problem lists in the drafts and active discussion records, and
leave the evidence the scheduled convention rewrite cites.

## Scope

Works the prefactor *The git-discipline violations are found and resolved* and its
child *The drafts and active discussion records' problem lists are re-evaluated
and cleaned*, under M3.7.2's *The branch-preparation surface is one host flow*. The
reframe *The convention leads from history as a commons* stays scheduled and
depends on this row. The eval-driven reader check is the deferred, unscheduled
part. Out of scope: the convention text rewrite, the host hints (sibling row),
`history-cleanup`'s contract (its sibling), and the recovery reference's removal
(its sibling).

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A rule -> defect -> real-instance table covers every rule the convention keeps; each row names a commit id, a consumer path, or "no instance". | Read the table; count the convention's `##` rules against its rows. | Agent [x] |
| The quantitative measurement is stated and re-runnable: commit count, subject >50, body >280, type distribution, `wip:`/fixup/amend, correction commits, handover-link coverage. | Re-run the `.scratchpad` extraction; the numbers match. | Agent [x] |
| The qualitative pass names each consumer and what it cites or assumes, and each failure case with its commit id. | Each consumer has a row with a path; each failure case a commit id. | Agent [x] |
| Each violation class is adjudicated, and each record-level violation resolved: the review-range entry dropped, the uncommitted-work entry re-scoped to the rewrite, a rule with no instance named for the rewrite, a carrier fix filed. | `grep -n '2026-10-31.*review runbook lost' devlog/AGENT_FEEDBACK.md` returns nothing; `grep -n 'scoped: M3.7.2 -- the history' devlog/AGENT_FEEDBACK.md` returns the uncommitted-work entry; the table names each adjudication. | Agent [x] |
| Every problem in the three folders has a disposition; a retired file's facts are in a record that outlives it; no file an open row cites is deleted. | The disposition table lists every file; `git status` shows the retirements; `grep` confirms no open row cites a deleted file. | Agent [x] |
| The roadmap carries the evidence row, its cleanup child, and the scheduled rewrite with the dependency and the eval deferral. | `grep -n 'This row depends on the evidence row above' devlog/roadmap.md`; the child row. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The evidence pass lands first; the convention rewrite stays scheduled and depends on it; only the eval is deferred. | The rewrite is a stylistic choice backed by this measurement; the eval cannot guarantee a reproducible result today, so it is not a gate. | `devlog/roadmap.md`; this record |
| This iteration does not edit the convention text. | A carrier fix that is not a record is a finding and a row, so the rewrite keeps one subject. | this record |
| The problem inventory reads `.agents/drafts/`, `devlog/discussions/` and `src/reasoning/agent/drafts/`; the archive is read only for the records that carry a git or change-history problem, and the rest of it is not edited. | A settled record is history, not a draft; a file an open row cites is re-evaluated but not deleted, so no row loses its source. | this record |
| No new gate is added. | The measurement is a one-off in `.scratchpad/`; a gate over a historical corpus would pin a number that moves. | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The operator corrected the split: the eval is deferred, not the rewrite. The rewrite row is scheduled and depends on the evidence row. | record | the earlier mark was reverted | `devlog/roadmap.md` |
| The scan found 17 files in `.agents/drafts/`, 16 active discussion records, 86 archived records and 3 files in `src/reasoning/agent/drafts/`; six carry an explicit findings or defect heading, and the audit will classify the rest. | record | the cleanup's candidate set is larger than the explicit six | this iteration's audit |
| The row named seven feedback entries; five are no longer in `AGENT_FEEDBACK.md` by subject (commit budget 2026-10-05, correction 2026-10-18, typed delivery 2026-10-17, test helper 2026-10-20, mistyped sha 2026-10-19). The two present are the review range (2026-10-31, mitigated) and git operations over uncommitted work (2026-08-10, open). | record | the rewrite disposes of two entries, not seven | this iteration |
| The 50-character subject budget is violated by 876 of 1457 commits; the log holds three non-conforming types (`impl`, `design`, `feature`) and one `wip:` commit. The last 300 commits violate the subject budget at 41% and the body budget at 17%, and the three commits before this record are among them. | record | the budget is contested, not merely legacy | this iteration's measurement |
| The evidence pass is recorded, with the rule table, the consumers, the failure cases and the inventory, in [`20261112-report-open-git_discipline_evidence.md`](../../discussions/20261112-report-open-git_discipline_evidence.md). | record | the deferred rewrite has its requirements | the rewrite row |
| Two problem records retired after their facts were confirmed live elsewhere: the task-list/work-log error classes are enforced by the two maintenance skills, and the diff-workflow invariants are in `change_model.md`. | record | the drafts folder loses a spent requirements doc and the archive a spent change-workflow draft | this iteration |
| The closed M3.7.2 rows still carry implementation narrative and numbers (roadmap-maintenance check 3.6). | record | a number in a closed row goes stale at the next change | the milestone close's compaction |

## Completed

| File | One-line change summary |
|---|---|
| `devlog/handovers/M3.7.2/20261112-08-audit-git_discipline_evidence.md` | this record |
| `devlog/discussions/20261112-report-open-git_discipline_evidence.md` | the corpus measurement, the rule table, the consumers, the failure cases and the inventory |
| `devlog/AGENT_FEEDBACK.md` | the mitigated review-range entry dropped; the uncommitted-work entry re-scoped to the rewrite |
| `.agents/drafts/task-list-work-log-violation-requirements.md` | retired; the error classes are in the maintenance skills |
| `devlog/discussions/archive/20260925-design-draft-diff_workflow_invariants.md` | retired; the invariants are in `change_model.md` |
| `devlog/roadmap.md` | the evidence row and its cleanup child closed with the outcome |
| (maintenance) | `roadmap-maintenance` run over `devlog/roadmap.md`: no completed sub-milestone shown active; the check-3.6 finding filed above to the milestone close |
