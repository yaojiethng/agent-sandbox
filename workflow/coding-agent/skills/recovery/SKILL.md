---
name: recovery
description: "Recover lost work: state what the record claims, find what the repository and the session record actually hold, preserve it, then retrieve or rebuild and verify. Operator-invoked by /recovery; the model does not start a recovery on its own."
disable-model-invocation: true
---

# recovery

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `git-discipline`, `work-log`

## What this is for

The operator believes directed work is lost. Find out what survived before deciding anything. The claim is what the record says; the evidence is what the repository, the session record and the artifacts hold; the repair reconciles them.

A session that is merely open is resumed, not recovered. These are not recovery either: a wrong commit (`/record-correction`), a messy series ([`history-cleanup`](../history-cleanup/SKILL.md)), a branch that will not land (the `prepare` runbook), and a broken host draft (`T11`: `make reject` then `make draft`). Nothing was lost in any of them; the repository holds the work and the operator wants a different result.

## Triage

1. **State the claim.** Read the handover, the roadmap and the session record for what the unit was for, what range or files it covered, and what the record says landed. Write the claim down before searching; it is what the evidence is compared against.
2. **Preserve.** Capture a recovery point before any destructive operation: the working tree, the stash, the reflog and the branch, or a `git bundle`. A `git restore`, `checkout`, `clean`, `reset --hard` or `stash drop` before this step can destroy the only copy.
3. **Search.** Look for the work in the order below and name every source you checked. [`references/evidence.md`](references/evidence.md) states where each one lives by runtime and delivery mode.
   - the working tree and the index
   - the stash
   - every ref: branches, tags and worktrees
   - the reflog
   - dangling objects
   - the draft or bundle and the output channel
   - the session transcript or log
   - the host checkpoints
4. **Decide from the evidence.** `partial` when a fragment survives; `absent` only when the search above found nothing. Within `absent`, the evidence state selects retrieval or rebuild: work in a ref, the reflog, a dangling object or a bundle is retrieved; work only in the record is rebuilt.
5. **Restore and verify.** Apply the retrieval or the rebuild, then check it against the claim: the file set, the suite, and the commit or handover the record names. Where the record overclaimed, correct the record.
6. **Record.** In the handover, state what was lost, what survived, the source that decided it, what you searched, and what the repair did.

## The classes and their runbooks

| The evidence says | Class | Route |
|---|---|---|
| a fragment survives in the tree or the stash | partial | [`runbooks/partial.md`](runbooks/partial.md) |
| nothing survives after the search | absent | [`runbooks/absent.md`](runbooks/absent.md) |

## Close

Report the class, the runbook that ran, what the repository held, what was retrieved or rebuilt, and the checks. If the description named a boundary above, that command is the handoff: name it and stop.
