---
date: 2026-11-05
milestone: M3.5.1 - The work-log record layer
type: Workflow
status: Closed
---

# Handover - The work-log carriers call the tool

## Objective

Replace the work-log derived reads the procedures and reference documents compute by hand with calls to `scripts/worklog.sh`.

## Scope

The second unit of M3.5.1. U1 landed the declaration, the accessor and the tool. This unit points the work-log carriers at it: the five prompts that read the latest or the active handover, the bootstrap setup, the chain runbook's order and `Active` checks, and the three reference documents that restate the handover path or identity.

The task-list reads stay out of this unit. `active-milestone` in `milestone-start`, `milestone-close`, `backlog-triage` and `check-in` is the task-list's state, not the work-log's, and the seam's scope is the work-log; those reads change in M3.5.2 or M3.5.3, not here. The flat tree stays valid; the 240-record migration is U3.

The `active-milestone` scalar is set to M3.5.1 for the iteration and returns to M3.3 at close.

Out of scope, with reasons: the task-list reads above; the migration and the tag (U3); the discussion and feedback commands, which stay shape-only per the design record.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No prompt computes a work-log read | a grep of `workflow/` finds no `ls devlog/handovers`, no `sort \| tail -1`, and no `grep -l "Status: Active"` over handovers | Agent [x] |
| The orient step calls the tool | `iter.md` and `plan.md` read the latest handover through `scripts/worklog.sh latest` | Agent [x] |
| The commit check calls the tool | `commit.md` asks `scripts/worklog.sh active` for the open handover | Agent [x] |
| The milestone prompts call the tool | `milestone-start.md` and `milestone-close.md` read the latest through the tool | Agent [x] |
| The chain runbook is per-track | `chain.md` Step 1 takes git order and Step 4 validates `Active` per track | Agent [x] |
| The references name the track folder | `documentation_taxonomy.md`, `terminology.md` and `workflow_statechart.md` carry the folder or the per-track read | Agent [x] |
| The task-list reads are unchanged | the `active-milestone` field is still read in `milestone-start`, `milestone-close`, `backlog-triage` and `check-in`; only the handover clause on the changed lines moved | Agent [x] |
| The suite is green | `bash scripts/lint.sh` and `bash scripts/run_tests.sh` clean | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The prompts call `scripts/worklog.sh` directly | the tool is the seam, and a prompt that restates the read is the duplication the unit removes | this record |
| The chain runbook reads the project's work-log convention for the tool, and falls back to listing the folder | the runbook ships to projects that may not carry the tool; the convention is the portable pointer | this record |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| The statechart's full track dimension | the unit states one track; a second chart is the chart-skill row's | one sentence here, or the full dimension now |

## Findings

None.

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/iter.md`, `plan.md` | the orient read is `bash scripts/worklog.sh latest` |
| `workflow/coding-agent/prompts/commit.md` | the open-handover check is `bash scripts/worklog.sh active` |
| `workflow/coding-agent/prompts/milestone-start.md`, `milestone-close.md` | the latest handover is read through the tool; the `active-milestone` read is unchanged |
| `workflow/coding-agent/prompts/bootstrap.md` | the setup creates `devlog/handovers/<track>/` |
| `workflow/coding-agent/skills/handover-maintenance/runbooks/chain.md` | Step 1 takes git order; Step 4 validates `Active` per track and names the convention's tool |
| `docs/reference/documentation_taxonomy.md`, `terminology.md` | the handover path is the track folder |
| `docs/reference/workflow_statechart.md` | `it_open` is per-track, and the chart says it models one track |
| `.agents/skills/numbering/SKILL.md` | a handover id is an identity, not an ordered unit |
| `devlog/handovers/20261105-16-workflow-worklog_carriers.md` | this record |
| `devlog/roadmap.md` | write-back: None; the M3.5.1 row stays open for U3 |
