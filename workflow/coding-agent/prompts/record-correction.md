---
description: Fold a correction into a closed commit that is not HEAD, without rewriting anything else. The target commit is rewritten in place and the correction lands inside it, with its own handover where the record requires one.
argument-hint: "[target commit hash or subject] [what the correction changes] [why it belongs to that commit]"
---

> $@

## Mandate

You are correcting a record that has already been closed. The operator named the commit the correction belongs to. Your deliverable is that commit rewritten to carry the correction, with no other commit touched, no commit added, and no port artifact left behind.

A correction is not a new commit. A closed iteration's commit keeps its identity, its message, and its place in history, and the fix folds into it. This is the record correction described in [`closed_record_corrections.md`](../../../docs/adr/closed_record_corrections.md), and that document owns the policy. This prompt owns the mechanics.

Two rules govern the run.

First, verify the fold, never assume it. `git rebase --autosquash` reports success when it has matched nothing at all, and it matches on the target's subject line, not on the hash you named. Every failure this runbook exists to prevent came from a rebase that exited zero over a fixup still sitting at the top of the branch. Read the change out of the target commit by hand before you report.

Second, a correction that changes what kind of commit it is does not fold. If the correction would change the target's type, or would make it need a handover it does not have, it is its own commit with its own iteration and handover. Folding is for a correction that belongs to the commit it names.

## Input contract

| Input | Meaning |
|---|---|
| target commit | The closed commit the correction belongs to, by hash or by subject. |
| correction | What the correction changes, in one sentence. |
| belonging | Why this correction belongs to that commit, which is what makes the fold right. |

## Establish the target

Confirm the commit exists and is not HEAD, and record the branch it sits on.

```bash
git log --oneline --all | grep -F "<target subject>"
git show <target> --stat --format="%h %s"
```

If the commit is HEAD, stop. A HEAD commit is not closed and takes an ordinary commit, not a fold. If two commits share the subject, the correction names a subject that does not identify one commit; ask which.

## Test whether the correction folds

Read the commit type policy before folding anything, and answer one question: does the correction change what this commit is?

- The correction restores what the commit already claimed, or fixes its content, and the type stands. Fold it.
- The correction changes the commit's type, or adds a handover the commit's type requires and it lacks. Stop folding. The correction is its own commit with its own iteration and handover, placed after the target.

## Create the fixup

Stage only the correction, then commit against the target by hash.

```bash
git add <paths>
git commit --fixup=<target hash> -m "fix: <short reason>"
```

Name the target by hash here, not by subject. The hash is unambiguous at this point; the subject is not.

## Fold it

Set a non-interactive sequence editor. An unset one makes the rebase stop for an editor that does not exist, which reads as a crash rather than a prompt.

```bash
GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash --autostash HEAD~<n>
```

`--autosquash` moves the fixup to sit immediately after the commit whose subject its message names, then squashes it. It silently does nothing when no commit carries that subject. Three things cause that, and all three are silent:

- The target's subject changed since the fixup was written, so the `fixup!` prefix points at text no commit holds.
- The target is a merge commit, so `--autosquash` has no single line to move the fixup onto.
- The target is further back than `HEAD~<n>` reaches, so it is not in the todo at all.

If the fixup does not fold, write the todo by hand rather than retrying the flag. An explicit sequence editor that places `fixup <hash>` on the line immediately after the target is correct in every case the flag fails, and it is the only form whose result you can read back.

```bash
# sequence editor that reorders the fixup onto its target line
GIT_SEQUENCE_EDITOR=<script> git rebase -i --autostash HEAD~<n>
```

## Verify the fold

This step is not optional and not a formality. Run it every time.

```bash
git log --oneline -6 | grep -c "fixup!"     # must be 0
git show <target> --stat --format="%h %s"    # must list the corrected file
git show <target>:<path> | grep -F "<the corrected text>"
```

The first proves no fixup survived. The second proves the commit carries the file. The third proves the content is the corrected content, read out of the target itself rather than from the working tree. Only the third catches the failure this runbook names, where the rebase exited zero, the fixup stayed at the top of the branch, and the correction sat in a commit nobody would read.

Then run the repository gates on the rewritten tree, because a fold changes content a commit already claimed.

```bash
bash scripts/lint.sh
bash scripts/run_tests.sh
git status --porcelain    # clean
```

## Close

Report the target commit's before and after hash, the fixup's new hash, the output of all three verification commands, and the gate numbers. State whether the correction folded or became its own commit, and why. If the target was a merge commit, say so, because a folded correction into a merge is a history rewrite the operator may want to see again.
