---
date: 2026-11-09
milestone: M3.7.1 - Gate boundary capability
type: Plan
status: Closed
---

# Handover - Open the git boundary and gate boundary milestones

## Objective

Open `M3.7 - Git boundary and repository state` and its child `M3.7.1 - Gate boundary capability`, move the git-related and git-maintenance task rows into M3.7, move the draft lifecycle work into M3.7.1, remove the duplicate filings, consolidate the T4 harness-packaging row and standalone section into one T4 task, and cut the cross-chart state-machine row into owner-aligned work.

## Scope

This is a record-only iteration. It moves the four 2026-11-08 draft lifecycle handovers from `devlog/handovers/T7/` to `devlog/handovers/M3.7.1/`, edits their `milestone` field, and changes no other content. It moves the git boundary row and the git-maintenance rows out of T7 and T1 into M3.7, and the draft lifecycle rows out of T7 into M3.7.1. It removes the duplicate capacity-signal row from T7, the environment-change and STE-clean sections from `roadmap_future.md`, and the two completed future sections whose capabilities the M2.6 changelog entry already records. It also folds the completed M3.5.4 change-model row into M3.7 and removes the now-empty M3.5.4 section; the summary row keeps its changelog link. It consolidates the T4 harness-packaging row and the standalone `Harness Packaging and Versioning` section into one T4 task, because the row claimed the section's self-contained scope without carrying it. It cuts the cross-chart state-machine row out of M3.7.1: the change model goes to M3.7, the workflow chart to M3.3.6, and the execution lifecycle to M3.4.1.

Out of scope: the T1 eval duplicate, which M3.3.5 owns and must re-file.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `M3.7` is titled `Git boundary and repository state`, and `M3.7.1` is titled `Gate boundary capability`; both summary rows read `In progress`. | `rg -n 'M3\\.7.*In progress' devlog/roadmap.md`; `rg -n '^#### M3\\.7' devlog/roadmap.md`; `rg -n '^##### M3\\.7\\.1' devlog/roadmap.md` | Agent [x] |
| All git-related and git-maintenance task rows are under M3.7, and none remains in T1 or T7. The completed change-model row moves out of M3.5.4. | `rg -n -e 'Git boundary and repository state' -e 'git-discipline.*rewritten' -e 'Commit-metadata capture' -e 'Git policy rewrite' -e 'WIP-commit policy' -e 'A correction crossing two iterations' -e 'The commit and the recovery runbooks' devlog/roadmap.md` | Agent [x] |
| M3.7.1 carries the three completed draft lifecycle rows and the two completed package rows; the cross-chart row is gone. | `rg -n -e 'Draft consumes the package fork point' -e 'Replace .*draft-state' -e 'draft lifecycle transition model' -e 'Merge the two package prompts' -e 'Harness export and draft invocation seam' devlog/roadmap.md`; `rg -n 'Run the state-machine specification workflow' devlog/roadmap.md` | Agent [x] |
| The cross-chart row is cut by owner: the change model under M3.7, the workflow chart under M3.3.6, and the execution lifecycle under M3.4.1. | `rg -n -e "change model's three transitions" -e "workflow chart's transitions" -e "execution lifecycle is one evidenced" devlog/roadmap.md`; `rg -n 'Run the state-machine specification workflow' devlog/roadmap.md` | Agent [x] |
| The four 2026-11-08 handovers live under `devlog/handovers/M3.7.1/`, and each names `M3.7.1 - Gate boundary capability`. | `rg -n '^milestone:' devlog/handovers/M3.7.1/20261108-0*.md`; `bash scripts/worklog.sh list --track M3.7.1` | Agent [x] |
| T7 retains the sandbox-persistence rows and no duplicate git-boundary row. | `sed -n '/^#### T7 /,/^#### T8 /p' devlog/roadmap.md` | Agent [x] |
| The capacity signal has one open row, under M3.6.2; environment-change persistence has one row, under M3.4.3; the STE-clean sweep has one row, under T8; the completed future sections are gone. | `rg -n -e 'capacity signal' -e 'Environment-change persistence' -e 'STE-clean sweep' -e 'Copy-Model Seeding' -e 'M2\\.6\\.7' devlog/roadmap.md devlog/roadmap_future.md` | Agent [x] |
| The T4 packaging task is the only record: the standalone section is gone, and the row states the self-contained, atomic and version outcomes. | `rg -n 'Harness Packaging and Versioning' devlog/roadmap.md devlog/roadmap_future.md`; `sed -n '/^#### T4 /,/^#### T5 /p' devlog/roadmap.md` | Agent [x] |
| The record gates are clean. | `bash scripts/check_handover_format.sh`; `bash scripts/check_record_names.sh`; `bash scripts/check_record_lifecycle.sh`; `bash scripts/check_markdown.sh`; `bash scripts/lint.sh` | Agent [x] |
| No code or test file changed. | `git diff --name-only` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Open `M3.7 - Git boundary and repository state` and `M3.7.1 - Gate boundary capability`, not a track child. | The operator does not want the slice under a track. M3.7 is the git bin; M3.7.1 is its gate-boundary child. | This handover; `devlog/roadmap.md` |
| Do not backfill a milestone-open commit before the work. | Inserting one would rewrite four reviewed, handover-linked commits and assert a milestone that did not exist. The branch is local, but history is still a commons. Open the bins in a new `plan:` commit and say the work predates them. | This handover |
| Move the rows; leave no pointer row in T1 or T7. | A pointer row is a second open work item and bloats the roadmap. The owning milestone is the row's home. | This handover |
| Keep M3.6.2 for the capacity signal, M3.4.3 for environment-change persistence, and T8 for the STE-clean sweep. | Each is already the row's owner; the duplicate is removed rather than the owner changed. | `devlog/roadmap.md` |
| Remove the completed `Copy-Model Seeding` and `M2.6.7` sections from `roadmap_future.md`. | Both are completed capabilities already recorded in the M2.6 changelog entry; a planning file is not their home. | `devlog/roadmap_future.md` |
| The four closed handovers keep their content and change only their folder and `milestone` field. | The work happened under T7 before M3.7.1 existed. The re-file corrects the association, not the history. | `devlog/handovers/M3.7.1/` |
| T4 owns the full packaging milestone; the standalone section is removed. | One subject, one owner. The T4 row already claimed the subject but carried only part of it, and T4 holds the make/install surface the work touches. The task states the outcomes and leaves the packaging method to the implementer. | This handover; `devlog/roadmap.md` |
| Cut the cross-chart state-machine row by owner: change model to M3.7, workflow chart to M3.3.6, execution lifecycle to M3.4.1. | The row named four subjects and would have blocked M3.7.1 on work outside the git boundary. Each row now sits with the milestone that owns the chart. The workflow row is the one that may split by region at its scope gate. | This handover; `devlog/roadmap.md` |
| Leave the M2.7 changelog's `roadmap_future.md` pointer as history. | A closed changelog entry does not change; the T4 row is the live owner, and the entry records where the deferral was filed at the time. | This handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The capacity signal was one task in two open rows, T7 and M3.6.2. | record duplication | A reader could not tell which row owned the work, and a close could mark one without the other. | Fixed here: the T7 row is removed; M3.6.2 owns it. |
| Environment-change persistence was stated in an M3.4.3 row and a `roadmap_future.md` section. | record duplication | The two records could drift and one could close while the other stayed open. | Fixed here: the future section is removed; M3.4.3 owns it. |
| The STE-clean sweep was stated in a T8 row and a `roadmap_future.md` section. | record duplication | Same as above. | Fixed here: the future section is removed; T8 owns it. |
| `roadmap_future.md` carried two completed sub-milestones as planning detail. | record drift | Completed detail belongs in the changelog, not the planning file. | Fixed here: both sections are removed; the M2.6 changelog entry records the capabilities. |
| The T1 eval row and M3.3.5 carry the same eval work. | record duplication | Two owners for one pipeline. | Out of scope; M3.3.5 owns the re-file. |
| The T4 harness-packaging row claimed the standalone `Harness Packaging and Versioning` section's self-contained scope but carried only atomic install and semver. | record duplication | Completing the row would leave the self-contained artifact open; the ADR defers semver to a full-packaging milestone the row did not name. | Fixed here: T4 owns it; the row states the self-contained, atomic and version outcomes and the standalone section is removed. |
| The cross-chart state-machine row named four charts across three owners and made M3.7.1 wait on workflow and execution work. | scope defect | M3.7.1 could not close on the git boundary; the workflow chart is M3.3.6's map and the execution lifecycle is M3.4.1's. | Fixed here: the row is cut into three owner-aligned rows; M3.7.1 keeps only the draft chart. |
| The `git-discipline` rewrite and the completed git-policy rows lived under T1. | mis-filed rows | The git-maintenance surface had no single home. | Fixed here: moved to M3.7. |
| The completed `The change model and the change flow` row was a second git home under M3.5.4. | mis-filed row | The git history was split across M3.7 and a closed M3.5 child. | Fixed here: the row moved to M3.7; the empty M3.5.4 section is removed and its summary row keeps the changelog link. |
| Removing the T7 capacity row left live carriers naming it. | record drift | The roadmap evidence and a dispatch draft pointed at a row that no longer exists. | Fixed here: both name M3.6.2. |

## Completed

| File | Change |
|---|---|
| `devlog/roadmap.md` | Added `M3.7` and `M3.7.1`, moved the git-boundary, git-maintenance and completed change-model rows to M3.7 and the draft lifecycle rows to M3.7.1, removed the duplicate capacity-signal row and the empty M3.5.4 section, corrected the record-check backlog and capacity-signal carriers, replaced the T4 packaging row with one combined task, and cut the cross-chart state-machine row into M3.7, M3.3.6 and M3.4.1. |
| `devlog/roadmap_future.md` | Removed the environment-change, STE-clean, Copy-Model Seeding, M2.6.7 and standalone `Harness Packaging and Versioning` sections. |
| `docs/adr/harness_versioning.md` | Named the T4 row as the full-packaging milestone that carries the deferred semantic versioning. |
| `devlog/AGENT_FEEDBACK.md` | Repointed the install-and-staleness entry at the combined T4 task. |
| `.agents/drafts/cost-aware-dispatch-run.md` | Repointed the capacity-signal references from the removed T7 row to M3.6.2. |
| `devlog/handovers/M3.7.1/20261108-01-plan-draft_branch_record.md` | Moved from T7; milestone field changed to M3.7.1. |
| `devlog/handovers/M3.7.1/20261108-02-impl-draft_fork_point.md` | Moved from T7; milestone field changed to M3.7.1. |
| `devlog/handovers/M3.7.1/20261108-03-impl-branch_local_draft_record.md` | Moved from T7; milestone field changed to M3.7.1. |
| `devlog/handovers/M3.7.1/20261108-04-impl-draft_lifecycle_transition_model.md` | Moved from T7; milestone field changed to M3.7.1. |
| `devlog/handovers/M3.7.1/20261109-01-plan-open_m3_7_1_gate_boundary.md` | This handover. |
