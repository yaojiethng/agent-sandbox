# Absent - the record claims work the repository does not show

The record says the unit landed; the branch does not carry it. The class is `absent`.

## When

A handover or the roadmap states the work exists, and the branch the record names does not hold it. The work may still survive somewhere: the reflog, a dangling object, another ref, a bundle or the transcript. `absent` is the verdict after the search, not the start of it.

## Procedure

1. **State the claim.** Read the record for the unit, the commit range, the files and what it says landed. The claim is what the evidence is compared against.
2. **Preserve.** Capture a recovery point before any destructive operation: bundle the branch and its refs, or copy the `.git`. Treat the search's own commands (`checkout`, `restore`, `clean`) as destructive; capture the point first.
3. **Search, and name every source.** Follow the order in the skill: working tree and index, stash, every ref, the reflog, dangling objects (`git fsck --lost-found`), the draft or bundle and output channel, the session transcript, the host checkpoints. [`references/evidence.md`](../references/evidence.md) names where each lives. Write down what each held.
4. **Retrieve before rebuild.** A commit in a ref, the reflog, a dangling object, a bundle or an artifact is restored, not rebuilt: recover the commit or tree, re-point the branch, and verify it. Only when the search finds nothing is the work rebuilt.
5. **Rebuild only from the record.** Order the units one commit each, in the order they were done. Apply each unit's changes, run the suite, commit with that unit's original message, and write its handover. A rebuild is a replay of intent, not of hunks: drop what the tree already carries, adapt what it superseded. A rebuild that copies a stale diff lands a tree that never ran.
6. **Verify against the claim.** The restored tree matches the handover's file set; the suite passes; the range reads as the units the handovers claim; the tree is clean. Where the record overclaimed, correct it.
7. **Record.** In the handover, state what was lost, what survived, the source that decided it, what was searched, and whether the repair retrieved or rebuilt.

## Verify the rebuild

A rebuild, a port and a history rewrite share one risk: a record that describes a series the repository no longer has. Verify the artifact, not the transcript, and cite the gate that decides each check.

| Check | Decided by |
|---|---|
| One handover per commit, named and dated per the work-log convention | `bash scripts/check_handover_format.sh` |
| The document set and the record shape match the conventions | `bash scripts/lint.sh` |
| Every commit is checkoutable and the suite passes at the tip | `bash scripts/run_tests.sh` |
| No working document, patch residue, or wrong-prefixed file in history | `git log --all --diff-filter=A -- RECOVERY.md`, `git log --all -- '*.rej'`: no match |
| The range reads as the units the handovers claim | `git log --oneline <baseline>..HEAD`, read against them by hand |
| The tree is clean | `git status --short`: no output |

The last row is the only one a reader can skip, and it is the one that finds a record whose handovers describe work the tree does not hold.

## Handoff

A rebuilt unit hands to `/commit` if it is not committed, or the normal close.

## Known gaps

- **No expected test count.** The suite's total is evidence of nothing on its own: a rebuild that drops a test file still reports a passing run. The count at the range's start is the closest baseline, and a drop from it is a finding to explain.
- **The session record is interface-specific.** A session log's schema is not standardised across interfaces, so the portable record of the edits is the transcript. When that is gone, the handovers state the intent and nothing states the change.
- **A rebuild cannot recover an unrecorded decision.** A choice the unit made and no record holds comes back as a different choice, and the rebuilt commit is internally consistent and wrong. The handover's decisions table is the only guard.
