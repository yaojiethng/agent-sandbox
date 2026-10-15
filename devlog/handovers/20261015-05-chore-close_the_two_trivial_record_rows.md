---
date: 2026-10-15
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Housekeeping
status: Closed
---

# Handover - close the two trivial record rows

## Objective

Resolve the two M3.3.1 rows that needed no design, so they leave the task list rather than rehome to it.

## Scope

Two rows the triage of M3.3.1 marked trivial: `The handover opens as Active` and `The settled discussion docs carry their status in the filename`. The operator directed them to a sidequest rather than a rehome, so they land here as one unit.

Out of scope: the five non-trivial drift rows, which rehome under handover `20261015-04`, and closing M3.3.1.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The template and the iteration prompt agree on the opening state | `grep -n "status:" .agents/skills/work-log/assets/handover.md` returns `Active`; `iter.md` also sets `Active` | Agent [x] |
| The work-log vocabulary names the same states | `.agents/skills/work-log/SKILL.md` states Active on open, Closed at end, Open ahead of the iteration | Agent [x] |
| No discussion filename contradicts its `Status:` field | both renamed files carry `settled` in the name and `**Status:** settled` inside; `grep -rn` finds no old name | Agent [x] |
| `bash scripts/lint.sh` is clean | run it, eight gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The template opens `Active`, rather than the prompt setting `Open` | `iter` creates the record as the iteration starts, so the record is running at creation; the template should be correct on copy | `.agents/skills/work-log/assets/handover.md` |
| The work-log vocabulary names `Open` as the pre-iteration state | it keeps the state meaningful rather than vestigial, and it makes the template, the vocabulary and the prompt agree | `.agents/skills/work-log/SKILL.md` |
| The renames reach closed handovers' links | a link to a renamed file does not resolve; re-pathing is the correction the archive boundary already applied | the four handovers |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| Both rows were filed under M3.3.1 for proximity, not subject. One is a `work-log` template defect and the other a discussion naming defect. Triaged to: their own subjects, `work-log` and the discussion naming rule. | steering | `work-log` |

## Completed

| File | Change |
|---|---|
| [`.agents/skills/work-log/assets/handover.md`](../../.agents/skills/work-log/assets/handover.md) | the opening `status` is `Active` |
| [`.agents/skills/work-log/SKILL.md`](../../.agents/skills/work-log/SKILL.md) | the status vocabulary names Active on open and Open ahead of the iteration |
| [`devlog/discussions/20261014-design-settled-coding_agent_binding_surface.md`](../../devlog/discussions/20261014-design-settled-coding_agent_binding_surface.md) | renamed from `-draft-` to `-settled-` to match its `Status:` field |
| [`devlog/discussions/20261004-study-settled-deepseek_effort_levels.md`](../../devlog/discussions/20261004-study-settled-deepseek_effort_levels.md) | renamed to carry its `settled` status |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | inbound links to both renamed documents retarget |
| [`docs/adr/coding_agent_project_bindings.md`](../../docs/adr/coding_agent_project_bindings.md) | the binding-surface link retargets |
| [`devlog/handovers/20261004-05-impl-deepseek_effort_levels.md`](20261004-05-impl-deepseek_effort_levels.md) | the study reference retargets |
| [`devlog/handovers/20261014-02-design-policy_content_home.md`](20261014-02-design-policy_content_home.md) | the binding-surface link retargets |
| [`devlog/handovers/20261014-04-design-default_convention_surface.md`](20261014-04-design-default_convention_surface.md) | the binding-surface link retargets |
| [`devlog/handovers/20261014-06-design-handoff_contract.md`](20261014-06-design-handoff_contract.md) | the binding-surface link retargets |
| [`devlog/handovers/20261015-05-chore-close_the_two_trivial_record_rows.md`](20261015-05-chore-close_the_two_trivial_record_rows.md) | this record |
