---
date: 2026-10-15
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - the manual work-unit owner

## Objective

Give the decomposition of a task into work units one owner, `/scope`, and give the handoff between prompts one named pattern.

## Scope

The manual half of `devlog/roadmap.md` row `Scope-to-unit decomposition for autonomous runs`. This iteration owns decomposition into work units for a manual, operator-involved run, where `/scope` is invoked directly and the operator is in the loop.

The autonomous half stays out. `sequential-work.md`, `parallel-work.md`, the `/auto` dispatcher and the `/goal` capability keep their own row, their own entry, and their own definition of the autonomous work-unit table. This iteration neither closes nor rescopes them.

Two adjacent items are ruled out of scope. `devlog/roadmap.md` row `Roadmap decision-row format drift` is a distinct subject, decision rows rather than task rows. `devlog/AGENT_FEEDBACK.md` entry `[A] 2026-10-05` is about where a row lands, not its granularity.

The operator released `/scope`'s promotion after the port landed, and the promotion folds in here: the draft moves to the live prompt root, the loop inventory and the policy's `scope` field gain it, and the two prompts that hand it work reach it directly. Four record defects the port introduced fold in with it.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `/scope` carries the work-unit table in its brief shape and claims no roadmap-row writing | `grep -n "work-unit table" workflow/coding-agent/prompts/scope.md` returns the brief row; `/scope` stages no row | Agent [x] |
| `/plan` gives up the unit list and names `/scope` for it | `grep -n "scoped unit at its stated grain" workflow/coding-agent/prompts/plan.md` returns nothing; the file links `scope.md` | Agent [x] |
| `/wrapup` B4 names the unit table as the source of the rows | `grep -n "work-unit table" workflow/coding-agent/prompts/wrapup.md` returns the clause | Agent [x] |
| The handoff pattern has one named home | `grep -n "workflow handoff pattern" docs/development/prompt-authoring-conventions.md` returns the section and the body-order entry | Agent [x] |
| The manual half has its own roadmap row and its own feedback entry, and the autonomous row is unchanged | `grep -n "Scope-to-unit decomposition for autonomous runs" devlog/roadmap.md` shows the parent row text intact; the sibling row is `[x]`; `grep -n "2026-10-15" devlog/AGENT_FEEDBACK.md` finds the entry | Agent [x] |
| `/scope` is live, and the old draft path is gone | `ls workflow/coding-agent/prompts/scope.md` succeeds and `ls .agents/drafts/scope.md` fails | Agent [x] |
| Both routing prompts reach `/scope` | `grep -n "](scope.md)" workflow/coding-agent/prompts/iter.md workflow/coding-agent/prompts/plan.md` returns a link in each | Agent [x] |
| The loop inventory and the policy's `scope` field agree, and both name `/scope` | `bash scripts/check_instruction_surfaces.sh` reports clean; `grep -c "scope" docs/policies/iteration_policy.md AGENTS.md` returns a non-zero count in each | Agent [x] |
| The gate suite is clean | `bash scripts/lint.sh` reports clean across 8 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The manual work-unit table's shape already has one home, in `iteration_policy.md` | on inspection the policy enumerates the manual columns and only the autonomous table points at `sequential-work.md`, so the measured duplication is entirely autonomous-side and out of scope | this record |
| `/scope` stays a prompt, not a skill | a prompt runs at the operator's word and `/scope` is a verb the operator types; a skill would add a layer and change no ownership | this record |
| The handoff pattern is named `workflow handoff pattern` | four prompts already use it and none names it | `prompt-authoring-conventions.md` |
| `/scope` joins the loop inventory | `/iter` and `/plan` both route to it, and the brief it produces is what a run reads, so it is a runbook the loop runs; the policy's `scope` field and the `AGENTS.md` table are the two carriers the instruction-surface gate holds together | `iteration_policy.md`; `AGENTS.md` |
| The manual-half roadmap row closes | the promotion was the row's last open clause, and a live `/scope` makes the owner reachable | `devlog/roadmap.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The manual half's table shape already has one home, so the planned hoist unit dissolved. Triaged to: this record's Decisions table. | scope change | current iteration |
| 87 of 151 open roadmap rows, 58%, name no file at all, against the project's `task-list` convention `**Task granularity**`. Triaged to: `roadmap.md` row `The manual work-unit owner, and the named handoff pattern`, and `AGENT_FEEDBACK.md` entry `[A] 2026-10-15`. | steering | roadmap |
| The port renumbered three handover records, and four references kept the old numbers: `devlog/roadmap.md` cited `20261014-03` for the model-router row and `20261015-01` for the manual-half row, and this record's Completed table cited its own pre-rename filename. The ported record also carried a four-column acceptance-criteria table, where the `work-log` convention fixes three. Triaged to: Completed (all four fixed in this record's amend). | obstacle | current iteration |

## Completed

| File | Change |
|---|---|
| [`workflow/coding-agent/prompts/scope.md`](../../workflow/coding-agent/prompts/scope.md) | the promoted `/scope`: moved live from `.agents/drafts/`, with a `## Project conventions` block and image-path and sibling links |
| [`workflow/coding-agent/prompts/plan.md`](../../workflow/coding-agent/prompts/plan.md) | Write back gives up the unit list and hands the decomposition to `/scope` |
| [`workflow/coding-agent/prompts/wrapup.md`](../../workflow/coding-agent/prompts/wrapup.md) | B4 names the work-unit table as the source of the rows |
| [`docs/development/prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) | names the workflow handoff pattern and adds it to the body order |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | new row for the manual half under M3.3.1; the row closes `[x]`; two dangling handover references repair |
| [`devlog/AGENT_FEEDBACK.md`](../../devlog/AGENT_FEEDBACK.md) | new entry for the manual half, cross-referencing the autonomous entry |
| [`devlog/handovers/20261015-03-workflow-the_manual_work_unit_owner.md`](20261015-03-workflow-the_manual_work_unit_owner.md) | this record |
| [`workflow/coding-agent/prompts/iter.md`](../../workflow/coding-agent/prompts/iter.md) | Step 2 routes a row that is not ready to `/plan`; Step 3 states design precedence against `/plan` |
| [`workflow/coding-agent/prompts/milestone-start.md`](../../workflow/coding-agent/prompts/milestone-start.md) | names `/plan` for the milestone phase's design step |
| [`docs/policies/iteration_policy.md`](../../docs/policies/iteration_policy.md) | the frontmatter `scope` list gains `/scope` |
| [`AGENTS.md`](../../AGENTS.md) | the `### Loop prompts` table gains the `/scope` row |

---

[CORRECTION -- 2026-10-15: the Completed table omitted the consumer end of the pipeline this iteration built. `/iter` Step 2 had a recovery of "ask the operator" and no route, so `/scope` was an owner with no path from the only prompt that discovers an unready row, and `/milestone-start.md` named `/plan` nowhere, leaving the milestone phase's design step with no runbook. Both are folded in here. Finding routed to Completed: both gaps are fixed in this fold, and the direct `/iter` route to `/scope` is a clause on the manual-half roadmap row because it waits on `/scope`'s promotion.]

---
