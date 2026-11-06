---
date: 2026-10-23
milestone: M3.3.2 - Retire the policy form
type: Housekeeping
status: Closed
---

# Handover - The cited-command gate is retired and its surviving half is refiled

## Objective

Retire the cited-command half of the roadmap row, reject the design that carried it, and file the chart's command-table equality as its own row under the milestone that owns the chart.

## Scope

This iteration continues the milestone's cheap-row pass from handover `20261023-15`, and works the roadmap row **A cited command resolves to a file, checked mechanically**. The row held two subjects. The operator ruled on 2026-10-23 that the citation half is not worth a gate: pi rejects an unknown command when the operator types it, and a resolver cannot be complete over the commands an operator installs. The chart's command-table equality is a different subject and moves to M3.3.3 rather than closing with the row.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The roadmap carries no cited-command row | `grep -c 'cited command resolves' devlog/roadmap.md` prints `0` | Accepted: prints `0` |
| The command-table row is filed under M3.3.3 | `grep -n "command table is checked" devlog/roadmap.md` shows the row and handover `20261023-16` | Accepted: the row sits under M3.3.3 and cites the handover |
| The design record is rejected and renamed | `ls devlog/discussions/20261023-design-rejected-cited_command_gate.md` succeeds and its frontmatter reads `status: rejected` | Accepted: the file exists and line 2 reads `status: rejected` |
| The old design path is gone | `ls devlog/discussions/20261023-design-draft-cited_command_gate.md` fails | Accepted: the old path is gone |
| The census entry points at the new row | `grep -n 'command-table gate under M3.3.3' devlog/roadmap_future.md` finds it | Accepted: the dependency note names it |
| The closed handover's link follows the rename | `grep -n 'rejected-cited_command_gate' devlog/handovers/20261023-07-workflow-derived_artifacts_census.md` finds it | Accepted: the Completed row points at the new name |
| The umbrella is clean | `bash scripts/lint.sh` | Accepted: clean across 11 gates |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The design is `rejected`, not `superseded` | The cited-command gate was decided against, so the record's own status vocabulary names the outcome | the design record's `## Outcome` |
| The command-table row goes to M3.3.3 | M3.3.3 already carries the chart-maintenance row, and the gate is the chart's, not the policy-form milestone's | the M3.3.3 row |
| The dispatch cells are not gated | A cell names what its prompt reaches; `rebase.md` shows that claim can be wrong, but a gate over it needs the same reading the prompt does, so it stays a reading and is recorded in handover `20261023-14` | handover `20261023-14`, `## Findings` |

## Decisions pending

None.

## Findings

- **The census's dependency note and not-in-scope bullet named the retired row.** Both now point at the M3.3.3 row. The not-in-scope bullet keeps its meaning: the inventory milestone still does not build either equality gate.

## Completed

| File | One-line change summary |
|---|---|
| [`devlog/roadmap.md`](../roadmap.md) | the cited-command row is removed and the command-table gate is filed under M3.3.3 |
| [`devlog/roadmap_future.md`](../roadmap_future.md) | the dependency note and the not-in-scope bullet point at the new row |
| [`devlog/discussions/20261023-design-rejected-cited_command_gate.md`](../discussions/20261023-design-rejected-cited_command_gate.md) | the design is renamed to `rejected` and carries the outcome |
| [`devlog/handovers/20261023-07-workflow-derived_artifacts_census.md`](../handovers/20261023-07-workflow-derived_artifacts_census.md) | the link follows the rename |
