---
date: 2026-11-24
milestone: M3.5.1 - The work-log record layer
type: Housekeeping
status: Closed
---

# Handover - fold the handover check into work-log

## Objective

Move the handover check from a module skill to a runbook of the `work-log` convention, so it is agent-sandbox's and no longer ships to projects that do not use handovers.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The runbook sits under `work-log`. | `test -f .agents/skills/work-log/runbooks/handover-maintenance/SKILL.md` | Accepted |
| The module ships no `handover-maintenance` directory. | `test ! -d workflow/coding-agent/skills/handover-maintenance` | Accepted |
| `work-log` names the runbook, and the callers name the new home. | `grep -rn 'handover runbook' .agents/skills/work-log workflow/coding-agent/prompts docs/reference` | Accepted |
| The runbook's links resolve and the check still runs. | `bash scripts/check_skill_map.sh`; `bash scripts/check_handover_format.sh` | Accepted |
| Lint and the suite pass. | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | Accepted |
| Every decision this iteration recorded is realized in the files. | read the Decisions table against `git diff` | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The check becomes a runbook under `work-log`, keeping its frontmatter, like `doc-maintenance`. | A runbook is the same shape as the existing project runbooks, and the nested path keeps it out of the top-level skill index. | This record |
| The runbook's `## Project conventions` section is removed. | Inside `work-log`, telling the reader to read `work-log` is self-referential. | This record |
| Module prompts name the path in a code span, not a link. | A shipped-layer link to `.agents/` crosses the layer boundary the skill map forbids. | This record |
| Current ADR statements are corrected in place; historical entries stay as written. | The move changes the surface's home, not the historical record of why it existed. | This record |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The module seed's `work-log` convention stays generic, so external projects get no handover check. | record | That is the intent: the handover record is agent-sandbox's. | `initialize` seed, unchanged |
| A historical rationale in `closed_record_corrections.md` still names the old skill. | record | It records the state at the time; rewriting it would falsify the record. | Left as written |
