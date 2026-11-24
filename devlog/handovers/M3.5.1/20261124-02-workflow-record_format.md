---
date: 2026-11-24
milestone: M3.5.1 - The work-log record layer
type: Workflow
status: Closed
---

# Handover - define the record format once

## Objective

Define the per-iteration record format once in `work-log` and delegate to it, so a new record stops carrying parts no reader uses and no carrier restates the format.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A record carrying the template's format passes the gate. | `bash scripts/check_handover_format.sh devlog/handovers/M3.5.1/20261124-02-workflow-record_format.md` | Accepted |
| A record carrying older parts still passes. | `bash tests/test_handover_format_gate.sh` | Accepted |
| A record missing a part the template declares fails, naming it. | `bash tests/test_handover_format_gate.sh` | Accepted |
| The template is the only declaration: the gate reads its headings, and `work-log` points at it. | `grep -n 'template' .agents/skills/work-log/SKILL.md scripts/lint/handover-format.mjs` | Accepted |
| The prompts point at `work-log` and name no format set; `gm` reads the record per the format. | `grep -n 'work-log' workflow/coding-agent/prompts/iter.md workflow/coding-agent/prompts/wrapup.md workflow/coding-agent/prompts/gm.md workflow/coding-agent/prompts/sidequest.md` | Accepted |
| `iteration_protocol.md` reconciles the close against the record and the roadmap. | `grep -n 'acceptance' docs/reference/iteration_protocol.md` | Accepted |
| Every decision this iteration recorded is realized in the files. | read the Decisions table against `git diff` | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The `work-log` template is the format declaration; the gate reads its headings. | One artifact owns the format and the worked example, so they cannot drift, and a format change is a `work-log` change. | This record; `work-log/SKILL.md` |
| The gate requires the template's headings and forbids nothing the old records carry, so a record with older parts passes. | A relaxation lets an old record and a new one both pass and keeps the migration seamless. | This record; `handover-format.mjs` |
| The prompts and the close point at `work-log`; no carrier restates the format set. | The format has one owner, and a later change edits one place instead of many. | This record; the prompts |
| A record that still carries the older format's pending-decision part closes it under that shape; the current format carries none. | One prompt serves both shapes without making the old part mandatory. | This record; `wrapup.md` |
| `gm` reads the record per the format, closing the `/gm` read-contract row. | The check-in's read must name only what the convention carries. | This record; `roadmap.md` |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Roadmap maintenance: M3.6.5 is fully checked while its summary reads `In progress`; the close owns the flip, and an early flip unassigns its handovers. | record | Carried, not fixed here. | `roadmap.md` M3.6.5, its close |
| The `/iter` prompt told the iteration to record the maintenance execution in the completed-work part, which the current format does not carry. | record | The prompt is a carrier; this iteration records the note here and repoints the instruction. | This iteration, `iter.md` |
| Operator steering: the format must be defined once and delegated to `work-log`, not restated as a part list across the prompts; the coined term is not the project's vocabulary. | record | The carriers each named the parts, so the format had many owners; the rework moved the declaration to the template and made the prompts point at `work-log`. | This iteration, the rework |
| The format gate now reads the `work-log` template, so a project without the convention-skill fails with a named path. | code | The install seeds the skill; the failure names the missing template, so the gap is visible rather than silent. | `work-log`; the gate |
