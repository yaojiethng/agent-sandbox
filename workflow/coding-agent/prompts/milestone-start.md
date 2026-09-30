---
description: Open or reshape a major milestone or sub-milestone. Factors the roadmap's loose task pool into a named milestone shape - audits the pool, proposes milestones (possibly several), titles them with the operator, assigns and re-files tasks, promotes one as next active, and updates the records. Handles a finish at any nesting level, since milestone numbering is fractal.
argument-hint: "[direction or intent - optional]"
---

> $@

# Milestone Start - Milestone Open

**Scope:** turn the roadmap's remaining task pool into a named, scoped milestone at the current nesting level. Milestone numbering is fractal: the same protocol opens a sub-milestone within a milestone, or a milestone at the top level.

## Orient

Read `devlog/roadmap.md`. Read the `active-milestone` frontmatter field, its milestone section, its open items, and the Milestone Summary table. Read the most recent handover in `devlog/handovers/`. Read `devlog/AGENT_FEEDBACK.md` open entries.

Determine the finish state: a caller can finish at any nesting level. A finish that cannot factor under the current level indicates the next milestone steps up one nesting level. Confirm with the operator that a milestone should be opened or reshaped.

## Audit the task pool

The task pool is the remaining open tasks in the roadmap at and below the current lineage. Read the current milestone's open tasks and its child sub-milestones; do not cross into unrelated milestones.

Group the tasks in the pool into task categories, and grade the categories by the following decision axes:

- **Size** -- small, medium, large.
- **Progress** -- closes the active sub-milestone / gates others / urgent housekeeping / write-back / deferred, no pickup date.
- **Impact** -- core goal / recurring pain / risk-bearing / cosmetic.

Present the task categories and their grades to the operator in a table.

## Propose the milestone -- single decision

Present one reorganization proposal to the operator. The proposal covers the whole milestone shape at once:

- which new milestones to create from the audited task categories, naming the work each one holds;
- which existing milestones are stale and should be superseded;
- which existing milestones are overfull and should split;
- the nesting level each milestone sits at.

Milestone numbering is fractal and nests to any depth -- M{n}, M{n}.{m}, M{n}.{m}.{o}. Numbering uses integers only; follow the Fractal Milestone Numbering section of [roadmap_policy.md](docs/operations/roadmap_policy.md) for the numbering rules and the Milestone Summary table's indentation.

You may propose nested sub-milestones where the pool decomposes cleanly. If the pool cannot factor at the current level, propose the shape one nesting level up. If the shape has genuine variants, rank them (1-3) -- the operator still decides once, on one point.

A milestone is a bin; a new milestone is an empty bin. Wait for one operator decision that fixes the milestone set and their titles before any organization. A good title shapes a clean scope.

## Organize the milestones

After the operator fixes the milestone set, allocate tasks:

- Create, split, and supersede bins exactly as the operator's decision fixed them.
- For each new empty bin, fill it with the pool's tasks that fall under its scope.
- Move badly-filed tasks to the bin that owns them.
- Re-sequence or re-title only at the operator's command.

When a task is ambiguous about its bin, ask the operator. When the operator proposes a task list, review it for gaps and out-of-scope items and say so.

## Promote and record

When several milestones exist, select one as next active with the operator. Update every record the selection touches:

- `roadmap.md` Milestone Summary table row -- set the active milestone to `In progress`.
- The milestone's section -- add the full task checklist to the active one; non-active milestones carry an objective paragraph only.
- `roadmap.md` frontmatter `active-milestone` -- set it to the active major milestone.

Follow the Record shape section of [roadmap_policy.md](docs/operations/roadmap_policy.md) when writing the summary row and the checklist/objective split. Confirm with the operator that the milestone is open before stopping.
