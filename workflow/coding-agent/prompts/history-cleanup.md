---
description: Start a history cleanup. Name the commit range; the history-cleanup runbook rewrites the series into a reviewable, bisectable sequence.
argument-hint: "[<base>..<tip> - the commit range to clean]"
---

> $ARGUMENTS

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `work-log`, `task-list`

Run the [`history-cleanup`](/opt/workflow/agent/modules/coding-agent/skills/git-discipline/runbooks/history-cleanup/SKILL.md) runbook from the repository root, with the range above as its input. The runbook owns the properties, the audit, the two releases and the report.
