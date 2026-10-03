# Agent Handover

**Date:** 2026-09-27
**Milestone:** M3 - Autonomous Task Execution, Manual Review Workflow
**Type:** Plan
**Status:** Closed

## Objective

Assess every T1 task for staleness across the policy-to-workflow seam, write back the verdicts, and propose two sub-milestones: M3.2.1 - Loops as Workflows (move the major and minor loops out of policy into workflows, T1 row 79 as the core task) and M3.2.2 - Audit and Review Workflow Cleanup (organize the stray audit and review-pass files into proper workflows). The assessment found two stale rows (71, 72), six rows on the loops seam (73, 77, 78, 79, 82, 83), and four rows in the audit-and-review family (84, 92, 93, 94).

## Scope

| Site | Change | Status |
|---|---|---|
| `devlog/roadmap.md` | the M3.2.1 section with the sequenced task checklist and the acceptance-criteria block; the M3.2.2 section with objective and scope paragraph; the summary table rows; the T1 write-backs | pending |
| `devlog/AGENT_FEEDBACK.md` | the [O] 2026-09-22 questionnaire entry flips to probation: its fix landed (row 96, `e775af2`) | pending |
| `devlog/handovers/archive/20260927-10-plan-m3_2_loops_to_workflows.md` | this handover | pending |

## Hot Files

| File | Why |
|---|---|
| `devlog/roadmap.md` | the T1 task list; the M3.2.1 and M3.2.2 sections land here |
| `devlog/AGENT_FEEDBACK.md` | the questionnaire entry's state flip |
| `workflow/coding-agent/prompts/milestone-close-run.md` | the existing close-arm runbook the move adopts |
| `docs/operations/iteration_policy.md` | the minor-loop procedure the /iter workflow will carry |
| `docs/operations/milestone_policy.md` | the major-loop rule side the move must not duplicate |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Row 71 is stale: `auto.md` and `parallel-auto.md` own the headless-run lifecycle and the unit brief format, and the roadmap-as-task-source ruling supersedes the row's framing | staleness | closing the row leaves `autonomous_task.md`'s "The format and content of `TASK.md` are defined in M3" with no artifact behind it; the disposition is owned by T1's stale-artifact-processing row |
| Row 72 is stale: `milestone-close-run.md` is the close-arm runbook the row wanted `make close-milestone` to become; the mechanism decision is runbook over make target | staleness | the make-target arm is consciously not taken; the close note records that |
| Row 79 carries two sub-rows absent from the chat assessment: separating the new-iteration workflow into `workflows/`, and authoring the `new-iteration` prompt surface plus the major-loop prompts | inventory defect | both moved verbatim with the row into M3.2.1's checklist |
| M3.2.2 is non-active, so its record shape allows no task checklist; the four audit-and-review rows are carried as prose sentences inside the scope paragraph, checkboxes removed | record shape | the full work content survives in the paragraph and its linked records; the rows move into a checklist when M3.2.2 activates |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | The M3.2.1 section carries the sequenced task checklist and the acceptance-criteria block; M3.2.2 carries the objective and scope paragraph; both appear in the summary table, indented under M3 | read `devlog/roadmap.md` | Agent [x] accepted: both sections landed; summary rows at the M3.1 indentation level |
| AC2 | Rows 71 and 72 carry landed notes naming the covering artifacts, and are `[x]` | read the rows | Agent [x] accepted: superseded by the operator's replacement ruling -- the rows are gone and their landing notes live in the artifact-processing task that replaced them |
| AC3 | The six seam rows move into M3.2.1's checklist and the four audit-and-review rows into M3.2.2's scope paragraph, with no row lost and T1 holding only the off-seam rows | count the moved rows against T1 | Agent [x] accepted: six rows plus row 79's two sub-rows in M3.2.1; the four rows' content in M3.2.2's paragraph; T1 holds the artifact task and the off-seam rows |
| AC4 | The questionnaire feedback entry carries `state: probation` with the landing cited | read the entry | Agent [x] accepted |
| AC5 | Lint clean, suite green | `lint.sh`, `run_tests.sh` | Agent [x] accepted: lint clean across 3 gates, 1001 passed, 0 failed, 0 skipped |
| AC6 | One commit; handover committed with `Status: Closed` | `git log` | pending |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| M3.2.1 and M3.2.2 are M3's next sub-milestones, with no M3.2 umbrella section | the operator's numbering, taken literally; fractal numbering nests arbitrarily | `roadmap.md`, summary table |
| The stale framing rows are replaced, not merely closed: the entries become one artifact-processing task naming the documents, each to be refreshed or removed | the operator's ruling: the tasks' documents are artifacts that would otherwise dangle | `roadmap.md`, T1 |
| The review-pass rows carry as prose, not checkboxes, until M3.2.2 activates | the non-active sub-milestone record shape forbids a task checklist | `roadmap.md`, M3.2.2 |

## Completed

None.

## What's Next

M3.2.1's first iteration is the ADR (workflows carry the procedure, policy carries the rules), the named prefactor of the move.
