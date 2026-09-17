---
description: Check-in. Survey the project state and present the work inventory with options to choose from.
argument-hint: "[context or intent - optional, e.g. back after a break, easy start]"
---

> $@

gm is a check-in, not an iteration. No code or document changes, nor handover
creation, is expected as a result of this survey. Wait for the user to pick a
next task before starting a new iteration proper -- see
[iteration policy](docs/operations/iteration_policy.md).

## Survey

Read these sources. Apply the repo's read discipline: grep to locate, then
read the needed sections. Do not open files wholesale beyond what the survey
needs.

- Handover chain: the latest file in [`devlog/handovers/`](devlog/handovers/)
  -- highest date and index in the filename. Read its status, findings, and
  deferred items.
- Roadmap: [`devlog/roadmap.md`](devlog/roadmap.md). Read the
  `active-milestone` frontmatter field, that milestone's section, and its
  open items. Check done items for forward-looking text left behind.
- Recent git history (`git log --oneline -20`): what landed, and the time
  gap since the last iteration.
- Open entries in [`devlog/AGENT_FEEDBACK.md`](devlog/AGENT_FEEDBACK.md) and
  [`devlog/GOTCHAS.md`](devlog/GOTCHAS.md) -- states `open` and `probation`.
- Stale-state sweep: `git status`, `git stash list`, `git branch` -- look for
  uncommitted changes, stashes, leftover branches.
- Settled design docs in [`devlog/discussions/`](devlog/discussions/) with
  no implementation handover referencing them yet.

Surface discrepancies, do not fix them: an open roadmap item whose work
already landed on disk; a done item still carrying forward-looking text; a
finding marked open whose fix landed; a feedback entry describing files that
no longer exist; a test suite whose last recorded run is red or stale. Each
becomes an inventory row or a finding, never a silent correction.

## State summary

Two or three lines before the inventory: the active milestone, the time gap
since the last iteration and what landed during it, and whether the tree is
at a clean stopping point. After a break, name the big changes the user has
not seen.

## Inventory

One row per open work item. The sample row below is illustrative, not a live item -- the values are examples of each column's shape, sourced from the open items the survey found:

| Item | Type | Size | Progress | Impact | Verification |
|---|---|---|---|---|---|
| <work item> -- <roadmap entry, handover, or feedback entry that names it> | chore | small | deferred, no pickup date | cosmetic | offline `make test` |

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
