---
date: 2026-11-06
milestone: M3.5.3 - The unified record layer
type: Workflow
status: Closed
---

# Handover - The parallel-milestone rule

## Objective

Delete the active-milestone frontmatter and derive the active set from the Milestone Summary table, so more than one milestone can be active with one source of truth.

## Scope

The parallel-milestone rule row of M3.5.3. The Milestone Summary table is the only store of a milestone's activity: every row reading `In progress` is in the active set, and a handover's `milestone` names one of those rows. `active-milestone` and `active-milestone-status` are deleted, not replaced by a set field. The rule is de-coupled from M3.5.2 in the roadmap, because it consumes the work-log seam and the concurrency proof, which have landed, and not the task-list store.

Out of scope, with reasons: the task-list store and its generated view (M3.5.2); the invariant census and the record-shape gate (M3.5.3's next row); the changelog and milestone close; the concurrency proof, which landed in handover `20261106-04`.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No instruction defines, reads or writes `active-milestone` or `active-milestone-status`; only dated history and deletion notes name them | `grep -rn "active-milestone" .agents docs workflow tests devlog/roadmap.md` returns only the seam ADR's rationale and amendment, the draft's past-tense premise, and the roadmap's history and landing note | Agent [x] |
| The active set is defined once in `task-list` as the summary table's `In progress` rows, and a handover's `milestone` names a member | read the `task-list` state and identifier rules | Agent [x] |
| The reading runbooks read the set from the table and the writing runbooks write no field | `grep -rn "active-milestone" workflow/` returns nothing; the reads name the summary table | Agent [x] |
| `ms_active` reads one or more and the statechart gate is clean | `bash scripts/check_statechart.sh` | Agent [x] |
| The loop ADR and the seam ADR are amended for the derived set and the deleted scalar | read `docs/adr/coding_agent_loop_workflow.md` and `docs/adr/work_log_record_seam.md` | Agent [x] |
| The roadmap de-couples this rule from M3.5.2 and corrects its stale field text | `git diff <base> -- devlog/roadmap.md` | Agent [x] |
| The parallel-milestone row closes with its landing note | `grep -n "parallel-milestone rule" devlog/roadmap.md` | Agent [x] |
| The statechart and the two ADRs describe the system as built | read the three documents against the tree | Agent [x] |
| Every decision this iteration recorded is realized in the files | the Decisions table read against `git diff` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Delete `active-milestone` and `active-milestone-status`; derive the set from the summary table | the table already stores the status and already shows several `In progress` rows while the scalar names one; a set field would be a second home | `task-list` and this record |
| The active set is every milestone row reading `In progress`, parents included | the table is the view a reader already opens; a handover may name a parent for cross-cutting work | `task-list` and this record |
| De-couple this rule from M3.5.2 in the roadmap | the rule consumes the work-log seam and the proof, not the task-list store | `devlog/roadmap.md` and this record |
| Amend the two ADRs in place; the seam ADR records that its scalar serializer was deleted | the decision-records convention keeps a current ADR current | `docs/adr/` and this record |

## Decisions pending

None.

## Findings

None.

## Completed

| File | Change |
|---|---|
| `.agents/skills/task-list/SKILL.md` | deleted the frontmatter rule; the active set is the summary table's `In progress` rows; the `active` state and identifier rule follow |
| `docs/reference/iteration_protocol.md` | added the derived-active-set invariant; no serialization rule remains |
| `workflow/coding-agent/prompts/milestone-start.md`, `workflow/coding-agent/prompts/milestone-close.md` | read the summary table; dropped both frontmatter writes |
| `workflow/coding-agent/skills/check-in/SKILL.md`, `workflow/coding-agent/prompts/bootstrap.md`, `workflow/coding-agent/prompts/backlog-triage.md` | read the active set from the summary table |
| `docs/reference/workflow_statechart.md` | `ms_active` reads one or more, the summary table's rows |
| `docs/adr/coding_agent_loop_workflow.md`, `docs/adr/work_log_record_seam.md` | amended the model; the seam ADR records the scalar's deletion |
| `devlog/roadmap.md` | removed the frontmatter block; de-coupled the rule from M3.5.2; corrected the stale scalar text and the closed row; closed the parallel-milestone row |
| `tests/test_parallel_records.sh` | dropped the fixture frontmatter |
| `.agents/drafts/task-list-mechanism-rewrite-run.md` | the premise is past tense; the field was deleted |
| `devlog/handovers/M3.5.3/20261106-05-workflow-parallel_milestone_rule.md` | this record |

Roadmap-maintenance run over `devlog/roadmap.md` and the handover content runbook over this record: 0 findings.
