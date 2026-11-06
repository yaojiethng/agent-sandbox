---
date: 2026-11-05
milestone: M3.5.4 - The git and change model
type: Workflow
status: Closed
---

# Handover - Merge and rebase become the two role runbooks

## Objective

Rewrite `/merge` and `/rebase` as the integrator and author runbooks: intent, inputs, one obligation, a method pointer and a stop, with no step list.

## Scope

`workflow/coding-agent/prompts/merge.md` and `rebase.md`, the runbook table in `git-discipline`, and the role words in the change-flow design record. The method is delegated to the replay and port mechanics already in use; the runbooks no longer restate them.

Out of scope, with reasons: the recovery reference, which still names the two as recovery runbooks and is the "leave recovery" row; the statechart's labels; the `merge` input contract, which is the prompt's input table and is now a branch and a range.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `/merge` acts for the integrator and refuses a stale tree | read the prompt's role and obligation | Agent [x] |
| `/rebase` acts for the author and owns the merge-back | read the prompt's role and obligation | Agent [x] |
| Neither runbook carries a step list | each is intent, inputs, obligation, method pointer, stop, close | Agent [x] |
| The role is named once, and an agent can hold both roles at different moments | the role sections say so | Agent [x] |
| `git-discipline`'s runbook table names the roles | read the table | Agent [x] |
| The gates are clean | `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `author` and `integrator` name the roles; `branch` and `trunk` name the objects | `branch` as a role collides with the git ref, so it would carry two subjects | this record |
| `/merge` is the integrator's accept; `/rebase` is the author's offer | the current `/merge` resolved conflicts, which is the author's job under the model | the two prompts |
| The early slice needs no third runbook | it is a unit with a grain the operator chooses; the same two runbooks carry it | this record |
| The method is delegated, not restated | the replay and port mechanics are in use; a clean step list for an unrun role split would be a guess | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `/merge` assigned conflict resolution to the trunk, so the trunk did the author's work | defect | the role model could not hold: a resolved tree could be re-resolved by the integrator | fixed in the rewrite |
| Both runbooks restated the same conflict and divergence rules | defect | two sources for one rule; a change to one missed the other | fixed: the obligations are stated by role, and the method is cited |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/merge.md` | the integrator's accept: intent, inputs, obligation, method, stop |
| `workflow/coding-agent/prompts/rebase.md` | the author's offer: intent, inputs, obligation, method, stop |
| `.agents/skills/git-discipline/SKILL.md` | the runbook table names the integrator and the author |
| `devlog/discussions/20261105-design-open-change_flow.md` | the role words |
| `devlog/handovers/M3.5.4/20261105-20-workflow-role_runbooks.md` | this record |
