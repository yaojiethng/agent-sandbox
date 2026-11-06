---
name: recovery
description: "Route a recovery: read the operator's description of lost or partial work, classify it as partial or absent, and open the runbook. Redirects a correction or a mergeability problem to its own command. Operator-invoked by /recovery; the model does not start a recovery on its own."
disable-model-invocation: true
---

# recovery

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `git-discipline`, `work-log`

## The input

The operator starts `/recovery` and describes what is wrong. That description is the skill's argument. Read it before anything else. If it is empty, ask one question: what is missing, and what does the record say landed?

The start is the operator's; the form is yours. Do not ask the operator to classify the loss. Read the description, decide, and route.

## The classes

| The description says | Class | Route |
|---|---|---|
| the work is half there; the chat is gone; the disk holds part of it | partial | [`runbooks/partial.md`](runbooks/partial.md) |
| the record says it landed, and no commit holds it | absent | [`runbooks/absent.md`](runbooks/absent.md) |
| the commit is wrong | correction | stop: `/record-correction` |
| the series is messy, or a commit is not reviewable | correction | stop: `history-cleanup` |
| the branch will not rebase onto its parent or the trunk | mergeability | stop: `prepare-rebase` |

The last three are not recovery. Nothing was lost; the repository holds the work and the operator wants a different result. Naming the right command is the handoff, not a refusal.

If the description fits partial and absent at once, ask one question: does any commit carry the work? A commit that carries part of it is `partial`; no commit at all is `absent`.

## The runbook

Open the runbook the class names. It owns the procedure, the verification and the close. This skill owns the classification and the redirect.

## Handoff

- A wrong commit: `/record-correction`.
- A messy series: [`history-cleanup`](../history-cleanup/SKILL.md).
- A branch that cannot land: `prepare-rebase`.

## Close

Report the class, the runbook that ran, what the repository held, and the checks. If the class was a redirect, report the command the operator should run instead.
