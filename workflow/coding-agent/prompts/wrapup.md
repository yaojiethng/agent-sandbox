---
description: "Close an active-operator session: consolidate the close into one shared runbook that /iter, /plan and /document invoke, landing the single delivery commit, writing back the roadmap task, closing ADRs and discussion docs whose work landed, and seeding the next iteration. Also run the commit-discipline checkpoint after each committed task group -- confirm the accumulated commits read as one delivery commit and one open handover, squash any pile of wip checkpoints and typed intermediates, and surface the missing-record signal before it reaches the operator."
argument-hint: "[optional: a commit range to audit]"
---

> $@

# /wrapup - The Consolidated Close

**Scope:** one shared close runbook for the active-operator-participation prompts -- `/iter`, `/plan` and `/document`. It owns the steps common to every such session's end: land the single delivery commit, keep one open handover naming the session, write back the roadmap task, close the ADRs and discussion docs whose work landed, and seed the next iteration. During a session it also owns the commit-discipline checkpoint that runs after each committed task group. It does not run the compaction pass or the milestone-record close; those are milestone-grain and belong to `/milestone-close`. `milestone-start`, `sequential-work` and `parallel-work` do not invoke it: milestone-close owns the milestone-record close, and the work runs substitute an autonomous review for the operator gate.

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

Run the canonical squash procedure in [`iteration_policy.md`](../../../docs/operations/iteration_policy.md) (Canonical procedures -- squash to one delivery commit). The canonical block is the single source; do not restate it here. The close edit and write-back are staged into the same commit, never a separate one.

### A6. Confirm an open handover names the unit

If none is open, create it (naming convention per `handover_policy.md`) or fold the existing one. Mark `Status: Closed` only when the unit genuinely closes.

### A7. Verify the result

```bash
git log --oneline <base>..HEAD   # exactly one commit
git status --short               # clean
bash scripts/lint.sh             # pre-close gate clean
```

## Part B - The close (end of session, shared)

Run this once when the session reaches its end. It follows the unit's release point. There is one release: the operator's forward signal on the release gate (per [`iteration_policy.md`](../../../docs/operations/iteration_policy.md) gate invariants) is the release for this part; Part B does not add a second operator approval. The close steps below run the close invariants in [`iteration_policy.md`](../../../docs/operations/iteration_policy.md); a step states the invariant it satisfies and links it, rather than redefining it.

### B1. AC verification

Read the acceptance criteria from the session's handover. For each criterion, state what was checked, what the result was, and whether it passes. If any criterion fails, stop -- do not close until the gap is resolved or explicitly deferred with a reason.

### B2. Propagation replay

Run the propagation-replay invariant in [`iteration_policy.md`](../../../docs/operations/iteration_policy.md) (Close invariants): when the session applied a naming, structural, or interface change across more than two files, or used "all", "every", "throughout", or "wherever X appears", produce a `file | change planned | status` table with every row accounted for (`completed`, or `deferred`/`not started` with the row written back to the roadmap) before the release gate releases.

### B3. Scope reconciliation

Run the scope-reconciliation invariant in [`iteration_policy.md`](../../../docs/operations/iteration_policy.md) (Close invariants): compare the confirmed scope against the Completed table; every in-scope item not completed is resolved by the deferred-resolution rule; no unaccounted items.

### B4. Roadmap write-back

Apply the roadmap write-back per `roadmap_policy.md`: mark completed tasks `[x]`, note the exact row change per task touched, and the completed rows the change supersedes or invalidates. The write-back rides the delivery commit; it never forms its own commit. The compaction pass, the summary table update, and any top-level milestone close are milestone-grain and belong to [`/milestone-close`](milestone-close.md), not to this runbook.

### B5. Carry-forward resolution

Run the deferred-resolution invariant in [`iteration_policy.md`](../../../docs/operations/iteration_policy.md) (Close invariants): every item in scope but not completed is written back to the roadmap as an open row with its reason, or ruled out of scope with one Scope sentence. The handover carries no carried-forward or deferred-items section.

### B6. Findings review/publish

Run the findings-review/publish invariant in [`iteration_policy.md`](../../../docs/operations/iteration_policy.md) (Close invariants): route each entry to its destination; attribution is operator-owned (the agent proposes a class) and the Findings section is empty or holds only entries with a triage destination before the close.

### B7. Pending-decision resolution

Every row of the handover's `Decisions pending` table closes before the handover closes, per [`handover_policy.md`](../../../docs/operations/handover_policy.md). Each row takes one of three exits: the operator answered it, so the answer moves to the Decisions table with its rationale; the agent found the answer in a record, so the row cites that record; or the block is real and unresolved, so the work is written back as an open roadmap row and the question leaves the handover with it.

A row left open here is a question the operator meets twice, which is the cost this section exists to remove. A table holding only the canonical marker is closed with no work.

### B8. Close ADRs and discussion docs whose work landed

When a `docs/adr/` or `devlog/discussions/` document's work landed this session, close or fold it by running the [`handover-maintenance`](../skills/handover-maintenance.md) skill against it. A document whose recorded work shipped but that stays open after the session is a stale record; close it here.

### B9. Prepare all files for the commit

Mark each AC accepted or pushed. Complete the Completed section and fold every not-in-scope item into a Scope sentence with its reason. Update Hot files. Set `Status: Closed`. Confirm the roadmap write-back from B4 is staged: the write-back is unconditional, one row per handover, so the delivery commit pairs with exactly one write-back -- when the session's task has no pre-existing roadmap row, raise and resolve a subtask row under the owning parent so the pairing holds.

### B10. Land the single commit

Generate the commit message per [`git_policy.md`](../../../docs/operations/git_policy.md): a valid type prefix from the Active Types table, an imperative subject that completes "this commit will", and a body that carries the reason without restating the diff or duplicating the handover. Commit the work, the `Status: Closed` edit, and the roadmap write-back as one commit.

### B11. Post-commit compliance self-check

Re-read the session's commits against the rules before reporting success. Run `git log` over the session's range and check it against [`git_policy.md`](../../../docs/operations/git_policy.md) and [`iteration_policy.md`](../../../docs/operations/iteration_policy.md): (1) the range's squash state holds exactly one delivery-typed commit per unit and its handover -- read the amended history, not pre-amend hashes; (2) every subject's type is in the Active Types table; (3) no subject carries a scope field; (4) no commit's only path is a handover file, unless the unit's deliverable was the record change itself; (5) no close edit or roadmap write-back is separated from its unit's work -- a standalone `plan:` commit is bookkeeping, not this violation; (6) roadmap and milestone bookkeeping is typed `plan:`; (7) one handover bounds the range; (8) the delivery commit matches the handover's scope -- one work unit lands as one commit, no scope item outside the commit and no commit content outside the scope; (9) the range left a roadmap write-back -- one row event per the unconditional write-back invariant, either the session's own task marked with its landing note or a subtask row raised under the owning parent. A unit whose work is not a roadmap task still writes back: the row that records what landed, or a Decision entry in the changelog when no task row applies. A `wip:` commit in the range is not a violation: it is legal and folds at the close. A violation found here is fixed before B12 -- by amending, folding, or retyping -- or recorded as a deliberate deviation with its reason. This check is agent-side; it adds no operator stop beyond the release gate the unit already passed.

### B12. Report the wrapup

State that the wrapup succeeded: the commit, the lint and suite results, the write-back, and any deviation B11 recorded. Then recommend what to pick up next, agent-led: name the candidate from the roadmap's open rows, with one line on why it is next. The recommendation is advisory context for the operator, not a task list; the roadmap stays the sole task list, and a fresh session starts from [`gm.md`](gm.md).

## Failure modes

- **A pile reaches the close unsquashed.** The checkpoint missed a task group, or a `wip:` chain was never folded. Squash into the delivery commit before landing, and record what let it accumulate.
- **The close duplicates the caller's own close steps.** Each invoking prompt must carry its own gates and presentation, and leave the shared close steps to `/wrapup`. A caller that re-states the close is the duplication this document exists to remove.
- **An ADR or discussion doc stays open after its work shipped.** A stale open record misleads the next session. Close it in B8, or name the reason it stays open in the handover's Scope.
- **The write-back lands as its own commit.** The roadmap write-back and the `Status: Closed` edit belong in the delivery commit, never a separate one.

## When to stop and ask

- If the unit boundary is not clear, ask before splitting.
- If a typed intermediate commit already landed on a shared branch and cannot be freely rewritten, ask before rebasing.
- If the operator wants the pile kept for review, stop and record the deliberate deviation instead of squashing.
- If any AC fails or an in-scope item is unaccounted, stop and resolve it before the close.
