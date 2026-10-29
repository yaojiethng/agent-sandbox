---
date: 2026-10-28
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - `/maintenance` retires, with no caller and no acceptance to lose

## Objective

Retire the `/maintenance` entry point and the record-audit acceptance the milestone was still waiting on, because nothing in the tree invokes it and `check-in` already holds the three parts it existed for. Carry the two things it and the adjacent brief were the last holders of.

## Scope

The entry point, its rows and the brief that shared its sweep: `.agents/drafts/maintenance.md`, the maintenance cluster's `/maintenance` half, the acceptance row that would have been its first run, `.agents/drafts/close-the-model-bypass-run.md`, and the three dispatch invariants the draft was the last carrier of.

Out of scope, one sentence each with the reason: `doc-maintenance` is untouched, because it has three callers and a subject that outlives the records; the two payloads are untouched, because their checks are live and invoked; the ADR that fixes "the maintenance surface" is untouched, because it names the four skills and never named the bridge.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The draft is deleted | `ls .agents/drafts/maintenance.md` prints nothing | Agent [x] |
| Nothing invokes it | `grep -rn '`/maintenance`' workflow src docs` prints nothing; the closed rows name it only to record the retirement | Agent [x] |
| The three rules landed where the auditor is dispatched | `grep -c 'foreground of the call' workflow/coding-agent/skills/check-in/auditor-invocation.md` prints `1` | Agent [x] |
| The acceptance is no longer owed | `grep -c 'Manual quality pass and acceptance' devlog/roadmap.md` prints `0` | Agent [x] |
| One row records the retirement | `grep -c 'retires instead of being accepted' devlog/roadmap.md` prints `1` | Agent [x] |
| The payloads keep their callers | `grep -c 'roadmap-maintenance'` is non-zero in `check-in/SKILL.md`, `iter.md`, `wrapup.md` and `milestone-close.md` | Agent [x] |
| The bypass brief is deleted | `ls .agents/drafts/close-the-model-bypass-run.md` prints nothing | Agent [x] |
| Its measurement survives in a row | `grep -c 'MissingSessionID' devlog/roadmap.md` prints `1`, on the M3.6 seam row | Agent [x] |
| No row claims a filing that does not exist | `grep -c 'dispatch half is filed under M3.6' devlog/roadmap.md` prints `0` | Agent [x] |
| The gate row still states its own constraints | `grep -c 'the exempt set stays explicit' devlog/roadmap.md` prints `1` | Agent [x] |
| No link or shape gate fails | `bash scripts/lint.sh` clean across 15 gates, and the suite passes | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Retire rather than accept | the call graph settles it: no prompt, skill or statechart invoked the entry point, and `check-in` held the invocation, the schema and the disposition already | the closed roadmap row |
| The rescope that preceded it folds into the same unit | it produced the evidence that retired the draft, and a rescope followed the same day by a retirement is one history, not two | this handover |
| The three dispatch invariants move to the auditor invocation | that file is where exactly these auditors are dispatched, and each failure there is silent; `sequential-work.md` keeps the same rule for its own dispatch shape | `auditor-invocation.md`, `## Running the dispatch` |
| The acceptance row is deleted rather than closed | it asked for one dispatch whose result a second agent reads, and that dispatch would have been the entry point's first run | the closed roadmap row |
| `doc-maintenance` is not touched | three callers, a shipped subject, and a claim ledger, which is what separates a check that pays from a bridge that does not | no change |
| The bypass brief retires into the rows that carry it | its gate half is already a row stating the matcher, the exempt set and the failing-first requirement, and its carrier list had gone stale: six of eleven paths it named no longer exist | the two rows |
| Its four dispatch items are filed under M3.6 rather than dropped | a row claimed they were filed there, and none was; the measurement is a dated output that cannot be re-derived cheaply, so it moves into the row that owns the seam | the M3.6 seam row |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Whether a decidable check over the records is still worth filing | the row filed earlier today asking for one, against the ruling that record audits produce churn on a format the task-list rewrite will change | keep it as a write-time gate, or delete it and re-file after the rewrite |
| Whether `AGENT_FEEDBACK`'s growth gets an owner | it is a live, read record with no expiry rule | `work-log` or `doc-maintenance`, not a maintenance entry point |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The entry point had no caller in any prompt, skill or statechart | evidence | the milestone's open acceptance waited on a run nobody had a reason to make | the retirement |
| `check-in` grew the invocation, the schema and the disposition, so the bridge was bypassed by accretion rather than decided against | structure | its rows still read as open work | the closed rows |
| The bypass brief's carrier list was a measurement from 2026-10-18 and six of its eleven paths are gone, one of them the caller it named as legitimate | evidence | the list could not be acted on, and the brief re-derived it before use, which is why retiring it lost nothing | the M3.6 row keeps the measurement, not the list |
| The road map claimed the dispatch half was filed under M3.6 and no such row existed | task list | a reader would have looked for work that was never written | filed as one row |
| The ADR that fixes "the maintenance surface" names `document` as one of its skills, and `/document` is a prompt that invokes `doc-maintenance` | docs | the ADR's inventory is one stage behind the tree; not this unit's to correct | flagged only |

## Completed

| File | Change |
|---|---|
| `.agents/drafts/maintenance.md` | deleted, after a same-day rescope to 96 lines |
| `.agents/drafts/close-the-model-bypass-run.md` | deleted, 77 lines, its measurement carried into the roadmap |
| [`workflow/coding-agent/skills/check-in/auditor-invocation.md`](../../workflow/coding-agent/skills/check-in/auditor-invocation.md) | gains `## Running the dispatch`: foreground, log to a file, judge the report not the exit code, and the worker never merges |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the cluster restated to `/document` alone; the `/maintenance` row closed with the call-graph evidence; the acceptance row deleted; the rescope row corrected; the bypass gate row repointed at the new M3.6 row; the M3.6 seam row filed with the dated measurement |
