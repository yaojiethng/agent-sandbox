---
date: 2026-10-15
milestone: M3.4 - Container Execution Model and Environment Ownership
type: Plan
status: Closed
---

# Handover - M3.4: the container execution model and environment ownership

## Objective

Settle the container-execution model and its reserved vocabulary, then cut M3.4 into sub-milestones that carry the consolidated environment-ownership work, so the shipped harness can support a project's own development environment and self-verification.

## Scope

This plan session shapes M3.4 as a whole. It takes over M3.4 from a partial implementation on another thread, which the operator bundles separately and this session folds in.

In: the domain and plane model, the vocabulary decision, `docs/reference/system_overview.md`, `docs/reference/terminology.md`, the M3.4 sub-milestone decomposition, and the consolidation of the T4, T6, T7, T8, T9, M3.1.2, M7 and W1 rows that the environment-ownership concern owns.

Out: the implementation of any seam, the spread live test, and the fold-in of the other thread's M3.4 bundle, which waits for the operator to hand it over. M3.6 runs on another branch and is not this session's work.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The vocabulary appears in one place with one sense each | `docs/reference/terminology.md` | Agent [x] |
| `system_overview.md` carries the model with a corrected freeze column | the rewritten model section | Agent [x] |
| Every M3.4 sub-milestone maps to one sub-domain and its planes | the M3.4 section in `devlog/roadmap.md` | Agent [x] |
| No consolidated row is duplicated across the two roadmap files | a grep per taken-over term | Agent [x] |
| The operator confirms the ADR and the decomposition | the plan close | Operator (released) |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| M3.4 becomes the canonical milestone and the active one for this session | the scoping is superior to the partial implementation on the other thread; M3.6 runs separately | this handover; `devlog/roadmap.md` |
| M3.6 stays `In progress` in the summary on this branch | the summary already carries several `In progress` rows; only the `active-milestone` scalar is singular, and it names M3.4 here | this handover |
| The other thread's M3.4 bundle folds in at M3.4.1's close | folding against a settled model beats folding against a moving one | this handover |
| The vocabulary is `domain`, `sub-domain` and `plane`, with `layer` reserved for the container architecture | measured collisions: `tier` 37 uses, `boundary` 99, `scope` 355, `context` 197, `plane` 0 | this handover; the ADR to land |
| The milestone runs empirically | a sub-milestone closes on a live `spread` run, not on a document | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| No handover was `Active`, so `/sidequest` did not apply | process, measured | the work routed to `/plan` at milestone scope | this record |
| `system_overview.md`'s layer model is stale and too shallow | defect, measured | its freeze column names M1.5 and M2, both closed, and it has no axis for M3 or the environment contract | this record |
| `tier` collides with the Docker build tiers and the `model-failover` dispatch tiers | defect, measured | 37 uses; the vocabulary cannot reuse the term | the vocabulary gate |
| The capability entrypoint installs a harness pre-commit hook whose handover check calls a harness-repo script | defect, measured | the hook fails on any project but agent-sandbox; the project-hook seam is unfiled | M3.4.6 |
| The `active-milestone` scalar cannot represent two active branches, so parallel work forces the scalar and the summary to disagree | defect, recorded | already known and owned by M3.5 (`devlog/roadmap.md` M3.5, `The scalar already disagrees with the summary table`); this branch is a second instance | M3.5 |
| `docs/reference/agent_workflow.md` uses `layer` for instruction roots, which `coding_agent_project_bindings.md` already reserved for "surface" or "root" | defect, measured | a pre-existing T8 violation, deferred to U1 of the M3.4 brief, not fixed in this commit | M3.5 |

## Completed

| File | Change |
|---|---|
| `docs/adr/container_execution_model.md` | the new ADR for the domain model and the reserved vocabulary |
| `docs/reference/system_overview.md` | the Architecture Layer Model section, rewritten to the domain model |
| `docs/reference/terminology.md` | the `layer`, `domain`, `sub-domain` and `plane` entries |
| `docs/policies/documentation_policy.md` | the freeze sentence and the rewritten anchor |
| `docs/adr/coding_agent_project_bindings.md` | the reserved-terms row, from `tier` to `domain`, `sub-domain`, `plane` |
| `devlog/roadmap.md` | the M3.4 section, summary row, the `active-milestone` move, and the consolidation |
| `devlog/roadmap_future.md` | the M7 superseded note and the W1 portability note |
| `.agents/drafts/m3_4-container_execution_model-run.md` | the brief and the work-unit table |
| `devlog/handovers/20261015-09-plan-m3_4_domain_model_and_scope.md` | this record |
