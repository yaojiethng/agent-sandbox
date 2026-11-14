---
date: 2026-11-14
milestone: M3.7.2 - The change model and its refinements
type: Design
status: Closed
---

# Handover - The git-discipline rule set is adjudicated

## Objective

Adjudicate the rule set the evidence pass left unresolved and write each verdict
back to the task list as its own row.

## Scope

Works the row *The convention leads from history as a commons and owns the
primitives*, continuing handover
[`20261114-01`](20261114-01-design-git_history_commons.md). The verdicts are
settled in conversation and written back here; the convention's text does not
change this iteration. In scope: the six verdicts, the five rows under the
parent, and the deferred entry. Out of scope: the convention's text change
(`20261114-03`); the coherence clause and the no-instance boundary wording, which
ride the reframe row's text edits; body 280, settled in the ADR.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The six verdicts are recorded, each with its evidence and its owner. | Read the Decisions table below; six rows. | Agent [x] |
| Each verdict that creates work is its own roadmap row. | `grep -c 'enforced by a check\|substantiated against review cost\|fold, the slice and the stack\|working tree has its rule\|host contract from project style' devlog/roadmap.md` returns 5. | Agent [x] |
| The serialization verdict is a deferred entry, not an active row. | `grep -c 'Trunk serialization when an agent' devlog/roadmap_future.md` returns 1; the same title is absent from `devlog/roadmap.md`. | Agent [x] |
| The rows name the sources that substantiate their claim. | `grep 'commitlint\|Pope\|Graphite\|merge queue' devlog/roadmap.md devlog/roadmap_future.md`. | Agent [x] |
| The reframe row no longer claims the working-tree rule. | `grep -c 'working-tree rule from 2026-08-10' devlog/roadmap.md` returns 0. | Agent [x] |
| The convention's text is unchanged this iteration. | `git diff HEAD -- .agents/skills/git-discipline/SKILL.md` is empty. | Agent [x] |
| Every decision this iteration records is realized in the files. | Read the Decisions table against the diff. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The working tree gets its own row; its placement (the convention or the session hygiene layer) and its mechanism (a guard or a check) are the implementer's. | It is the only evidenced rule addition and it has been homeless since 2026-08-10; naming the rule is this iteration's job, choosing the enforcement is not. | the working-tree row |
| `## The delivery commit and the slice` moves to the iteration protocol; the convention leaves a pointer. | The protocol already owns one-iteration-one-delivery-commit and the split; the convention's slice is that split under a second name. | the fold row |
| `/commit` keeps construction, the protocol owns the count, the convention owns the commit's shape. | Three jobs, three owners; the convention restating the count is the duplication. | the fold row |
| The message shape gets a check, the budgets get a measurement, the stack practice gets one method statement. | Three claims with three mechanisms; a source per claim, so three rows rather than one. | the message-check, budget and fold rows |
| Trunk serialization is deferred-unscheduled; it reopens when an agent manages the trunk. | Merge-back is the operator's manual host act today, so the requirement is nonblocking; the retired runbooks are why the automated form is not attempted now. | the `roadmap_future.md` entry |
| The coherence clause and the no-instance boundary wording are edits inside the reframe's text, not rows. | They have no evidence of their own and no separate mechanism; a row would split a sentence from the section that carries it. | the reframe row |
| A rule links its ADR; an ADR never lists the files it governs. | A governed-file list is a derived index inside an immutable record; the rule-side edge is maintained where the change happens. | this record |
| The convention separates the host contract from project style, with precedence in `instruction-surface-conventions.md`. | A loaded project may carry its own commit convention; only the delivery shape is the host's. | the host-contract row |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The evidence pass adjudicated the subject and body budgets and left five rules unadjudicated: the working tree, the coherence rule, the delivery-commit count, the no-instance boundary rules, and the host/project split. | record | the rule set was half-decided | the five rows and the reframe row |
| The convention's `## The delivery commit and the slice` restates the protocol's invariant and defines a second name for the split. | record | two sources for one rule | the fold row |
| Trunk serialization has no owner; the runbooks that tried it were retired, and merge-back is manual. | record | nonblocking while the operator holds the trunk | the `roadmap_future.md` entry |
| The design conversation changed the iteration's product from a discussion record to the verdict table and its rows. | record | the file table narrows to the task list and this record | this record |

## Completed

| File | One-line change summary |
|---|---|
| `devlog/roadmap.md` | five new rows under the commons parent; the reframe row drops the working-tree clause |
| `devlog/roadmap_future.md` | the serialization requirement as a deferred-unscheduled entry |
| `devlog/handovers/M3.7.2/20261114-02-design-git_discipline_reframe.md` | this record; the verdicts and their destinations |
| (maintenance) | `roadmap-maintenance`: not triggered; no completed sub-milestone reads `In progress`. |
