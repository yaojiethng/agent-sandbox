# Partial - the intent survives, the disk is incomplete

The record holds what the unit was for, and a fragment of the work survives in the working tree, the index or the stash. The class is `partial`.

## When

The operator reports that the session or the chat is gone and the disk holds part of the change. `git status` or `git stash list` names the fragment; no commit carries the whole unit.

## Procedure

1. **State the claim.** Read the unit's handover and session record for what it was for, the files it covered and what the record says landed.
2. **Preserve.** Before touching the tree, capture a recovery point: copy the working tree, or `git stash push` it, or bundle the branch. A `git restore`, `checkout`, `clean` or `reset --hard` before this can take the fragment with it.
3. **Read what survived.** `git status`, the index, the stash, and the transcript for the edits. Separate the fragment from the intent; a fragment a commit already carries is not missing.
4. **Finish or retrieve.** Apply the missing part and run the suite. If a commit, the reflog or a bundle holds the rest, retrieve it rather than retyping; if the intent itself is lost, use [`absent.md`](absent.md).
5. **Verify against the claim.** The file set matches the handover, the suite passes, the tree is clean, and one commit carries the unit.
6. **Record.** In the handover, state what survived, the source that held it, what was retrieved or rebuilt, and the checks.

## Handoff

A finished unit hands to `/commit`. A unit whose intent is lost hands to [`absent.md`](absent.md).

## Close

Report the unit, what survived, the evidence source, what was rebuilt or retrieved, and the checks.
