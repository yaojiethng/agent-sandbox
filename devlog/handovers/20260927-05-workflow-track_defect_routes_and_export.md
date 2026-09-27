# Agent Handover

**Date:** 2026-09-27
**Milestone:** M3 - Autonomous Task Execution, Manual Review Workflow
**Type:** Workflow
**Status:** Active

## Objective

Give the two templates the operator asked for -- a route for a return the primary's verification rejects, and an export step that keeps a track's commits from dying with the container -- and file the two follow-ups the trial produced as roadmap rows.

## Scope

Two units of work, both narrow and both named by the operator against the findings of iteration `20260927-04`:

| Unit | Work | Type | Files owned |
|---|---|---|---|
| 1 | `auto.md` gains the route for a rejected return; `parallel-auto.md` gains the export step | `workflow` | `workflow/coding-agent/prompts/auto.md`, `workflow/coding-agent/prompts/parallel-auto.md` |
| 2 | The duplicate test name check and the owned-file-set derivation become roadmap rows; the records that referenced them as loose follow-ups are written back | `plan` | `devlog/roadmap.md`, `devlog/AGENT_FEEDBACK.md`, `devlog/discussions/20260927-design-draft-parallel_auto_experiment.md` |

The duplicate-registration check in `scripts/check_test_liveness.sh` was proposed for implementation in the previous handover and the operator directed it to the roadmap instead. The unit-count shape of the track-branch consolidation is settled by operator direction (three units: CLI strictness, host requirements, policy text) but not performed here; the branches and their exported bundles are the input to that later iteration.

## Carried forward

| Item | From handover |
|---|---|
| Consolidate and merge `exp/track-a` and `exp/track-b` into the main branch | `20260927-04-workflow-parallel_auto_experiment` |
| Vary the model across tracks to compare yield per unit | `20260927-04-workflow-parallel_auto_experiment` |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | `auto.md`'s Step 4 route table has a row for a return the primary's verification rejects, and the repair paragraph points at it | read the table and the paragraph | pending |
| AC2 | `auto.md`'s invariants carry the rule that a rejected return goes back to its own unit rather than into the primary's tree | read the invariants | pending |
| AC3 | `parallel-auto.md` carries the export step: the rule that a track's commits are reachable only from the container repository, the `package_branch` worktree refusal, and a recipe that works | read the step; the recipe is the one used in the previous iteration | pending |
| AC4 | `devlog/roadmap.md` carries a row for the duplicate test name check and a row for the owned-file-set derivation, each naming its evidence | `grep -n` the two subjects in the roadmap | pending |
| AC5 | The existing scope-to-unit row names the `parallel-auto` draft and records that the unit-split question is open | read the row | pending |
| AC6 | Paired negative check: no record still describes either follow-up as an unfiled item. `grep -rn` the two subjects across `devlog/` names only the roadmap rows, the design record and the feedback entries | the grep | pending |
| AC7 | The design record's follow-up table reflects the disposition of its items | read the table | pending |
| AC8 | Lint gate clean, 0 findings | `bash scripts/lint.sh` | pending |
| AC9 | Handover committed with the delivery commits, Status Closed | `git log` | pending |

## Hot files

| File | Why in scope |
|---|---|
| `workflow/coding-agent/prompts/auto.md` | unit 1 |
| `workflow/coding-agent/prompts/parallel-auto.md` | unit 1 |
| `devlog/roadmap.md` | unit 2 |
| `devlog/AGENT_FEEDBACK.md` | unit 2, `scoped:` fields |
| `devlog/discussions/20260927-design-draft-parallel_auto_experiment.md` | unit 2, follow-up table |
| `devlog/handovers/20260927-05-workflow-track_defect_routes_and_export.md` | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The registration-gate fix is a roadmap row, not an iteration | operator direction; a new gate rule belongs in its own iteration with its own negative test | this handover |
| Two units, two commits | operator direction that this work is a bundle of tasks rather than a scoped milestone iteration; the two units own disjoint files and have different commit types | this handover |
| The consolidation stays three units, performed later | operator confirmed the shape; the branches and their exported bundles are its input | the previous handover, the exported bundles |
| The `parallel-auto` export step documents the `package_branch` worktree refusal and a working recipe | a template that carries the refusal without the workaround sends the next run at the same wall | this handover |

## Findings

| Finding | Type | Impact | Triage |
|---|---|---|---|
| None yet | | | |

## Completed

| File | Change |
|---|---|
| `devlog/handovers/20260927-05-workflow-track_defect_routes_and_export.md` | this handover |

## Deferred items

| Item | Why deferred | Where it goes |
|---|---|---|
| Consolidate and merge the two track branches | operator direction: a later iteration, and the merge is the `/merge` feedback case | the roadmap's parallel-track rows, once filed |
| Whether a subagent can propose a work-unit split | the trial never asked one to; the question needs a run that asks | recorded on the roadmap's scope-to-unit row |
| Measure the concurrent-track ceiling on a host smaller than sixteen cores | needs a host and a run | this design record's follow-up table |

## What's Next

M3. Two template changes and two filed rows.
