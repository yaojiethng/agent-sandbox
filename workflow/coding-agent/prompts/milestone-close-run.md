---
description: Close a milestone or sub-milestone: compaction, changelog entry, summary-table and frontmatter write-back, review-gate reconciliation, and the close commit.
argument-hint: "[milestone name - for example M3.1 - Backpressure]"
---

> $@

# Milestone Close - Run (Main-Agent Template)

**Scope:** record that the named milestone's work is complete: compact its task list, write its changelog entry, update the summary table and frontmatter, run the pre-close review gate, and land one close commit. The milestone name always comes from the operator; the same procedure closes a sub-milestone and a full milestone, stopping one level earlier for the sub-milestone.

## Purpose

A milestone closes when its implementation is complete and the operator directs the close. The close is the record of completion, not new work: no substantive change lands after it. The close produces the milestone's durable record -- the compacted roadmap entry, the changelog entry, the reconciled feedback backlog -- in one commit. Close only what the operator names.

## Preconditions

1. **The milestone's roadmap section is all `[x]`.** Read the section and confirm every row is checked. An open row means the milestone is not ready to close; report it and stop.
2. **The operator has directed the close and named the milestone.** Never infer a milestone to close from the branch, the frontmatter, or the last handover.
3. **The operator's direction covers the review gate.** The close surfaces probation entries for a dismiss / maintain / escalate decision; confirm the operator will take those decisions before you execute the close.
4. **Lint and suite are green.** They are preconditions, not acceptance criteria.

## The review gate

Before the roadmap and changelog edits, run the pre-close review gate per [`iteration_policy.md`](docs/operations/iteration_policy.md) Sub-milestone close:

1. Surface every open `[A]`/`[O]` entry and every pending sweep in `devlog/AGENT_FEEDBACK.md`.
2. List every entry under `probation`. Present one row per entry to the operator: `dismiss` (the fix held -- delete the entry), `maintain` (extend probation), or `escalate` (the problem resurfaced -- re-scope).
3. Reconcile per the operator's decisions. An escalated high-blast-radius item defers the close; a low-urgency one lands as a named task under the next milestone.
4. Report the surface and the decisions in the handover's Findings section.

Do not auto-decide a probation entry. The operator owns the dismiss / maintain / escalate decision.

## The compaction

Compact the named milestone's task list in `devlog/roadmap.md` per [`roadmap_policy.md`](docs/operations/roadmap_policy.md) Compaction cascading:

1. Replace the milestone's checklist with one `- [x]` outcome summary of 1-3 sentences: what was built, the capability it delivers. Keep the section's design-document links and its `Not in scope` / deferred tags. Remove task breakdowns, file lists, and implementation notes -- the handovers retain them.
2. **Stop at the close boundary.** A sub-milestone whose siblings are incomplete does not cascade upward: the parent milestone keeps its task list and its `In progress` status. A full milestone whose direct children are all complete cascades to the top-level close instead (below).
3. Keep the section header and its framing paragraph; the status flip lives in the summary table, not the heading.

## The changelog entry

Append the milestone entry to `devlog/changelog.md` in milestone order per [`roadmap_policy.md`](docs/operations/roadmap_policy.md) Changelog Format:

```text
## M{n} - {Title}

*{One sentence: what the system can now do.}*

{Two to four sentences: what was built -- mechanisms, key decisions, concrete outcomes. No file lists. No future language.}

---
```

The italic sentence is the capability. The body states what was built and the decisions that shaped it. No `will` / `plan` / `eventually`.

## The summary table and the frontmatter

In `devlog/roadmap.md`:

1. **Summary table:** flip the milestone's row to `Complete` with a changelog link (`changelog.md#m{n}--{title}`). Leave the parent `In progress` unless all its direct children are complete.
2. **Frontmatter:** set `active-milestone` to the parent milestone when a sub-milestone closes and the parent continues; set it to the next milestone at a full top-level close. Status stays `in-progress`.

## Escalation clearance

Any item the milestone leaves open needs a recorded home before the close:

- A deferred item the next iteration will pick up goes to the handover's Deferred items.
- An item that will not be picked up next goes to the roadmap as a named task per [`roadmap_policy.md`](docs/operations/roadmap_policy.md) Carry-forward escalation -- the operator names the destination milestone (for example the M3.1 close dumped the mutation-run survivors under the M4 mutation entry).
- An item already resident elsewhere (for example a cadence decision in `roadmap_future.md`) is named, not duplicated.

## The close commit

1. Mark every acceptance criterion accepted in the handover. Set the handover `Status: Closed` before the commit -- the close is the commit.
2. Scope reconciliation: every in-scope item appears in Completed, or in Deferred items with a reason. The Deferred items and Carried forward sections carry canonical markers, never blanks (see `handover_policy.md` Canonical Null Markers).
3. Land one delivery commit carrying the roadmap write-back, changelog entry, feedback reconciliation, and the Closed handover. Per [`git_policy.md`](docs/operations/git_policy.md) Active Types, a planning close types `plan`; a sub-milestone close that only compacts and records is `chore`; the type is chosen from the diff. The `plan` type is active: the M2.7 close (`1c11267`) and the M3.1 close (`9c52805`) both typed `plan`.
4. Verify the commit landed and the tree is clean.

## Invariants

- No substantive work lands after the close direction, except the close record itself.
- Every number the close asserts (row counts, survivor counts, suite totals) is computed from the live record, not repeated from memory.
- No probation entry is decided by the agent.
- The roadmap is the sole task list; the close writes its completions there, never into the handover as a new task list.
- A closed milestone's detail lives in the changelog and the handovers; the roadmap shows the compacted summary.
- The milestone name, the close boundary, and the escalation homes come from the operator. The agent proposes; the operator disposes.
