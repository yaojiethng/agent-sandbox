# Recovery

## The classes

A recovery starts by naming the state the work is in, because five of the six classes replay or repair something the repository still holds, and only the last one derives it again. The state is decided by what the repository contains, never by what a record says happened. A handover is the entry to this table: it is how a reader learns work is missing, and it is not evidence of the class.

| Class | How it is known | Runbook |
|---|---|---|
| Uncommitted | `git status` names the changes, and no commit carries them | [`/commit`](../../../../workflow/coding-agent/prompts/commit.md) |
| Unlanded export | a draft branch holds the commits, and they apply to the target as they stand | [`/merge`](../../../../workflow/coding-agent/prompts/merge.md) |
| Unportable | the commits exist, the target has moved, and the diff no longer applies | [`/rebase`](../../../../workflow/coding-agent/prompts/rebase.md) |
| Malformed series | the branch's commits are inverted, or a commit is not a reviewable unit | [`history-cleanup`](../../../../workflow/coding-agent/skills/history-cleanup/SKILL.md) |
| Landed wrong | a closed commit carries a defect, and the commit itself is where the fix belongs | [`/record-correction`](../../../../workflow/coding-agent/prompts/record-correction.md) |
| Absent | a record states the work exists, and no commit, branch or tree holds it | `## Rebuild`, below |

A lost commit that a handover already describes is `Absent` all the same, and a branch whose commits survive but will not apply is `Unportable` even when the handover calls that iteration lost. The record states what was intended; only the repository states what is there.

## Replay or port

Two rows move existing commits onto the current branch, and choosing the wrong one loses the work twice. `/merge` replays: the drafts are finished, and their content lands as it stands, one commit per iteration, with the conflicts resolved once. `/rebase` ports: the target moved around the work, so each commit is re-realized against the current tree, and content the target already carries or superseded is dropped.

The test is what the replay would cost. A merge resolves conflicts and lands the same commits; a port re-derives the intent of each iteration, so a clean three-way merge that leaves the tree wrong is still a port.

## Rebuild

Use this when the class is `Absent`.

Entry conditions: a record from a session log, a transcript, or chat history states what the lost iterations changed, and at least one handover describes them.

1. **Establish what survived.** Read the range the loss covers, the working tree, and the handovers. The handovers state what each iteration was for; the session record is the only record of the edits themselves.
2. **Order the iterations.** One commit each, in the order they were done. An iteration with no artifact output, such as a planning iteration, is skipped rather than committed empty.
3. **Rebuild one iteration at a time.** Apply that iteration's changes, run the suite, commit. The commit keeps that iteration's original message, and it carries that iteration's handover.
4. **Write the handover for each rebuilt commit.** It is dated and numbered for the iteration it describes, and it reads `Status: Closed`, because the work it records was done. One line at its head says the record was written from a rebuild.

The rebuild is a replay of intent, not of hunks. Where the tree has moved since the iteration, the same rule as a port applies: what the tree already carries is dropped, and what it superseded is adapted. A rebuild that copies a stale diff lands a tree that never ran.

## Verify the rebuild

A rebuild, a port and a history rewrite share one risk: a record that describes a series the repository no longer has. Verify the artifact, not the transcript, and cite the gate that decides each check.

| Check | Decided by |
|---|---|
| One handover per commit, named and dated per the work-log convention | `bash scripts/check_handover_format.sh` |
| The document set and the record shape match the conventions | `bash scripts/lint.sh` |
| Every commit is checkoutable and the suite passes at the tip | `bash scripts/run_tests.sh` |
| No working document, patch residue, or wrong-prefixed file in history | `git log --all --diff-filter=A -- RECOVERY.md`, `git log --all -- '*.rej'`: no match |
| The range reads as the iterations the handovers claim | `git log --oneline <baseline>..HEAD`, read against them by hand |
| The tree is clean | `git status --short`: no output |

The last row is the only one a reader can skip, and it is the one that finds a rebuild whose handovers describe work the tree does not hold.

## Known gaps

- **No expected test count.** The suite's total is evidence of nothing on its own: a rebuild that drops a test file still reports a passing run. The count at the range's start is the closest baseline, and a drop from it is a finding to explain.
- **The session record is interface-specific.** A session log's schema is not standardised across interfaces, so the rebuild's only portable record of the edits is the transcript. When that is lost, the handovers state the intent and nothing states the change.
- **A rebuild cannot recover an unrecorded decision.** A choice the iteration made and no record holds comes back as a different choice, and the rebuilt commit is then internally consistent and wrong. The handover's decisions table is the only guard.
