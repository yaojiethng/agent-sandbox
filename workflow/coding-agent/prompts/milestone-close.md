---
description: Close a milestone or sub-milestone. A single general fractal protocol - verify completeness, run the review gate, compact the task list, write the changelog entry, update the records, escalate deferred work, and land the close commit. The same prompt closes a sub-milestone and a full milestone.
argument-hint: "[milestone name - for example M3.1 - Backpressure]"
---

> $@

# Milestone Close - Loop (Main-Agent Template)

**Scope:** record that the named milestone's work is complete. Milestone numbering is fractal, so the same protocol closes a sub-milestone and a top-level milestone; the close boundary tells how far the record cascade goes.

## Orient

Read `devlog/roadmap.md`. Read the `active-milestone` frontmatter field, the named milestone's section, and the Milestone Summary table. Read the most recent handover in `devlog/handovers/`. Read `devlog/AGENT_FEEDBACK.md` open entries.

The milestone name always comes from the operator. Never infer it from the branch, the frontmatter field, or the last handover.

## Verify completeness

Read the named milestone's section in `devlog/roadmap.md`. Confirm every task row is `[x]`; [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) `### Record shape` owns the invariant that a milestone holding an open row is never `Complete`, and this step applies it. An open row means the milestone is not ready to close: report it and stop.

Confirm the operator will take the review-gate decisions before you execute the close.

## Run the review gate

Surface every open `[A]` (agent) and `[O]` (operator) entry and every pending sweep in `devlog/AGENT_FEEDBACK.md`. Present one row per entry under probation for a decision:

- **dismiss** -- the fix held. Delete the entry.
- **maintain** -- the fix is not stress-tested. Extend probation.
- **escalate** -- the problem resurfaced. Re-scope with awareness of the prior fix.

Reconcile the feedback per the operator's decisions. Do not decide a probation entry yourself; the operator owns the decision. Escalation of far-reaching correctness work defers the close until the work completes. Low-urgency escalation files as a named task at the top of the next milestone.

## Compact the task list

Run the [`roadmap-maintenance`](../skills/roadmap-maintenance.md) skill over `devlog/roadmap.md`. It owns the compaction pass and the summary table update, and it follows [Compaction cascading](../../../docs/operations/roadmap_policy.md#compaction-cascading) and the [Changelog Format](../../../docs/operations/roadmap_policy.md#changelog-format). This prompt supplies the milestone name; the skill supplies the procedure.

## Stop at the close boundary

Apply [Compaction cascading](../../../docs/operations/roadmap_policy.md#compaction-cascading) to decide how far the close reaches; the policy owns the rule and this prompt does not restate it. The boundary decides which nodes this close touches, not how far the cascade travels next.

## Write the changelog entry

Append the milestone's entry to `devlog/changelog.md` in milestone order. [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) [Changelog Format](../../../docs/operations/roadmap_policy.md#changelog-format) owns the entry's structure and its writing guidance; read them there. Output the entry as a fenced block so the operator can append it verbatim to `changelog.md`.

## Update the records

In `devlog/roadmap.md`:

1. **Summary table:** flip the milestone's row to `Complete` with a changelog link. Leave the parent `In progress` unless all its direct children are complete.
2. **Frontmatter:** set `active-milestone` to the parent milestone when a sub-milestone closes; set it to the next milestone at a full top-level close.
3. **Top-level close (full milestone only):** remove the completed milestone's detail section from `roadmap.md`, and promote the next incomplete milestone from `roadmap_future.md` into `roadmap.md`. Steps 2 and 4 of [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) [Top-level milestone close](../../../docs/operations/roadmap_policy.md#top-level-milestone-close) own them.

## Escalate deferred work

Give every item the milestone leaves open a recorded home before the close:

- An item deferred with a destination goes to `roadmap.md` as an open row under the owning milestone, per the deferred-resolution rule in [`iteration_policy.md`](../../../docs/operations/iteration_policy.md).
- An item that will not be picked up next goes to `roadmap.md` as a named task under [roadmap-policy Roadmap task placement](../../../docs/operations/roadmap_policy.md#filing-rules); the operator names the destination milestone.
- An item already resident elsewhere in `roadmap.md` or `roadmap_future.md` is named, not duplicated.

## Close the milestone

Before the record edits and the close commit, present to the operator the compaction summary, the changelog entry, and the close boundary. Wait for explicit release before applying them. The operator's direction to close is the last input before the close commit.

Then:

1. Mark every acceptance criterion accepted in the handover.
2. Run scope reconciliation and the deferred-resolution gate at milestone grain; see [iteration_policy.md](../../../docs/operations/iteration_policy.md). The items compared are the milestone's Carried forward entries across its iterations -- not one iteration's scope.
3. Set the handover `Status: Closed` before the commit -- the commit is the close.
4. Land one delivery commit per [git_policy.md](../../../docs/operations/git_policy.md). Milestone-close bookkeeping -- compaction, changelog, and promotion -- types `plan`, per the `plan` row of Active Types. The M2.7 and M3.1 closes both typed `plan`.

After the close commit, stop: report the landed commit and the updated records. No substantive work lands after the operator's close direction.

## Invariants

- Every number the close asserts is computed from the live record, not repeated from memory.
- No probation entry is decided by the agent.
- The roadmap is the sole task list.
- A closed milestone's detail lives in the changelog and the handovers; the roadmap shows the compacted summary.
- The milestone name, the close boundary, and the escalation homes come from the operator. The agent proposes; the operator disposes.
