---
date: 2026-11-11
milestone: M3.3.5 - The eval pipeline
type: Workflow
status: Closed
---

# Handover - The history-cleanup method is relaxed and its audit lands

## Objective

Record the landed history-cleanup change as one unit, so the commit has a handover and the workflow skill's current shape is traceable.

## Scope

Commit `8c75b5e6`: `workflow/coding-agent/skills/history-cleanup/SKILL.md`, its `scripts/audit.sh`, and `tests/test_history_cleanup_audit.sh`. The record is written after the commit landed, and is filed under the active milestone's track because no roadmap row names this workflow-skill maintenance edit.

Out of scope: the check-in cleanup that marks the stale instruction-growth row and repairs the dead paths in `AGENT_FEEDBACK.md`; that is an inert-fix commit and carries no handover of its own.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The audit suite passes. | `bash tests/test_history_cleanup_audit.sh` -> 9 passed, 0 failed. | Agent [x] |
| The audit script parses. | `bash -n workflow/coding-agent/skills/history-cleanup/scripts/audit.sh` -> ok. | Agent [x] |
| The lint gate is clean. | `bash scripts/lint.sh` -> 27 gates, clean in 10s. | Agent [x] |
| The commit carries the three files it claims. | `git show --stat 8c75b5e6` -> `SKILL.md`, `scripts/audit.sh`, `tests/test_history_cleanup_audit.sh`. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The method is the agent's; the invariants, checks and two review gates are fixed. | The skill's job is the record, not the operation, and a departure nobody can see is the failure it prevents. | `SKILL.md` `**The method is yours.**` |
| The gate runs in each commit's own tree. | Today's gate is not the gate of its day, so a range whose tooling tightened must be judged where each commit was written. | `SKILL.md` `## Reorganize the series` |
| The proposal runs in two stages: the manifest, then a candidate on a scratch ref. | A unit boundary is cheap to change before the build and expensive after. | `SKILL.md` `## Propose the target series, in two stages` |
| Eight hand-run checks move into `scripts/audit.sh`. | A check that stays a hand-run diff drifts; one script gives the same answer on every run. | `SKILL.md` `## Run the audit` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The commit landed before its handover, so this record is written retroactively and rides the check-in cleanup commit. | record | The unit had no record, and a later reader could not trace the skill's current shape. | this record |
| No roadmap row names this workflow-skill maintenance edit. | record | The handover is assigned to the active milestone's track but no task row marks it. | this record |

## Completed

| File | One-line change summary |
|---|---|
| `workflow/coding-agent/skills/history-cleanup/SKILL.md` | Relaxes the method, adds the two-stage proposal, and moves the checks into the audit. |
| `workflow/coding-agent/skills/history-cleanup/scripts/audit.sh` | Runs the eight checks behind one command. |
| `tests/test_history_cleanup_audit.sh` | Holds the audit's nine cases. |
| `devlog/handovers/M3.3.5/20261111-03-workflow-history_cleanup_method_and_audit.md` | This record. |
