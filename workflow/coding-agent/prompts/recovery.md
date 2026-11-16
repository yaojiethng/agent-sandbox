---
description: Start a recovery. Describe what is missing or wrong; the recovery skill establishes the claim, searches the evidence, opens the runbook, or redirects it to the command that owns it.
argument-hint: "[what is missing or wrong - e.g. the last change is half there; the record says it landed and it did not]"
---

> $ARGUMENTS

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `work-log`, `task-list`

Run the [`recovery`](/opt/workflow/agent/modules/coding-agent/skills/recovery/SKILL.md) skill from the repository root, with the description above as its input. The skill owns the classification, the runbooks and the redirects.

The skill owns the procedure and the classes; its `references/evidence.md` names where the evidence lives by runtime and delivery mode.
