---
description: Check-in. Survey the project state and present the work inventory with options to choose from.
argument-hint: "[context or intent - optional, e.g. back after a break, easy start]"
---

> $@

gm is a check-in, not an iteration. The agent's only permitted change during a check-in is a cosmetic record-bug fix: a stale record state, a mis-dated record entry, or forward-looking text in a completed item. Apply all such fixes found, aggregate them into a single `chore:` commit, and do not open a handover. All other changes wait; the user picks the next task before a new iteration starts -- see
[iteration policy](../../../docs/operations/iteration_policy.md).

## Survey

The survey reads state; it does not repair it. Apply the repo's read discipline: grep to locate, then read the needed sections. Do not open files wholesale beyond what the survey needs.

Delegate the record maintenance. Run [`roadmap-maintenance.md`](../skills/roadmap-maintenance.md) over [`devlog/roadmap.md`](../../../devlog/roadmap.md) and [`handover-maintenance.md`](../skills/handover-maintenance.md) over the handover chain. Between them the two skills own the record checks, the corrections each may apply, and the defects each reports. Every finding they return becomes an inventory row or a finding, never a silent correction.

Cosmetic record-bug fixes (the class named above) are applied immediately and aggregated into a single `chore:` commit; every other discrepancy is surfaced as a row and waits.

## State summary

Two or three lines before the inventory: the active milestone, the time gap
since the last iteration and what landed during it, and whether the tree is
at a clean stopping point. After a break, name the big changes the user has
not seen.

## Inventory

One row per open work item. The sample row below is illustrative, not a live item -- the values are examples of each column's shape, sourced from the open items the survey found:

| Item | Type | Size | Progress | Impact | Verification |
|---|---|---|---|---|---|
| `<work item>` -- `<roadmap entry, handover, or feedback entry that names it>` | chore | small | deferred, no pickup date | cosmetic | offline `make test` |

Field meanings:

- Item -- the work, plus the record that names it (roadmap entry, handover, feedback entry).
- Type -- impl (build or fix code), design, chore (housekeeping), investigation, doc.
- Size -- how much of one iteration it fills: small, medium, large.
- Progress -- where it sits in the work sequence: closes the active sub-milestone / gates other planned tasks / urgent housekeeping (misleads or blocks others until fixed) / write-back (record text is stale vs the tree) / deferred, no pickup date.
- Impact -- why it matters beyond sequence: core goal of the active sub-milestone / recurring pain point / risk-bearing (security or correctness) / cosmetic.
- Verification -- how its acceptance is checked: offline `make test` / needs docker / needs operator involvement.

Fill every field from the records already read during the survey. If a field
cannot be filled without new investigation, write `unclear` and add the
investigation itself as an inventory row. Do not run investigations during
this check-in.

## Close

If an intent was provided as the argument: filter the inventory by it,
recommend one starting task, and say why it fits. If the argument already
fixes a specific task, say the direction is set and the next step is opening
the iteration.

If no intent was provided, do not assume one. Suggest work along the intents
actually present in the inventory, commonly:

- easiest start -- smallest size, offline verification; re-entry after a break.
- highest leverage -- the least complex task that unblocks the most downstream
  work. When a large task needs prefactors, suggest the prefactor, not the
  large task: tasks land in sequence, and the prefactor comes first.
- most urgent -- cost grows with delay; risk-bearing or accumulating drift.

Recommendations respect landing order in every case: a prefactor is suggested
before the task that needs it.

Then ask which direction to take. Stop there; no work begins before the user
picks a scope.

If the picked direction is an unattended run rather than a supervised
iteration, run [`backlog-triage.md`](backlog-triage.md) on the inventory
before opening the run. The survey answers "what is open"; triage answers
"which of it runs without the user", and the two questions have different
answers once the inventory holds more than a few rows.
