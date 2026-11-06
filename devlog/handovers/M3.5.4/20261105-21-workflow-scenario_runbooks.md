---
date: 2026-11-05
milestone: M3.5.4 - The git and change model
type: Workflow
status: Closed
---

# Handover - Merge and rebase enter by scenario, not by role

## Objective

Replace the role identity in `/merge` and `/rebase` with a checkable scenario, and name the unit a **merge request**: the branch opens it, the trunk merges or refuses it.

## Scope

The two prompts, the runbook table in `git-discipline`, and the role words in the change-flow design record. The role words are dropped; the scenario is a predicate over the repo.

Out of scope, with reasons: the command names, which stay `/merge` and `/rebase`; the recovery reference, which is the "leave recovery" row; the method, which is still delegated.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Each runbook opens with a scenario | the `## The scenario` section | Agent [x] |
| The scenario is a set of git checks, not an identity | the checks name `rev-parse`, `merge-base`, `log`, `status` | Agent [x] |
| A failed check stops the runbook | the section says stop and ask | Agent [x] |
| No role words remain | no `author` or `integrator` in the two prompts or the table | Agent [x] |
| The gates are clean | `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The entry is a scenario, not a role | "am I an author?" has no repository answer; a state predicate does, and it is cheap to check | this record |
| The unit is a merge request; the branch opens it and the trunk merges it | forge vocabulary replaces the marketplace words "offer" and "accept"; the terminal state is `merged` | this record |
| The checks are the gate, not a preamble | a check that fails closes the runbook before it edits anything | the two prompts |
| The command names stay `/merge` and `/rebase` | they are the git verbs the operator invokes; the scenario is the entry, the name is the command | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| A role identity invites a self-assessment the repo cannot confirm | defect | the agent can loop on "am I an author?" instead of reading the branch state | fixed: the scenario checks |
| The role words leaked into the design record and the runbook table | defect | two vocabularies for one thing | fixed in this unit |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/merge.md` | the merge scenario and its four checks |
| `workflow/coding-agent/prompts/rebase.md` | the merge-request scenario, its two checks, and the rebase condition |
| `.agents/skills/git-discipline/SKILL.md` | the runbook table names the scenario |
| `devlog/discussions/20261105-design-open-change_flow.md` | the role words are gone |
| `devlog/roadmap.md` | the model row uses the scenario language |
| `devlog/handovers/M3.5.4/20261105-21-workflow-scenario_runbooks.md` | this record |
