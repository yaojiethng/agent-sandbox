---
date: 2026-11-26
milestone: M3.5.6 - The discussion record corpus
type: Workflow
status: Closed
---

# Handover - Task cleanup is one procedure

## Objective

Name the procedure both end paths run, and state its scope, so a cancelled row and a completed row cannot clean up differently.

## Scope

A tenth row on `M3.5.6`: a `task-list` clause naming the procedure and its two triggers, the scope sentence, and one sentence of `work-log` replaced with a pointer to the trigger.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `task-list` states both triggers and the scope. | `grep -n 'Task cleanup runs when the row ends' .agents/skills/task-list/SKILL.md` | Agent [x] |
| `work-log` names the trigger and states the record rule once. | `grep -n 'cleaned up in the same commit' .agents/skills/work-log/SKILL.md` | Agent [x] |
| The gates and the suite pass. | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| One procedure, two triggers: the row completes, or the row is cancelled and deleted. | The two paths had diverged: the close deleted its records, and the cancellation clause was the only place that named a deletion at all. | `task-list` |
| Cleanup covers the record layer and no deliverable. | A task delivers by completing, and a completion is the commit that lands under a row which closes, so no cancelled row owns a delivered file. | `task-list` |
| `task-list` owns the trigger and `work-log` owns what happens to a record. | One fact, one owner: the row's end is a roadmap concern, and the record's fate is a record concern. | both |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The deliverable gap the previous row raised is closed by the delivery rule rather than by cleanup: partial work lands as a row that completes, so the cancelled row is left with records alone. | model | cleanup is complete over everything a cancelled row can own | `task-list` |
| The cancellation clause was the only statement that a cancelled row deletes anything, and it named the discussion record alone. | record | a cancelled row's records were cleaned by an implication rather than by a procedure | `task-list` |
