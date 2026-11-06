---
date: 2026-11-05
milestone: M3.5.4 - The git and change model
type: Design
status: Closed
---

# Handover - The change flow is written down and M3.5.4 is filed

## Objective

Write down the change-flow statechart, state the early-change-and-rebase workflow, list the critical workflow bugs it exposes, and file M3.5.4 as the home for resolving them.

## Scope

The design record `devlog/discussions/20261105-design-open-change_flow.md`, its checked TLA+ model and generated chart, the six bug findings with their carriers, and the M3.5.4 section with the five carrier edits in `devlog/roadmap.md`. The fixes themselves are open rows in M3.5.4, not this unit.

Out of scope, with reasons: the bug fixes, which the M3.5.4 rows hold; the prose unification, which follows the model; the task-list and work-log rows, which M3.5.2 and M3.5.3 own; the statechart tool, which M3.3.6 owns.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The record is named and stated | `bash scripts/check_record_names.sh` | Agent [x] |
| The record is owned by an open row | `bash scripts/check_record_lifecycle.sh` | Agent [x] |
| The model checks | TLC reaches 90 states and 170 steps; `CleanAtHead` and `TrunkNeverResolves` break only on the two forbidden paths | Agent [x] |
| The chart is written down | the record carries the generated Mermaid chart | Agent [x] |
| The six bugs are named with their carriers | the record's `## Critical workflow bugs` table | Agent [x] |
| The early-change workflow is stated | the record's step list; the `merge` input change is filed | Agent [x] |
| M3.5.4 and its carriers are in the roadmap | the new section, the TOC row, both order paragraphs, and M3.5.3's `Depends on` and `Sequencing` | Agent [x] |
| The gates are clean | `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The branch owns its merge-back; the trunk only accepts | the trunk is a role, not a workspace; an author refuses to resolve on the branch's behalf | the design record, `## Decision` |
| There is no second lane; the merge unit's grain is a judgement | a small fix and a milestone delivery obey the same rules; only the unit's size and order change | the design record, `## Decision` |
| The defect flow is the `blocked` state, not a second model | a branch that needs a semantic shared change is blocked until that change lands as a unit | the design record, `## Decision` |
| M3.5.4 opens before M3.5.3 | the change model is the other half of the parallelization blocker, and its file set is disjoint | `devlog/roadmap.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The normal integration path is documented only as recovery (`merge` and `rebase` sit under "lost work") | defect | an agent treats a live merge as a rescue and cannot find the normal early-slice path | M3.5.4, "`merge` and `rebase` leave recovery" |
| `/merge` accepts only a draft export, so a single commit on a feature branch cannot be merged early | defect | the operator must export the whole branch or hand-edit | M3.5.4, "The early-change-and-rebase workflow" |
| The branch model says `main` is the only long-lived branch | defect | the topology in use, a long-lived track that is the merge target, has no stated lifetime or replay obligation | M3.5.4, "The branch model names the long-lived track" |
| No rule obliges a live branch to rebase when the trunk moves | defect | `CleanAtHead` is unenforced; a branch can offer a stale tree | M3.5.4, "Live branches rebase when the trunk moves" |
| The early slice's commit and handover shape is undefined | defect | a `wip:` can land on the trunk, or the slice is a partial unit with no handover | M3.5.4, "A slice is a unit, not a fragment" |
| `/rebase` assumes every commit carries a handover | defect | the supplier's post-slice delivery has a commit with no handover to read | M3.5.4, "The exposed workflow bugs are resolved" |

## Completed

| File | Change |
|---|---|
| `devlog/discussions/20261105-design-open-change_flow.md` | the model, chart, early-change workflow, six bugs, and the checked evidence |
| `devlog/roadmap.md` | the M3.5.4 section, the TOC row, both order paragraphs, and M3.5.3's dependency |
| `devlog/handovers/M3.5.4/20261105-19-design-change_flow_model.md` | this record |
