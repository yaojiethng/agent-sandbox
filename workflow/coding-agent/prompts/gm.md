---
description: Check-in. Survey the project state and present the work inventory with options to choose from.
argument-hint: "[intent - optional, e.g. back after a break, easy start]"
---

> $ARGUMENTS

# Check-in - the survey and the work inventory

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `task-list`, `work-log`

## Purpose

A check-in surveys project state and hands the operator an inventory of open work with a starting direction. It is not an iteration; its task list carries work rather than record housekeeping.

## When to use

Run this when the operator wants to know what is open and where to start. Four cases it is not for, and what replaces it:

- **One task, already chosen.** Open the iteration with `/iter`. A check-in named the task in an earlier turn.
- **A record audit on its own.** Run [`roadmap-maintenance`](/opt/workflow/agent/modules/coding-agent/skills/roadmap-maintenance/SKILL.md) or [`handover-maintenance`](/opt/workflow/agent/modules/coding-agent/skills/handover-maintenance/SKILL.md) directly. This prompt runs neither.
- **Which work runs without the operator.** [`/backlog-triage`](/opt/workflow/agent/modules/coding-agent/prompts/backlog-triage.md) answers that narrower question. This prompt reports what is open, not what is dispatchable.
- **A milestone boundary.** `/milestone-start` and `/milestone-close` own those.

## Scope

The check-in's only write is an inert fix: a stale path, a broken link, an index entry, a formatting artefact. It applies those in one commit, typed off the diff per `git-discipline`, and opens no handover. Every other change waits for the operator to pick the next task.

## Arguments

The invocation argument is the intent: any argument filters the inventory.

## Survey

Apply the repository's read discipline: grep to locate, then read the needed sections. Do not open files wholesale beyond what the survey needs.

- Handover chain: read the latest ten handovers. When the operator names a different window - a count ("the last three handovers") or a period ("the last seven days") - read that window instead. Read each record's `status`, findings and deferred items.
- Roadmap: `devlog/roadmap.md`. Read the Milestone Summary table's `In progress` rows, their sections and their open items. Check done items for forward-looking text left behind.
- Recent git history (`git log --oneline -20`): what landed, and the time gap since the last iteration.
- Open entries in `devlog/AGENT_FEEDBACK.md` -- states `open` and `probation`, both `[A]` (agent-raised) and `[O]` (operator-raised) tags.
- Stale-state sweep: `git status`, `git stash list`, `git branch` -- uncommitted changes, stashes, leftover branches.
- Discussion records in `devlog/discussions/` whose roadmap row has closed -- each is a deletion candidate.

Surface every discrepancy as a finding below the inventory table: an open roadmap item whose work already landed on disk; a done item still carrying forward-looking text; a finding marked open whose fix landed; a feedback entry describing files that no longer exist; a test suite whose last recorded run is red or stale.

## Inventory

One row per open work item.

| Item | Type | Size | Progress | Impact | Verification |
|---|---|---|---|---|---|
| `<work item>` -- `<roadmap entry, handover, or feedback entry that names it>` | impl | small | deferred, no pickup date | degrading | offline `make test` |

The axes below are this prompt's to define. `/milestone-start` grades its audited pool on the same axes, and reads them here.

- Item -- the work, plus the record that names it (roadmap entry, handover, feedback entry).
- Type -- impl (build or fix code), design, chore (housekeeping), investigation, doc.
- Size -- how much of one iteration it fills: small, medium, large.
- Progress -- where it sits in the work sequence: closes the active sub-milestone / gates other planned tasks / urgent housekeeping (misleads or blocks others until fixed) / deferred, no pickup date.
- Impact -- the severity axis: how bad the consequence of leaving the work undone. `blocking` -- correctness, security or data loss, or a gate that lets a break through, so the cost of delay is a wrong action taken now. `degrading` -- drift, recurring pain, or cost that grows with delay: the record misleads, the workaround spreads.
- Verification -- how its acceptance is checked: offline `make test` / needs docker / needs operator involvement.

Fill every field from the records already read during the survey. If a field cannot be filled without new investigation, write `unclear` and add the investigation itself as an inventory row. Do not run investigations during a check-in.

A discrepancy is not work: report it below the table rather than as a row.

## Output rules

When no intent was provided, the three closing suggestions draw only from work items. A record defect is never one of them.

## State summary

Two or three lines before the inventory: the active milestone, the time gap since the last iteration and what landed during it, and whether the tree is at a clean stopping point. After a break, name the big changes the operator has not seen.

## Close

If an intent was provided, filter the inventory by it, recommend one starting task from the open rows, and say why it fits. Do not also present the three intents. If the argument already fixes a specific task, say the direction is set and the next step is opening the iteration.

Recommend within the current milestone. A cross-milestone task needs a stated basis: it blocks a task under the current milestone, or it is a recent, urgent problem.

If no intent was provided, do not assume one. Suggest work along the intents actually present in the inventory:

- easiest start -- smallest Size, offline Verification; re-entry after a break.
- highest leverage -- Progress `gates other planned tasks`: the least complex task that unblocks the most downstream work. When a large task needs prefactors, suggest the prefactor, not the large task.
- most urgent -- Impact `blocking`, or `degrading` where the cost grows with delay.

A discrepancy is never one of the three. Present it apart from the table, naming what the record asserts, what the tree shows, and what has to be chosen.

Recommendations respect landing order in every case: a prefactor is suggested before the task that needs it.

Then ask which direction to take. Stop there; no work begins before the operator picks a scope.

## Non-goals

- Does not open, re-scope or close an iteration.
- Does not open a handover.

## Failure modes

- **The intents are graded from memory.** Every field is filled from a record read this run. A field that needs new investigation becomes an inventory row, not a guess.
