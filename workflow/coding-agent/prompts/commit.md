---
description: "Land one delivery commit for a unit: the in-session commit-discipline checkpoint that keeps the commit range readable, and the close's commit steps that prepare the handover, land the single commit and verify the result. Use after each committed task group and at a unit's close."
argument-hint: "[optional: a commit range to audit]"
---

> $ARGUMENTS

# /commit - The Delivery Commit

**Scope:** the one operation that turns a unit's work into a delivery commit. It owns the in-session commit-discipline checkpoint, and at the close it owns the preparation, the landing and the post-commit verification. It does not run the close: acceptance-criteria verification, propagation replay, scope reconciliation, roadmap write-back, carry-forward resolution, findings publication, closing ADRs and discussion docs, and pending-decision resolution belong to [`/wrapup`](wrapup.md). It does not run the compaction pass or the milestone-record close; those are milestone-grain and belong to `/milestone-close`.

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `task-list`, `work-log`, `git-discipline`

## Mandate

A unit ends as one delivery commit carrying the work, the handover marked `Closed`, and the roadmap write-back. Four rules govern both jobs in this runbook.

First, one commit per unit: every `wip:` checkpoint and typed intermediate commit folds into it -- the `git-discipline` convention names the delivery commit the sole reviewable surface. Second, intermediate commits are `wip:` checkpoints, never typed deliveries: a `fix:`/`docs:`/`chore:`/`feat:` prefix mid-unit is reserved for the delivery commit, and the status flip and write-back never form their own commit. Third, an open handover bounds the unit: `iteration_protocol.md` requires the handover open before output, and a commit with no open handover is a missing record. Fourth, fix the root cause: squash the pile now and record what let it accumulate, as an entry on `devlog/AGENT_FEEDBACK.md` (grep first) or an amendment to the rule that failed to stop it.

## Called from

- `/iter`, `/document` and `/plan` run the checkpoint during the session and land the commit at the end, handed here by `/wrapup`'s close.
- `/sidequest` lands its single delivery commit here.
- `/merge` folds a replay's current-state corrections here.
- `/milestone-close` does not invoke it: the milestone-record close lands its own bookkeeping commit.

## Input contract

| Input | Meaning |
|---|---|
| commit range | The unit's commits. Defaults to the commits since the last known delivery commit (the last commit with a delivery type that carried its own handover). If no base is identifiable, use the current branch tip range back to the previous merge base. |
| current branch | The branch holding the unit's work, normally `feat/*` or `milestone/*`. |

## Part A - The checkpoint (in-session, recurring)

Run this after each committed task group within the session. It is a hygiene pass, not a release point; it does not stop the session.

Commit the unit's work before its boundary, even when incomplete: a `wip:` checkpoint folds at the close, and a stash is not a record. `wip:` is a prefix and not a type, so it never reads as a delivered unit.

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

Run the canonical squash. Given a commit range `base..HEAD`, land one delivery commit:

```bash
git reset --soft <base>          # keep the work staged
git add -A
git commit -m "<type>: ..."      # one typed commit
```

A clean committed range uses the same fold. The close edit and write-back are staged into the same commit, never a separate one.

Three kinds of transient commit fold into it: `wip:` checkpoints, a correction commit, and the close edit with its roadmap write-back.

When the work commit has already landed and the close edit is still outstanding, fold the edit into that commit rather than adding one. The end state is one commit per iteration.

### A6. Confirm an open handover names the unit

If none is open, create it (naming per the project's `work-log` convention) or fold the existing one. Mark `Status: Closed` only when the unit genuinely closes.

### A7. Verify the result

```bash
git log --oneline <base>..HEAD   # exactly one commit
git status --short               # clean
bash scripts/lint.sh             # pre-close gate clean
```

## Part C - The commit (at the unit's close)

Run once, after `/wrapup` has run the close steps and handed the commit here.

### C1. Prepare all files for the commit

Mark each AC accepted or pushed. Complete the Completed section and fold every not-in-scope item into a Scope sentence with its reason. Set `Status: Closed`. The handover format gate checks the record's shape at the commit. Confirm the roadmap write-back from `/wrapup` is staged, or that its recorded outcome is None. When the iteration completed or rescoped a roadmap task, that row edit rides this commit; an iteration that changed no task writes back nothing.

A working tree holding changes from more than one iteration is split before the commit: save the diff, reset the file, and apply only the hunks that belong to each commit. Where the changes interleave inside one section, split the file or restructure so each iteration's work is disjoint.

### C2. Land the single commit

Generate the commit message per the `git-discipline` convention, `.agents/skills/git-discipline/SKILL.md`: a valid type prefix from the active types table, an imperative subject that completes "this commit will", and a body that carries the reason without restating the diff or duplicating the handover. Commit the work, the `Status: Closed` edit, and the roadmap write-back as one commit.

### C3. Post-commit compliance self-check

Re-read the session's commits against the rules before reporting success. Run `git log` over the session's range and check it against the `git-discipline` convention, `.agents/skills/git-discipline/SKILL.md`, and [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md): (1) the range's squash state holds exactly one delivery-typed commit per unit and its handover -- read the amended history, not pre-amend hashes; (2) every subject's type is in the Active Types table; (3) no subject carries a scope field; (4) no commit's only path is a handover file, unless the unit's deliverable was the record change itself; (5) no close edit or roadmap write-back is separated from its unit's work -- a standalone `plan:` commit is bookkeeping, not this violation; (6) roadmap and milestone bookkeeping is typed `plan:`; (7) one handover bounds the range; (8) the delivery commit matches the handover's scope -- one work unit lands as one commit, no scope item outside the commit and no commit content outside the scope; (9) the range left a roadmap write-back -- one row event per the unconditional write-back invariant, either the session's own task marked with its landing note or a subtask row raised under the owning parent. A unit whose work is not a roadmap task still writes back: the row that records what landed, or a Decision entry in the changelog when no task row applies. A `wip:` commit in the range is not a violation: it is legal and folds at the close. A violation found here is fixed before the commit is reported -- by amending, folding, or retyping -- or recorded as a deliberate deviation with its reason. This check is agent-side; it adds no operator stop beyond the release gate the unit already passed.

## Failure modes

- **A pile reaches the close unsquashed.** The checkpoint missed a task group, or a `wip:` chain was never folded. Squash into the delivery commit before landing, and record what let it accumulate.
- **The commit lands as more than one.** The status flip, the write-back or a correction has been split off. Fold each into the delivery commit; the end state is one commit per unit.
- **The write-back lands as its own commit.** The roadmap write-back and the `Status: Closed` edit belong in the delivery commit, never a separate one.
- **A commit with no open handover.** The unit has no record, so the commit is unreadable to the next session. Open the handover before the commit, or fold the existing one.

## When to stop and ask

- If the unit boundary is not clear, ask before splitting.
- If a typed intermediate commit already landed on a shared branch and cannot be freely rewritten, ask before rebasing.
- If the operator wants the pile kept for review, stop and record the deliberate deviation instead of squashing.
- If the close left an AC failing or an in-scope item unaccounted, stop and return it to `/wrapup`.
