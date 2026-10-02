# Handover - The roadmap consolidation plan

**Date:** 2026-10-02
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Plan
**Status:** Closed

Plan. No consolidation is executed in this iteration.

## Objective

Turn the roadmap's four dense sections into a task list a reader can hold, by consolidating related rows, summarising landed narrative, and re-filing rows that sit in the wrong section.

## Scope

`devlog/roadmap.md` sections T1, M3.2.1, M3.2.2 and M3.2.3. Read only; no other file is in scope except this handover and the learnings write-back to `workflow/coding-agent/skills/roadmap-maintenance.md`.

## What is wrong, measured

**Rows carry the implementation narrative that belongs in the handover.** A closed row in M3.2.1 runs to a paragraph of landed detail: the two mutation-gate subtasks, the BDD-lite report and the adversarial template each restate what their handover recorded, including counts that will drift. The `task-queue` primitive row, the pool-join row and the interface-improvements row are each longer than the task they describe. A reader deciding what to work on reads three handovers to find out that a row is closed.

**Nine taskq rows span three outcomes.** M3.2.1 carries seven taskq rows. Three are closed work on the primitive (the primitive itself, the interface improvements, the pool join), two are closed work on its review and visibility (review-hardening, the documentation gap), and two are open prompt-quality rows. They are one subject with one owner and they read as nine unrelated items.

**The per-prompt quality pass is filed four times.** `/task-queue`, `/plan`, `/milestone-start` with `/milestone-close`, and `/document` each carry their own row. Same work, same bar, same reviewer, four rows. Three sit in M3.2.1 and one in T1, so the fourth reads as a stray.

**Five rows sit in a section that does not own them.** T1 is Workflow + Policy Organization. It currently also holds the `/document` convergence row, the `documentation-pass.md` distillation row, the `/document` quality pass, the `/task-queue` dispatch row, and a three-defect row mixing a prompt label fix with a lint-gate cause with a duplicated rule.

**One row holds three unrelated defects.** The extraction row bundles a wrong step label in `wrapup.md`, the doc-wrap registration cause, and a rule stated twice in `gm.md`. Its own text says one matters and two do not, which is a sign the row is a bucket rather than a task.

**One row restates a known entry without adding to it.** The doc-wrap half of that row is the `AGENT_FEEDBACK` `[A]` 2026-09-21 entry with its 2026-10-01 recurrence, re-confirmed. What is new is the config cause. That belongs as a recurrence note on the feedback entry, not as a roadmap row.

**Counts in closed rows are a drift source.** Node 264/264, harness 1004/1004, 101/101, 247/247, 22/22, 157 assertions and a live pi version are all recorded in closed rows. Every one is a number that is true once.

## The work table

Each unit is independently reviewable and lands as one commit with this handover amended rather than a new one.

| Unit | Change | Files | Depends on |
|---|---|---|---|
| U1 | Summarise every closed row in T1, M3.2.1, M3.2.2 and M3.2.3 to one or two lines plus a handover link. Delete landed narrative and inline counts from the roadmap body. | `devlog/roadmap.md` | none |
| U2 | Merge the seven taskq rows in M3.2.1 into one parent with the closed ones as subtasks, preserving each subtask's handover link. | `devlog/roadmap.md` | U1 |
| U3 | Merge the four per-prompt quality pass rows into one parent with the four prompts as subtasks. | `devlog/roadmap.md` | U1 |
| U4 | Split the three-defect extraction row. File the `wrapup.md` label fix and the `gm.md` duplicate rule as two rows under M3.2.1 next to the prompts they name. Move the doc-wrap cause onto the `AGENT_FEEDBACK` entry as a recurrence and delete the roadmap row. | `devlog/roadmap.md`, `devlog/AGENT_FEEDBACK.md` | U1 |
| U5 | Re-file the five mis-placed rows: `/document` convergence, `documentation-pass.md` distillation and `/document` quality pass to M3.2.2, which owns the audit and review family; `/task-queue` dispatch procedure to M3.2.3, which its own row names as the fold point; the stale `roadmap_future.md` pin note into the existing pi-bump U2, which already claims it. | `devlog/roadmap.md` | U1, U3 |
| U6 | Refresh the Milestone Summary table and the T1 heading blurb against the consolidated rows. | `devlog/roadmap.md` | U2 through U5 |

## Decisions taken in the plan

- A closed row keeps one line of what landed and one handover link. The narrative lives in the handover, which is where it already is.
- A parent task holds subtasks; the parent carries the owner and the shared bar. A taskq parent does not restate each subtask's scope.
- Rows move to the milestone whose text already claims the work. No new milestone scope is created.
- The roadmap records state, not history. A recurrence on a feedback entry is recorded on the feedback entry.

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | Every closed row in the four sections is one or two lines plus a handover link | read T1, M3.2.1, M3.2.2, M3.2.3 | pass |
| 2 | One taskq parent carries its closed subtasks | read M3.2.1 | pass |
| 3 | One quality-pass parent carries four prompt subtasks | read M3.2.1, T1 | pass |
| 4 | No open row names a milestone whose text does not claim it | read each open row against its section blurb | pass |
| 5 | No count appears in a closed row | grep the four sections for a digit count | pass |
| 6 | The Milestone Summary matches the consolidated rows | read the table against the rows | pass |

## Findings that improve `roadmap-maintenance.md`

Written back to the skill, which this plan exercised for the first time on a live document.

**A row that cannot be closed without a decision is not one task.** The three-defect extraction row carried its own priority order in its own text. That is the tell. Split it before working it.

**A row that restates a known entry adds nothing unless it names the delta.** The doc-wrap row re-confirmed a known defect and the new fact was the config cause. The rule is: if a row's first half is already recorded elsewhere, the row's job is the delta only, and the delta belongs on the original entry.

**A milestone's section blurb is the filing test.** Two of the five mis-placed rows name a milestone that already claims them elsewhere. If the blurb claims it, the row is mis-filed; if no blurb claims it, the milestone scope is wrong. One of those two is a scope decision and the other is a move.

**Landed narrative is the main source of roadmap bloat.** Every closed row in these sections is longer than the task it records. The rule the skill should carry: a closed row is one line of what landed plus a handover link, and inline counts are never restated because they are true exactly once.

**A number in a record is a liability once the record closes.** Node counts, suite counts and version literals in closed rows are stale the moment the next change lands.

## Deferred

- M3.2.2 has no task rows of its own, only a section blurb. The five rows U5 moves into it are what gives that milestone a task list. Whether the section blurb is split into tasks is a separate call.
- The Milestone Summary table lists M3.2.2 as Not started. U6 refreshes it against the rows, which will change that status. Whether M3.2.2's own text implies otherwise is a milestone-state question for the operator.
