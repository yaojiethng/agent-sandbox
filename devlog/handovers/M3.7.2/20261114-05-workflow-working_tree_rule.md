---
date: 2026-11-14
milestone: M3.7.2 - The change model and its refinements
type: Workflow
status: Closed
---

# Handover - The working tree has its rule

## Objective

State the boundary the commit history commons rests on: the working tree is the session's uncommitted work, and no git command discards it as a side effect.

## Scope

Continues the parent row *The convention leads from history as a commons and owns the primitives* in M3.7.2, from [`20261114-04`](20261114-04-workflow-message_budgets.md).

One row: *The working tree has its rule*. The convention has no working-tree section at all -- the ADR names the boundary and the convention never states it. Two occurrences supply the rule: [`AGENT_FEEDBACK.md`](../../AGENT_FEEDBACK.md) `[A] 2026-08-10`, a `git restore` that reverted a session's refactor, and its recurrence recorded in [`.agents/drafts/precommit-gate-runbook.md`](../../../.agents/drafts/precommit-gate-runbook.md), a `git checkout` that silently dropped a lint rule.

Out of scope: any change to the container's git configuration or to `guards.sh`'s stash advice, which is recoverable and not in the discarding class.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The convention states the rule: the four-step discard and the copy-aside for a mutation. | Read `## The working tree`. | Agent [x] |
| The ADR names both occurrences: 2026-08-10 and the precommit-gate recurrence. | `grep -c 'markdownlint-cli2' docs/adr/git_commit_history_commons.md` returns 1 | Agent [x] |
| The ADR records the boundary decision and the rejected enforcement arm. | `grep -c 'a gate over' docs/adr/git_commit_history_commons.md` returns 1 | Agent [x] |
| The 2026-08-10 entry reads `state: mitigated` and names this handover. | `grep -A4 '2026-08-10' devlog/AGENT_FEEDBACK.md` | Agent [x] |
| One statement per layer: the verb list lives in the convention, the why in the ADR. | `grep -c 'git clean -f'` is 1 in the convention and 0 in the ADR | Agent [x] |
| The roadmap row closes with its outcome. | `git diff HEAD -- devlog/roadmap.md` at pre-close | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The rule covers the discarding class only: `restore`, `checkout -- <path>`, `clean -f`, `reset --hard`, `stash drop`. | `stash push` saves the work and is recoverable, so a rule that named plain `stash` would forbid the safe path. | the convention |
| The required method for undoing the session's own mutation is a temp copy, not git. | The two occurrences were both reverts of a deliberate mutation; git restored HEAD over work the operation did not create. | the convention |
| The inspection is two commands the rule carries, not advice to be careful. | `git status --porcelain -- <path>` and `git diff -- <path>` show whether the discard would take work this operation did not make. | the convention |
| The rule's mechanism is the record alone, and a gate is rejected. | A gate can read a script's text but not an agent's intent, and the one greppable form appears legitimately in fixture repositories. | the ADR entry |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The occurrence has a second record the feedback entry does not name: the precommit-gate draft's `git checkout` dropped a lint rule from the config. | record | the rule's evidence is two cases, not one | the convention and the ADR |
| `scripts/guards.sh` advises `git stash` when the tree is dirty. | record | in the discarding class only under `stash drop`; the advice is recoverable, so it stands | no change |
| The convention's rule must carry no case history, so the occurrences live in the ADR and the AC was revised to check there. | record | the convention stays the verbs, the ADR the why | this iteration |
| The ADR's first draft repeated the five verbs, so the convention was not their single source. | record | two statements of one list | removed from the ADR |

## Completed

| File | One-line change summary |
|---|---|
| `.agents/skills/git-discipline/SKILL.md` | the `## The working tree` section: the four-step discard, the five verbs, the copy-aside |
| `docs/adr/git_commit_history_commons.md` | the boundary entry: the two occurrences, the rejected gate and wrapper |
| `devlog/AGENT_FEEDBACK.md` | 2026-08-10 reads `mitigated`; the recurrence recorded on it |
| `devlog/roadmap.md` | the row closes, compacted |
| (maintenance) | `roadmap-maintenance`: 0 findings; the budgets row compacted last iteration, and no closed row carries open work. |
