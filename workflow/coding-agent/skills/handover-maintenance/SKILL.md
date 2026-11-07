---
name: handover-maintenance
description: "Checks handover content and the closed handover chain against the project's work-log convention, and reports the violations. Use when the operator asks to check handover content quality, audit the handover chain, trace a deferred item across iterations, or correct handover structure. Writes nothing."
---

# handover-maintenance

<!-- Merge provenance: Track A (the two content checks and their run conditions) is the substance of .agents/audits/handover-audit.skill.md. Track B (the triggers, the scope list, the seven-step procedure, and the report) is the substance of .agents/audits/audit.skill.md. Both files are superseded by this skill and were removed by handover 20261003-02. The skill was made report-only by handover 20261004-10, which took back the part of commit c1bc00e that made a maintenance run write its corrections: the checks stay, the write authority leaves, and no audit file is restored. The two tracks became two runbooks by handover 20261023-17, because a track has no caller and a runbook does. -->

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `work-log` - the handover record and the exploration record.

## Purpose

Checks handover documents and reports the violations of the project's `work-log` convention. The run finds each violation and reports it in the form the caller consumes. It writes no record, applies no correction, and invents no fact.

This skill is the index. The checks live in two runbooks, one per subject, and each names the moment it opens.

## Runbooks

| Runbook | Subject | Open it when | Dispatched by |
|---|---|---|---|
| [`runbooks/content.md`](runbooks/content.md) | the handover the current iteration is writing | at the scope gate, before the criteria are released, and again at the pre-close | `/iter` steps 5 and 7, `wrapup` B9 |
| [`runbooks/chain.md`](runbooks/chain.md) | the chain of handovers already closed | a periodic or event-driven audit, or a workflow that reads the chain | an operator audit |

## The shape every handover is checked against

The record's shape is the project's template; its controlled vocabulary is the project's `work-log` convention. This skill states no vocabulary of its own. Both runbooks check:

| Check | Against |
|---|---|
| the four frontmatter keys are present | the template |
| `type` holds a value from the vocabulary | the convention |
| `status` holds a value from the vocabulary | the convention |
| every section the template carries is present, and no forbidden section is | the template and the convention |
| each empty nullable section carries its canonical marker | the convention |
| the filename follows the pattern | the convention |
| the record is inside the format window, or exempt | the convention |

Read `.agents/skills/work-log/SKILL.md` for the vocabulary, the section roles and the window, and `.agents/skills/work-log/assets/handover.md` for the shape.

## Output shape

Report the findings in your reply. The caller applies them; this skill writes no record and commits nothing.

Print a one-line summary when a run ends: the findings count and the skip count.

A finding that does not block a gate is still reported; the caller decides where it is routed.

## Non-goals

- Does not write a record, apply a correction, or commit. The caller applies the report.
- Does not close an iteration. The chain runbook reports what is already closed and what needs escalation.
- Does not check the roadmap. That is [`roadmap-maintenance`](/opt/workflow/agent/modules/coding-agent/skills/roadmap-maintenance/SKILL.md).
- Does not write policy. A finding that no policy text covers is a gap to report, not a rule to add here.
- Does not audit handovers outside the scope set the chain runbook names. A wider sweep is a separate run with its own scope.
- Does not choose a commit shape, a message, or a fold.
