---
description: Fold a correction into a closed commit that is not HEAD, without rewriting anything else. The target commit is rewritten in place and the correction lands inside it, with its own handover where the record requires one.
argument-hint: "[target commit hash or subject] [what the correction changes] [why it belongs to that commit]"
---

> $@

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `work-log`, `decision-records`, `git-discipline`

## Mandate

You are correcting a record that has already been closed. The operator named the commit the correction belongs to. Your deliverable is that commit rewritten to carry the correction, with no other commit touched, no commit added, and no port artifact left behind.

A correction is not a new commit. A closed iteration's commit keeps its identity, its message, and its place in history, and the fix folds into it. The `git-discipline` convention, `.agents/skills/git-discipline/SKILL.md`, owns that rule. This prompt owns the record principle behind it and the mechanics that apply it.

Two rules govern the run.

First, verify the fold, never assume it. `git rebase --autosquash` reports success when it has matched nothing at all, and it matches on the target's subject line, not on the hash you named. Every failure this runbook exists to prevent came from a rebase that exited zero over a fixup still sitting at the top of the branch. Read the change out of the target commit by hand before you report.

Second, a correction that changes what kind of commit it is does not fold. If the correction would change the target's type, or would make it need a handover it does not have, it is its own commit with its own iteration and handover. Folding is for a correction that belongs to the commit it names.

Report and stop when the fold needs an interactive rebase with several conflict edits. The cost has moved past an amendment, and the alternative instrument is a port, [`/rebase`](rebase.md). What may be amended after a close is in [`iteration_policy.md`](/opt/sandbox/docs/policies/iteration_policy.md); which change a correction may contain is the judgement of `principle-minimal-corrections`, and this runbook decides only where it lands.

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

## Correcting a record

A closed record is edited only at the operator's direction, and every edit carries the corresponding correction tag. The operator signals direction any way it is said: "amend the handover", "reopen the handover", "edit it", "fix the typo", or by naming the change. A correction is never applied unasked.

Three forms qualify:

- A **misrecording**: an incorrect status, a wrong filename, a misrecorded decision, or a count or state that disagrees with the tree.
- A **folded fix**: a later squash, fixup or amend folded into the close, and the record amendments the fold carries.
- An **omission**, and only where the record's own account of what the iteration turned in is incomplete without it: the iteration delivered something and did not record a defect in it.

An omission is not a place to record work the iteration never did, and it is not a place to state a limit the iteration set only afterwards. Both are new work, and a new record carries them.

A closed record's content does not change; what changes is the account, and only where the account is wrong. The agent may notice a correction and propose it in one line, and never deletes a record, because deletion is an operator action.

### The form follows the record's purpose

A record that states what is true is corrected in place. A record that tracks open and closed tasks is corrected by addition, with a successor entry. A type's durability, and the marker it carries, is [`documentation_taxonomy.md`](/opt/sandbox/docs/reference/documentation_taxonomy.md#durability).

| Record | Nature | Form |
|---|---|---|
| Handover | states what the iteration did | rewrite the paragraph, or reopen and close it again; either way the tag at the end of the corrected section |
| Roadmap entry | tracks open and closed tasks | keep the entry, add the superseded marker, add the successor entry |
| Changelog entry | tracks closed tasks, archived | as a roadmap entry |
| Discussion record | states reasoning and evidence | rewrite, tag |
| ADR, concept, architecture, policy | states what the system does | rewrite, tag |

**Propagation.** A correction inherits the record set of the unit it corrects: a unit that changed code, a task description and a handover is corrected in all three, and every closed record among them takes its marker. A correction that leaves a closed record contradicting its successor is incomplete.

**Archival is not amendment.** Moving a closed milestone's entries from the roadmap to the changelog is a length boundary, not a correction, and carries no marker.

**Two stops bound the work.** A correction that changes the unit's scope, or that carries new work, is a new iteration. A correction whose edit would carry no marker is a rewrite, and it stops too.

### Procedure

1. Confirm the operator's direction and identify the paragraph or section.
2. Rewrite the entire affected paragraph, or section, in place. Do not leave an inline marker such as a reference count or a `[see correction below]` label. The rewritten text reads as the record.
3. Insert the correction tag as a block at the end of the corrected section, immediately before the start of the next section:

```text
---
[CORRECTION -- YYYY-MM-DD: <one to three lines describing the change and the reason>]

---
```

Keep the blank line before the closing fence. Without it, the tag paragraph parses as a setext heading and the Markdown lint gate reports `MD022`.

4. Order multiple correction tags newest first, oldest last, the way an ADR orders its dated entries.
5. Do not alter the `status`, the date, or any other frontmatter field in the corrected record. A reopen and re-close cycle is a procedure step, not a record edit: the record ends `Closed`, with the date and metadata it carried before.
6. **Findings triage.** If the correction surfaces a new finding, route it before the correction is finalised: to the active handover's `## Findings`, to a new roadmap row, or to the document the finding concerns. The correction tag states where the finding was routed.

### What this is not

A correction is not a substitute for a new record. Work the iteration did not do is new work, and a new record carries it.

A correction may reopen the record. Reopening to adjust the work and closing again is a correction path. A correction that cannot be finished returns the record to `Closed` as it was.

## Close

Report the target commit's before and after hash, the fixup's new hash, the output of all three verification commands, and the gate numbers. State whether the correction folded or became its own commit, and why. If the target was a merge commit, say so, because a folded correction into a merge is a history rewrite the operator may want to see again.
