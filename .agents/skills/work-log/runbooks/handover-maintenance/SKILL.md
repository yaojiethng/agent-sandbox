---
name: handover-maintenance
description: "Checks handover content and the closed handover chain against the project's work-log convention, and reports the violations. Use when the operator asks to check handover content quality, audit the handover chain, trace a deferred item across iterations, or correct handover structure. Writes nothing."
---

# handover-maintenance

## Purpose

Checks handover documents and reports the violations of the `work-log` convention. The run finds each violation and reports it in the form the caller consumes. It writes no record, applies no correction, and invents no fact.

This runbook is the index. The checks live in two runbooks, one per subject, and each names the moment it opens.

## Runbooks

| Runbook | Subject | Open it when | Dispatched by |
|---|---|---|---|
| [`content.md`](content.md) | the handover the current iteration is writing | at the scope gate, before the criteria are released, and again at the pre-close | `/iter` steps 5 and 7, `wrapup` B6 |
| [`chain.md`](chain.md) | the chain of handovers already closed | a periodic or event-driven audit, or a workflow that reads the chain | an operator audit |

## The shape every handover is checked against

The record's shape is this convention's template; its controlled vocabulary is the `work-log` convention. This runbook states no vocabulary of its own. Both runbooks check:

| Check | Against |
|---|---|
| the four frontmatter keys are present | the template |
| `type` holds a value from the vocabulary | the convention |
| `status` holds a value from the vocabulary | the convention |
| every section the template carries is present, and no forbidden section is | the template and the convention |
| each empty nullable section carries its canonical marker | the convention |
| the filename follows the pattern | the convention |
| the record is inside the format window, or exempt | the convention |

Read [`../../SKILL.md`](../../SKILL.md) for the vocabulary, the format and the window, and [`../../assets/handover.md`](../../assets/handover.md) for the shape.

## Output shape

Report the findings in your reply. The caller applies them; this runbook writes no record and commits nothing.

Print a one-line summary when a run ends: the findings count and the skip count.

A finding that does not block a gate is still reported; the caller decides where it is routed.

## Non-goals

- Does not write a record, apply a correction, or commit. The caller applies the report.
- Does not close an iteration. The chain runbook reports what is already closed and what needs escalation.
- Does not check the roadmap. That is [`roadmap-maintenance`](/opt/workflow/agent/modules/coding-agent/skills/roadmap-maintenance/SKILL.md).
- Does not write policy. A finding that no policy text covers is a gap to report, not a rule to add here.
- Does not audit handovers outside the scope set the chain runbook names. A wider sweep is a separate run with its own scope.
- Does not choose a commit shape, a message, or a fold.
