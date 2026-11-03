---
date: 2026-11-03
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - the filing default is gone, and the agent proposes instead

## Objective

Remove the rule that filed every escalated item into the active sub-milestone, so a row lands where the agent proposes and the operator decides.

## Scope

In scope: the convention's `**Roadmap task placement**` rule, the check that enforced it, the close step that named the destination, and the one row filed under the old rule.

Out of scope: the rows already filed under it, which the operator placed as they stand.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The convention states a proposal, not a default | `grep -n 'Roadmap task placement' .agents/skills/task-list/SKILL.md` | Agent [x] |
| The check follows it | `roadmap-maintenance` 3.10 names the owning subject and the operator's direction | Agent [x] |
| The close step asks for the proposal | `grep -n 'proposes the destination milestone' workflow/coding-agent/prompts/milestone-close.md` | Agent [x] |
| The hook-abort row is filed by subject | it sits in M3.4.2, Environment declaration seam | Agent [x] |
| `bash scripts/lint.sh` is clean | twenty gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The agent proposes and the operator decides | The old default filed by recency rather than by subject, so a row could sit a milestone away from the objective that owns it and no reader could tell a considered placement from a defaulted one | `task-list` convention, Filing rules |
| The hook-abort row goes to M3.4.2 | The provider setup hook is a pre-compose environment step, and M3.3.3's objective is the skill pipeline | `devlog/roadmap.md` |

## Decisions pending

None.

## Findings

- `devlog/AGENT_FEEDBACK.md:404` still tells an agent to read the placement rule before filing. It now reads correctly as a proposal step, so no entry changes.

## Completed

| File | Change |
|---|---|
| `.agents/skills/task-list/SKILL.md` | the placement rule states the proposal and the operator's decision |
| `workflow/coding-agent/skills/roadmap-maintenance/SKILL.md` | 3.10 checks subject ownership and the operator's direction |
| `workflow/coding-agent/prompts/milestone-close.md` | the agent proposes the destination |
| `devlog/roadmap.md` | the hook-abort row moves to M3.4.2 |
