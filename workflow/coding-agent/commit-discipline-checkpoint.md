---
description: Checkpoint the iteration's commit discipline after each committed task group: confirm the accumulated commits read as one delivery commit and one open handover, squash any pile of wip checkpoints and typed intermediates, and surface the missing-record signal before it reaches the operator.
argument-hint: "[optional: a commit range to audit]"
---

> $@

## Mandate

You are checking the commit discipline of the current iteration after a task group has been committed. Your deliverable is a HEAD that reads as one coherent delivery commit per iteration, with an open handover naming that iteration, and no pile of typed checkpoints left for the operator to untangle.

This run exists because a session shipped an iteration as a pile: 13 commits (8 typed `fix:`/`docs:`/`chore:` and 4 `wip:`) across one logical iteration with no open handover, then needed a retrospective squash when the operator asked for one. The failure had two parts: the typed intermediate commits read as deliveries that never closed, and the `wip:` checkpoints were never folded. Both are missing-record signals, not progress.

Four rules govern this run.

First, one commit per iteration. The iteration ends as one delivery commit carrying the work, the handover marked `Closed`, and the roadmap write-back. Every `wip:` checkpoint and every typed intermediate commit folds into it. `git_policy.md` closes this: "the delivery commit is the sole reviewable surface."

Second, intermediate commits are `wip:` checkpoints, never typed deliveries. A `fix:` or `docs:` prefix is reserved for the delivery commit at iteration end. A typed commit mid-iteration that is not the close is a false delivery surface and a review defect. For the same reason, the status flip and roadmap write-back never form their own commit; they belong in the delivery commit.

Third, an open handover bounds the iteration. `iteration_policy.md` Step 1 opens the handover before output; a commit landed with no open handover is a missing record. When you find commits with no handover, the fix is not only to squash -- open (or reopen) the handover that names the work.

Fourth, fix the root cause, not the symptom. If the check detects a pile, squash it now and record what let it accumulate. A recurrence is a feedback or policy gap: catalogue it on `devlog/AGENT_FEEDBACK.md` (grep for an existing entry on the same topic first) or amend the policy that failed to stop it.

## Input contract

| Input | Meaning |
|---|---|
| commit range | Optional. Defaults to the commits since the last known delivery commit (the last commit with a delivery type that carried its own handover). If you cannot identify a base, use the current branch tip range back to the previous merge base. |
| current branch | The branch holding the iteration's work, normally `feat/*` or `milestone/*`. |

## Procedure

Run each step in order. Stop only when the operator directs otherwise.

### 1. Enumerate the iteration's commits

```bash
git log --oneline <base>..HEAD
```

List the commits. Identify each by kind: the delivery commit, `wip:` checkpoints, typed intermediate commits (`fix:`/`docs:`/`chore:`/`feat:`), and the close edit.

### 2. Count the failure signals

- How many commits are in the range, and how many carry a delivery type?
- Is there an open handover? `grep -l "Status: Active" devlog/handovers/*.md`
- Does any commit look like a close-edit-only commit (only the `Status` flip or write-back)?

More than one delivery-typed commit, or any `wip:` not yet folded, and no open handover are each a missing-record signal. Report them all.

### 3. Determine the iteration boundary

Read the commit subjects and the roadmap. Decide whether the range is one iteration or several. If a single deliverable group (for example "close the register"), it is one iteration and folds to one commit. If the range spans distinct milestones or sub-milestones, split at the boundaries into one delivery commit per iteration, each with its own handover.

### 4. Confirm scope with the operator before touching history

Present the boundary and the squash plan. For a multi-iteration split, the operator decides the number and the type prefix per delivery commit. Do not rewrite history before the operator releases.

### 5. Squash to one delivery commit

```bash
git reset --soft <base>          # keep the work staged
git add -A
git commit -m "<type>: ..."      # one typed commit
```

Or, when the work is already committed and clean, use an interactive rebase squash (`git rebase -i` folding the range into the base delivery commit). The close edit and write-back are staged into the same commit, never a separate one.

### 6. Confirm an open handover names the iteration

If none is open, create it (naming convention per `handover_policy.md`) or fold the existing one. Mark `Status: Closed` only when the iteration genuinely closes.

### 7. Verify the result

```bash
git log --oneline <base>..HEAD   # exactly one commit
git status --short               # clean
bash scripts/lint.sh             # pre-close gate clean
```

## Output contract

| Output | What it must be |
|---|---|
| Squashed commit | One delivery commit per iteration, delivery-typed, carrying the work + close edit + write-back |
| Handover | Open (or reopened) at the start of the writer's next iteration; `Status: Closed` on this one |
| Diff | Identical tree before and after the squash; the squash never drops or changes content |

## When to stop and ask

- If the range spans more than one iteration and the boundary is not clear, ask before splitting.
- If a typed intermediate commit already landed on a shared branch and cannot be freely rewritten, ask before rebasing.
- If the operator wants the pile kept for review, stop and record the deliberate deviation instead of squashing.
