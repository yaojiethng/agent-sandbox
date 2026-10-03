# Agent Handover

**Date:** 2026-09-27
**Milestone:** M3 - Autonomous Task Execution, Manual Review Workflow
**Type:** Workflow
**Status:** Closed

## Objective

Write a run brief template at `workflow/coding-agent/prompts/milestone-close-run.md` that captures the milestone-close operation just executed for M3.1, as a reusable main-agent template.

## Scope

Operator direction: "new iteration, type: workflow. In `workflow/coding-agent/prompts/` write a milestone-close prompt template, aiming to capture the operation ... close that you just did". The scope is one new file: `workflow/coding-agent/prompts/milestone-close-run.md`. The milestone name comes from the operator at run time; the template handles a sub-milestone close as the just-run case. Follow the established run-brief conventions (frontmatter `description` + `argument-hint`, invitation pattern, Purpose, Preconditions, Output contract, Close, Invariants). Do not edit the milestone-close policy text itself; the brief invokes and cites it.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | New template file exists at `workflow/coding-agent/prompts/milestone-close-run.md` with frontmatter and `> $@` | `ls` + `head -6` | Agent [x] accepted |
| AC2 | Template mirrors the just-run close sequence: pre-close review gate, compaction, changelog entry, summary table + frontmatter, close commit | read the section list | Agent [x] accepted |
| AC3 | Template cites the policy docs it runs against (`roadmap_policy.md`, `iteration_policy.md`, `handover_policy.md`, `git_policy.md`) with their section names | `grep -n "policy" file` | Agent [x] accepted |
| AC4 | Template carries the durable lessons from the just-run close (review-gate surface, plan-type check, survivors disposition, compaction-stop rule) | read | Agent [x] accepted |
| AC5 | Lint gate clean (0 findings) | `bash scripts/lint.sh` | Agent [x] accepted |
| AC6 | Handover committed with the delivery commit | git log | Agent [x] accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`workflow/coding-agent/prompts/milestone-close-run.md`](../workflow/coding-agent/prompts/milestone-close-run.md) | new template (to be created) |
| `docs/operations/roadmap_policy.md` | compaction and close rules the template runs against (reference) |
| `docs/operations/iteration_policy.md` | pre-close review gate and Steps 8-9 (reference) |
| `docs/operations/handover_policy.md` | close-handover rules (reference) |
| `docs/operations/git_policy.md` | close-commit typing, `plan` type (reference) |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| One new file, no policy edits | the operator scoped the brief only; policy citations keep it honest | this handover |
| Template name `milestone-close-run.md` | consistent with `read-through-run.md`, `churn-analysis-run.md`, `fanout-run.md` | this handover |
| Close-commit type rule: `plan` for a plan-iteration close, else the dominant type | the just-run close used `plan:`; the git-policy Active Types table decides from the diff | this handover |

## Findings

| Finding | Type | Impact | Triage |
|---|---|---|---|
| None | | | |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/milestone-close-run.md` | new main-agent run template: frontmatter + invitation, Purpose, Preconditions, The review gate, The compaction, The changelog entry, The summary table and the frontmatter, Escalation clearance, The close commit, Invariants |
| `devlog/handovers/20260927-03-workflow-milestone_close_template.md` | this handover |

## Deferred items

None.

## Carried forward

None.

## What's Next

M3. The new template is the first milestone-close run brief. It is exercised next time a sub-milestone or milestone closes (M3's T1-T12 tracks or a future sub-milestone); the M3.1 close it captures is the worked precedent. The M4 mutation-frequency and survivor rows ride `roadmap_future.md`.
