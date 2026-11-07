---
date: 2026-11-07
milestone: M3.3.6 - The instruction corpus and its map
type: Workflow
status: Closed
---

# Handover - The check-in's report contract is cut

## Objective

Cut the check-in's JSONL record-report contract and its auditor dispatch, fold the light survey and inventory into `/gm`, and keep only the violation classes that the task-list and work-log redesign will need.

## Scope

The operator directed the overhaul after the thoroughness path was found to have no recorded use and no code consumer. In scope: the `/gm` prompt, the retirement of the `check-in` skill and its two references, the output sections of `roadmap-maintenance`, `handover-maintenance` and `doc-maintenance`, the `fix-now` residue in `/milestone-close` and `propagation-check`, the statechart and ADR carriers, the inventory-axis pointer in `/milestone-start`, and the roadmap write-back. Out of scope: rebuilding the image, which is a host operation; releasing the requirements draft out of `.agents/drafts/`; and the task-list/work-log redesign itself.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `/gm` owns the light survey and inventory, and no `check-in` skill remains | `test ! -d workflow/coding-agent/skills/check-in`; read `gm.md` | Agent [x] |
| No live `auditor`, `report-schema`, `auditor-invocation`, `fix-now` or `thoroughness` reference remains | `grep -rn -i "auditor\|report-schema\|auditor-invocation\|fix-now\|thoroughness" workflow/ .agents/ docs/ src/ \| grep -v devlog/handovers` | Agent [x] |
| The maintenance skills report findings inline, with no JSONL, report path, schema or `deferTo` | `grep -rn "JSONL\|report-schema\|deferTo" workflow/coding-agent/skills/roadmap-maintenance workflow/coding-agent/skills/handover-maintenance .agents/skills/project-documentation/runbooks/doc-maintenance` returns nothing | Agent [x] |
| `/milestone-close` no longer names `fix-now`, and `/milestone-start` resolves its axes to `gm.md` | `grep -n "fix-now" workflow/coding-agent/prompts/milestone-close.md`; `grep -n "gm.md" workflow/coding-agent/prompts/milestone-start.md` | Agent [x] |
| The statechart says `/gm` dispatches none and `chk_orientation` is the `/gm` survey | `grep -n "chk_orientation\|/gm" docs/reference/workflow_statechart.md` | Agent [x] |
| The ADR drops `check-in` from the maintenance surface and records the fold | `grep -n "Amended 2026-11-07" docs/adr/coding_agent_project_bindings.md` | Agent [x] |
| The 27 task-list and 9 work-log violation classes are parked in the requirements draft | `grep -c "^\| TL" .agents/drafts/task-list-work-log-violation-requirements.md` is 27; `grep -c "^\| WL"` is 9 | Agent [x] |
| The tree is green | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | Agent [x] |
| The roadmap records the landing | `grep -n "check-in's report contract is cut" devlog/roadmap.md` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Cut the report contract rather than move the schema | no code consumes it, and the only runtime consumer was the thorough path that had no recorded use; the inline callers never set the report path the skills referred to | this handover |
| Fold the light check-in into `/gm` | one procedure and one command; removes the dispatch indirection, the duplicate convention block, and the retired skill directory | this handover |
| Scrub `auditor` and `fix-now` | the role noun described a dispatch no path uses, and `fix-now` had one live reference in `/milestone-close` whose skill never defines the word | this handover |
| Park the violation classes in `.agents/drafts/` | each class is a requirement for the task-list and work-log redesign, not a live procedure to run now | this handover; the requirements draft |
| Keep the check-in's single `chore:` commit authority | the operator scoped this change to the report contract; the determinable-record-fix rule is otherwise unchanged | `gm.md` `## Scope` |
| Amend the ADR rather than rewrite it silently | the maintenance-surface decision dropped one surface, which is a decision change a reviewer must see | `docs/adr/coding_agent_project_bindings.md` |

## Decisions pending

None.

## Findings

None.

## Completed

| File | Change |
|---|---|
| [`workflow/coding-agent/prompts/gm.md`](../../../workflow/coding-agent/prompts/gm.md) | folded the light check-in procedure in; removed the report contract and the duplicate convention block |
| [`workflow/coding-agent/skills/check-in/SKILL.md`](../../../workflow/coding-agent/skills/check-in/SKILL.md) | deleted |
| [`workflow/coding-agent/skills/check-in/auditor-invocation.md`](../../../workflow/coding-agent/skills/check-in/auditor-invocation.md) | deleted |
| [`workflow/coding-agent/skills/check-in/report-schema.md`](../../../workflow/coding-agent/skills/check-in/report-schema.md) | deleted |
| [`workflow/coding-agent/skills/roadmap-maintenance/SKILL.md`](../../../workflow/coding-agent/skills/roadmap-maintenance/SKILL.md) | findings reported inline; recommendation vocabulary removed |
| [`workflow/coding-agent/skills/handover-maintenance/SKILL.md`](../../../workflow/coding-agent/skills/handover-maintenance/SKILL.md) | findings reported inline; caller wording |
| [`workflow/coding-agent/skills/handover-maintenance/runbooks/chain.md`](../../../workflow/coding-agent/skills/handover-maintenance/runbooks/chain.md) | findings reported inline; retired caller removed |
| [`workflow/coding-agent/skills/handover-maintenance/runbooks/content.md`](../../../workflow/coding-agent/skills/handover-maintenance/runbooks/content.md) | caller wording |
| [`.agents/skills/project-documentation/runbooks/doc-maintenance/SKILL.md`](../../../.agents/skills/project-documentation/runbooks/doc-maintenance/SKILL.md) | findings reported inline; schema failure mode removed |
| [`workflow/coding-agent/prompts/milestone-close.md`](../../../workflow/coding-agent/prompts/milestone-close.md) | `fix-now` reference reworded |
| [`workflow/coding-agent/prompts/milestone-start.md`](../../../workflow/coding-agent/prompts/milestone-start.md) | axes resolve to `gm.md` |
| [`src/reasoning/agent/skills/propagation-check/SKILL.md`](../../../src/reasoning/agent/skills/propagation-check/SKILL.md) | `fix-now` reworded to plain English |
| [`docs/reference/workflow_statechart.md`](../../../docs/reference/workflow_statechart.md) | `/gm` dispatches none; `chk_orientation` is the `/gm` survey |
| [`docs/adr/coding_agent_project_bindings.md`](../../../docs/adr/coding_agent_project_bindings.md) | maintenance surface and protocol references updated; dated amendment |
| [`devlog/roadmap.md`](../../roadmap.md) | landing row; stale `check-in` reference genericized |
| [`.agents/drafts/task-list-work-log-violation-requirements.md`](../../../.agents/drafts/task-list-work-log-violation-requirements.md) | new requirements register for the task-list and work-log redesign |
