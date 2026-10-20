---
description: Close a milestone or sub-milestone. A single general fractal protocol - verify completeness, run the review gate, compact the task list, write the changelog entry, update the records, escalate deferred work, and land the close commit. The same prompt closes a sub-milestone and a full milestone.
argument-hint: "[milestone name - for example M3.1 - Backpressure]"
---

> $@

# Milestone Close - Loop (Main-Agent Template)

**Scope:** record that the named milestone's work is complete. Milestone numbering is fractal, so the same protocol closes a sub-milestone and a top-level milestone; the close boundary tells how far the record cascade goes.

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`. If one is absent or holds the seeded stub, state the failure and hand control to the agent, which decides with the steering it has loaded; the workflow prescribes no fallback.

- `task-list`, `work-log`, `decision-records`

## Orient

Read `devlog/roadmap.md`. Read the `active-milestone` frontmatter field, the named milestone's section, and the Milestone Summary table. Read the most recent handover in `devlog/handovers/`. Read `devlog/AGENT_FEEDBACK.md` open entries.

The milestone name always comes from the operator. Never infer it from the branch, the frontmatter field, or the last handover.

## Verify completeness

Read the named milestone's section in `devlog/roadmap.md`. Confirm every task row is `[x]`; the project's `task-list` convention, The record's shape, owns the invariant that a milestone holding an open row is never `Complete`, and this step applies it. An open row means the milestone is not ready to close: report it and stop.

Confirm the operator will take the review-gate decisions before you execute the close.

## Run the review gate

Surface every open `[A]` (agent) and `[O]` (operator) entry and every pending sweep in `devlog/AGENT_FEEDBACK.md`. Present one row per entry under probation for a decision:

- **dismiss** -- the fix held. Delete the entry.
- **maintain** -- the fix is not stress-tested. Extend probation.
- **escalate** -- the problem resurfaced. Re-scope with awareness of the prior fix.

Reconcile the feedback per the operator's decisions. Do not decide a probation entry yourself; the operator owns the decision. Escalation of far-reaching correctness work defers the close until the work completes. Low-urgency escalation files as a named task at the top of the next milestone.

## Compact the task list

This prompt owns the milestone-grain compaction. Run the [`roadmap-maintenance`](/opt/workflow/agent/modules/coding-agent/skills/roadmap-maintenance/SKILL.md) skill over `devlog/roadmap.md` first and apply its report: it writes nothing, so apply each `fix-now` finding and carry an escalated one into the close. The skill supplies the checks; the project's `task-list` convention supplies the record's form.

Then compact, for each node whose direct children are all complete:

1. **Compact the node** - replace each child's checklist with a `- [x]` outcome summary of 1-3 sentences. Keep the marker, the design document links and the "Not in scope" or deferred tags; drop the task breakdown, the file lists and the implementation notes, which the handover retains. A child that is work in its own right keeps its row beneath the parent; the test is in the project's `task-list` convention, Filing rules. A unit of this workflow's own execution folds into the summary. Flip the node's heading status to `Complete` when one is shown.
2. **Check the node's own parent** - when every sibling of this node is also compacted, compact the parent the same way, to a single `- [x]` entry.
3. **Repeat upward** until the pass reaches a node whose siblings are not all complete, or the top-level milestone.
4. **Continue into the top-level close** when the pass reached the top-level milestone.

The boundary decides which nodes this close touches, not how far the cascade travels next. There is no separate trigger and no event gate.

## Stop at the close boundary

Every number the close asserts must come from the live record rather than memory, and every open row is reported rather than closed. Confirm the boundary with the operator before writing the changelog entry.

## Write the changelog entry

Append the milestone's entry to `devlog/changelog.md` in milestone order. The project's `task-list` convention, The changelog entry, owns the entry's structure and its writing guidance; read them there. Output the entry as a fenced block labelled `changelog` so the operator can append its contents verbatim to `changelog.md` without reading the existing file.

## Update the records

In `devlog/roadmap.md`:

1. **Summary table:** flip the milestone's row to `Complete` with a changelog link. Leave the parent `In progress` unless all its direct children are complete. Done when every row's status and fragment match the section it names.
2. **Frontmatter:** set `active-milestone` to the parent milestone when a sub-milestone closes, or to the next milestone at a full top-level close. Done when it names the milestone this close leaves active.
3. **Top-level close (full milestone only):** write the changelog entry per the step above; remove the completed milestone's detail section from `## Upcoming Milestones`; change its Summary row to `[Complete -- see changelog]` carrying the milestone's changelog anchor; then promote the next incomplete milestone in Summary-table order, moving its section out of `roadmap_future.md` under `## Upcoming Milestones` with its row reading `In progress`, promoting a parent and its sub-milestones as one block. Done when the row's anchor resolves, no detail section for the milestone remains, and the promoted milestone's section has left `roadmap_future.md`.

## Escalate deferred work

Give every item the milestone leaves open a recorded home before the close:

- An item deferred with a destination goes to `roadmap.md` as an open row under the owning milestone, per the deferred-resolution rule in [`iteration_policy.md`](/opt/sandbox/docs/policies/iteration_policy.md).
- An item that will not be picked up next goes to `roadmap.md` as a named task under the `task-list` convention's `**Roadmap task placement**`; the operator names the destination milestone.
- An item already resident elsewhere in `roadmap.md` or `roadmap_future.md` is named, not duplicated.

## Close the milestone

Before the record edits and the close commit, present to the operator the compaction summary, the changelog entry, and the close boundary. Wait for explicit release before applying them. The operator's direction to close is the last input before the close commit.

Then:

1. Mark every acceptance criterion accepted in the handover.
2. Run scope reconciliation and the deferred-resolution gate at milestone grain; see [iteration_policy.md](/opt/sandbox/docs/policies/iteration_policy.md). The items compared are the milestone's Carried forward entries across its iterations -- not one iteration's scope.
3. Set the handover `Status: Closed` before the commit -- the commit is the close.
4. Land one delivery commit per [git_policy.md](/opt/sandbox/docs/policies/git_policy.md). Milestone-close bookkeeping -- compaction, changelog, and promotion -- types `plan`, per the `plan` row of Active Types. The M2.7 and M3.1 closes both typed `plan`.

After the close commit, stop: report the landed commit and the updated records. No substantive work lands after the operator's close direction.

## Invariants

- The roadmap is the sole task list; the project's `task-list` convention owns when it is touched.
- A closed milestone's detail lives in the changelog and the handovers; the roadmap shows the compacted summary.
