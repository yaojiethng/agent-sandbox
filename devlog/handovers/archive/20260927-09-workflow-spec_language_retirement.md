# Agent Handover

**Date:** 2026-09-27
**Milestone:** M3 - Autonomous Task Execution, Manual Review Workflow
**Type:** Workflow
**Status:** Closed

## Objective

Retire the dead word "spec" from live policy and instruction vocabulary, and name what each surviving use means in practice: an implementation plan, an agreed design, or a narrowed task requirement as recorded in the roadmap (operator ruling, 2026-09-27). The handover type `spec` is already deprecated and folded into `design`; the word survives only in prose. Boundary: language only -- mechanism changes to how roadmap entries are recorded belong to the Roadmap-mechanism rewrite study.

## Scope

The word "spec" is retired from live policy and instruction vocabulary. Each use names its artifact: the confirmed scope, the agreed design, the per-step implementation plan, the specification of a criterion, or the requirements read from the roadmap task. No new umbrella word is introduced. Exclusions: the usage spec in `command_flag_parsing.md`, the Symphony-spec study row, the deprecated-type rows that name `spec` as retired vocabulary, and all closed records.

| Site | Change | Status |
|---|---|---|
| `docs/operations/iteration_policy.md` | 21 uses swapped: the Principles confirmations, the Step 4 reading list, the minor-loop and Gate 2 rows, the amendment rule | done |
| `AGENTS.md` | the Development bullet reads "The design proposal is the agreement" | done |
| `workflow/coding-agent/audits/handover-audit.skill.md` | the audit speaks of the handover's design sections; the category renamed Design-to-source integrity | done |
| `docs/concepts/autonomous_task.md` | the two stage lists read scope, design | done |
| `docs/architecture/system_overview.md` | the security sentence names requirements; `security.md` and `threat_model_stride.md` use the word zero times, so no artifact is orphaned | done |

## Carried forward

| Item | From handover |
|---|---|
| Define where the spec lives, or retire the word | `20260927-08-workflow-unit_boundary_proposal_and_commit_granularity` |

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | Whole-word `spec` has zero remaining uses in live policy, instruction, concept and architecture files, outside the named exclusions | the negative grep | Agent [x] accepted: 33 uses retired across five files, zero remaining; repo-wide, only `well-specifiedness` and the load-bearing exclusions remain |
| AC2 | Every replacement names one of the meanings settled at Gate 2, and no umbrella word is introduced | read the swap table | Agent [x] accepted: confirmed scope, agreed design, implementation plan, a criterion's specification, or the roadmap task, per site |
| AC3 | No mechanism change: the diff touches prose lines only | read the diff | Agent [x] accepted: 25 insertions, 25 deletions, five files, prose lines only |
| AC4 | Closed records unchanged: handovers, discussions and ADRs other than the flagged ADR check | `git diff --name-only` | Agent [x] accepted: the diff names the five live files only |
| AC5 | Lint clean, suite green | `lint.sh`, `run_tests.sh` | Agent [x] accepted: lint clean across 3 gates, 1001 passed, 0 failed, 0 skipped |
| AC6 | One commit; handover committed with `Status: Closed` | `git log` | Agent [x] accepted: the delivery commit carrying this handover is the iteration's only commit, and it carries this handover with Status Closed |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/operations/iteration_policy.md`](../../docs/operations/iteration_policy.md) | the primary surface: "Confirm the spec", "fixed at spec time", the Step 4 reading order, "spec gaps", "Spec amendment" |
| [`AGENTS.md`](../../AGENTS.md) | the Development mode bullet says "The design proposal is the spec" |
| [`workflow/coding-agent/audits/handover-audit.skill.md`](../../workflow/coding-agent/audits/handover-audit.skill.md) | the Gate 2 audit rules are phrased against "a spec" |
| [`docs/concepts/autonomous_task.md`](../../docs/concepts/autonomous_task.md) | two whole-word uses, full sentences to read at Step 4 |
| [`docs/architecture/system_overview.md`](../../docs/architecture/system_overview.md) | one whole-word use, full sentence to read at Step 4 |
| [`docs/adr/command_flag_parsing.md`](../../docs/adr/command_flag_parsing.md) | check only: there "spec" names the usage spec, a real artifact; likely out of scope |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| No new umbrella word; each use names its artifact | the operator's ruling: colloquially the meanings collapse to "requirements", and sharpening beats a catch-all for agent consumption | this handover, Scope |
| The Step 4 reading list reads the roadmap task first | the roadmap is the single source for task definition; elaborations link from it or from documents it links | `iteration_policy.md` Step 4 |
| "spec bug" becomes "specification bug" | the defect is in the written statement of the requirement, not in the boundary; the specification stem stays where the act of specifying is meant, as with "unspecified behaviour" and "well-specifiedness" | `iteration_policy.md` Gate 2 |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The inventory undercounted: six uses, in the documentation principle, the minor-loop stage list, the Step 2 row and the Gate 2 and steering passages, were absent from the released swap table | inventory defect | the negative grep demanded by AC1 caught them at implementation; the swaps follow the already-released meaning classes, so no new decision was needed |

## Completed

| File | Change |
|---|---|
| `docs/operations/iteration_policy.md` | 21 uses swapped per the released mapping; the specification stem retained where the written requirement is meant |
| `AGENTS.md` | the Development bullet: the design proposal is the agreement |
| `workflow/coding-agent/audits/handover-audit.skill.md` | 8 uses swapped; the audit category renamed |
| `docs/concepts/autonomous_task.md` | 2 stage lists reordered to scope, design |
| `docs/architecture/system_overview.md` | the security sentence names requirements; no standalone spec artifact exists to orphan |
| `devlog/handovers/archive/20260927-09-workflow-spec_language_retirement.md` | this handover |

## Deferred items

None.

## What's Next

The T1 open rows are the candidates for the next iteration: the correction-ownership row and the scope-to-unit row's Open half are adjacent to this milestone's thread; the operator picks. Mechanism changes to how roadmap entries are recorded stay with the Roadmap-mechanism rewrite study.
