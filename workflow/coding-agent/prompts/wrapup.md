---
description: "Close an active-operator session: consolidate the close into one shared runbook that /iter, /plan and /document invoke, landing the single delivery commit, writing back the roadmap task, running compaction, closing ADRs and discussion docs whose work landed, and seeding the next iteration. Also run the commit-discipline checkpoint after each committed task group -- confirm the accumulated commits read as one delivery commit and one open handover, squash any pile of wip checkpoints and typed intermediates, and surface the missing-record signal before it reaches the operator."
argument-hint: "[optional: a commit range to audit]"
---

> $@

# /wrapup - The Consolidated Close

**Scope:** one shared close runbook for the active-operator-participation prompts -- `/iter`, `/plan` and `/document`. It owns the steps common to every such session's end: land the single delivery commit, keep one open handover naming the session, write back the roadmap task, run compaction, close the ADRs and discussion docs whose work landed, and seed the next iteration. During a session it also owns the commit-discipline checkpoint that runs after each committed task group. `milestone-start`, `sequential-work` and `parallel-work` do not invoke it: milestone-close owns the milestone-record close, and the work runs substitute an autonomous review for the operator gate.

## Mandate

You run the consolidated close for an active-operator session that ends at its release point. Two jobs share this document: the **commit-discipline checkpoint** runs during the session after each committed task group; the **close** runs once at the session end. Both deliver a HEAD that reads as one coherent delivery commit per unit, with an open handover naming it, and no pile of typed checkpoints left for the operator to untangle.

Four commit rules govern both jobs. First, one commit per unit: the unit ends as one delivery commit carrying the work, the handover marked `Closed`, and the roadmap write-back; every `wip:` checkpoint and typed intermediate commit folds into it -- `git_policy.md` names the delivery commit the sole reviewable surface. Second, intermediate commits are `wip:` checkpoints, never typed deliveries: a `fix:`/`docs:`/`chore:`/`feat:` prefix mid-unit is reserved for the delivery commit, a typed intermediate reads as a closed deliverable that later folds away, and the status flip and write-back never form their own commit. Third, an open handover bounds the unit: `iteration_policy.md` requires the handover open before output, and a commit with no open handover is a missing record. Fourth, fix the root cause, not the symptom: a detected pile is squashed now and what let it accumulate is recorded -- a recurrence is a feedback or policy gap, catalogued on `devlog/AGENT_FEEDBACK.md` (grep for an existing entry first) or amended in the policy that failed to stop it.

## Called from

Each active-operator prompt invokes the part of this runbook that applies:

- `/iter` and `/document` run the commit-discipline checkpoint during the session and the close at the end.
- `/plan` runs the close at the end of a planning session, whose write-back produces roadmap rows, decisions, and ADRs rather than a delivery commit.
- `milestone-start` does not invoke it -- `/milestone-close` owns the milestone-record close, distinct from the unit close.
- `sequential-work` and `parallel-work` do not invoke it -- their run review substitutes for the operator gate (roadmap row `/auto` bypasses the two operator-acceptance points).

## Input contract

| Input | Meaning |
|---|---|
| commit range | The unit's commits. Defaults to the commits since the last known delivery commit (the last commit with a delivery type that carried its own handover). If no base is identifiable, use the current branch tip range back to the previous merge base. |
| current branch | The branch holding the unit's work, normally `feat/*` or `milestone/*`. |

## Part A - Commit-discipline checkpoint (in-session, recurring)

Run this after each committed task group within the session. It is a hygiene pass, not a release point; it does not stop the session.

### A1. Enumerate the unit's commits

```bash
git log --oneline <base>..HEAD
```

List the commits. Identify each by kind: the delivery commit, `wip:` checkpoints, typed intermediate commits, and the close edit.

### A2. Count the failure signals

- How many commits are in the range, and how many carry a delivery type?
- Is there an open handover? `grep -l "Status: Active" devlog/handovers/*.md`
- Does any commit look like a close-edit-only commit (only the `Status` flip or write-back)?

More than one delivery-typed commit, or any `wip:` not yet folded, or no open handover are each a missing-record signal. Report them all.

### A3. Determine the unit boundary

Read the commit subjects and the roadmap. Decide whether the range is one unit or several. If a single deliverable group (for example "close the register"), it is one unit and folds to one commit. If the range spans distinct deliverables, split at the boundaries into one delivery commit per unit, each with its own handover.

### A4. Confirm with the operator before touching history

Present the boundary and the squash plan. For a multi-unit split, the operator decides the count and the type prefix per delivery commit. Do not rewrite history before the operator releases.

### A5. Squash to one delivery commit

Run the canonical squash procedure in [`iteration_policy.md`](docs/operations/iteration_policy.md) (Canonical procedures -- squash to one delivery commit). The canonical block is the single source; do not restate it here. The close edit and write-back are staged into the same commit, never a separate one.

### A6. Confirm an open handover names the unit

If none is open, create it (naming convention per `handover_policy.md`) or fold the existing one. Mark `Status: Closed` only when the unit genuinely closes.

### A7. Verify the result

```bash
git log --oneline <base>..HEAD   # exactly one commit
git status --short               # clean
bash scripts/lint.sh             # pre-close gate clean
```

## Part B - The close (end of session, shared)

Run this once when the session reaches its end. It follows the unit's release point. There is one release: the operator's forward signal on the release gate (per [`iteration_policy.md`](docs/operations/iteration_policy.md) gate invariants) is the release for this part; Part B does not add a second operator approval. The close steps below run the close invariants in [`iteration_policy.md`](docs/operations/iteration_policy.md); a step states the invariant it satisfies and links it, rather than redefining it.

### B1. AC verification

Read the acceptance criteria from the session's handover. For each criterion, state what was checked, what the result was, and whether it passes. If any criterion fails, stop -- do not close until the gap is resolved or explicitly deferred with a reason.

### B2. Propagation replay

Run the propagation-replay invariant in [`iteration_policy.md`](docs/operations/iteration_policy.md) (Close invariants): when the session applied a naming, structural, or interface change across more than two files, or used "all", "every", "throughout", or "wherever X appears", produce a `file | change planned | status` table with every row accounted for (`completed`, or `deferred`/`not started` with the row in Deferred items) before the release gate releases.

### B3. Scope reconciliation

Run the scope-reconciliation invariant in [`iteration_policy.md`](docs/operations/iteration_policy.md) (Close invariants): compare the confirmed scope against the Completed table; every in-scope item not completed must appear in Deferred items; no unaccounted items.

### B4. Roadmap write-back and compaction

Apply the roadmap write-back per `roadmap_policy.md`: mark completed tasks `[x]`, note the exact row change per task touched, and the completed rows the change supersedes or invalidates. Run roadmap maintenance (compaction cascading, summary table update, top-level milestone close if applicable). The write-back rides the delivery commit; it never forms its own commit.

### B5. Carry-forward resolution

Run the carry-forward-resolution invariant in [`iteration_policy.md`](docs/operations/iteration_policy.md) (Close invariants): every Carried forward item must be completed, re-deferred with reason, or escalated to a named roadmap entry; an item in none of the three is dropped -- find it and triage it.

### B6. Findings review/publish

Run the findings-review/publish invariant in [`iteration_policy.md`](docs/operations/iteration_policy.md) (Close invariants): route each entry to its destination; attribution is operator-owned (the agent proposes a class) and the Findings section is empty or holds only entries with a triage destination before the close.

### B7. Close ADRs and discussion docs whose work landed

When a `docs/adr/` or `devlog/discussions/` document's work landed this session, mark it closed or fold it, per `adr_policy.md` and `discussion_policy.md`. A document whose recorded work shipped but that stays open after the session is a stale record; close it here.

### B8. Close the handover and land the single commit

Mark each AC accepted or pushed. Complete the Completed and Deferred items sections. Update Hot files. Set `Status: Closed`. Land the delivery commit carrying the work, the `Status: Closed` edit, and the roadmap write-back.

### B9. Seed what's next

Populate What's Next per `handover_policy.md`, identifying the next iteration's scope from the roadmap task list and Deferred items (deferred items take priority). Note whether roadmap maintenance is run or pending.

## Failure modes

- **A pile reaches the close unsquashed.** The checkpoint missed a task group, or a `wip:` chain was never folded. Squash into the delivery commit before landing, and record what let it accumulate.
- **The close duplicates the caller's own close steps.** Each invoking prompt must carry its own gates and presentation, and leave the shared close steps to `/wrapup`. A caller that re-states the close is the duplication this document exists to remove.
- **An ADR or discussion doc stays open after its work shipped.** A stale open record misleads the next session. Close it in B7, or name the reason it stays open in Deferred items.
- **The write-back lands as its own commit.** The roadmap write-back and the `Status: Closed` edit belong in the delivery commit, never a separate one.

## When to stop and ask

- If the unit boundary is not clear, ask before splitting.
- If a typed intermediate commit already landed on a shared branch and cannot be freely rewritten, ask before rebasing.
- If the operator wants the pile kept for review, stop and record the deliberate deviation instead of squashing.
- If any AC fails or an in-scope item is unaccounted, stop and resolve it before the close.
