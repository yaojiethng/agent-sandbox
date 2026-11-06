# Partial - the intent survives, the disk is incomplete

The record holds what the iteration was for, and the working tree holds part of it. The class is `partial`.

## When

The operator reports that the chat or the session is gone, and the disk holds a fragment of the change. `git status` names the fragment; no commit carries the whole iteration.

## Procedure

1. **Read the intent.** Open the iteration's handover and the session record. The handover states what the iteration was for; the session record is the only record of the edits themselves.
2. **Read what survived.** `git status`, the working tree and the last commit. Separate the fragment from the intent. A fragment that a commit already carries is not missing.
3. **Finish the iteration.** Apply the missing part, run the suite, and close the iteration the normal way. When the intent itself is lost and no record states it, use [`absent.md`](absent.md)'s rebuild for the missing part.
4. **Verify.** The tree is clean, the suite passes, the handover is closed, and one commit carries the iteration.

## Handoff

A finished iteration hands to `/commit`. A iteration whose intent is lost hands to [`absent.md`](absent.md).

## Close

Report the iteration, what survived, what was rebuilt, and the checks.
