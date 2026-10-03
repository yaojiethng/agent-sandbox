# Agent Handover

**Date:** 2026-09-29
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Workflow
**Status:** Closed

## Objective

Build the shared `/wrapup` close runbook (roadmap row 84, Option 1): the consolidated close for the active-operator prompts `/iter`, `/plan` and `/document`, covering the steps no other prompt owns -- close the handover, land the single commit, write back the roadmap task and its parent, run compaction, and close ADRs and discussion docs whose work landed.

## Scope

`/wrapup` is the consolidated close for the **active-operator-participation** prompts: `/plan`, `/iter`, `/document`. They route their close through one shared `/wrapup` (one rule one owner).

- `workflow/coding-agent/prompts/wrapup.md` -- grow the stub into the full shared close runbook: the close sequence (AC verification, propagation replay, scope reconciliation, roadmap write-back and compaction, carry-forward resolution, findings review/publish, closing ADRs and discussion docs, seed-next, single-commit landing), and the shared-invocation contract. The commit-discipline checkpoint stays as the recurring in-iteration half.
- `workflow/coding-agent/prompts/iter.md` -- replace the duplicated Steps 8-9 close procedure with an invocation of one shared `/wrapup`; keep the iteration gates (Step 7 / Gate 3) and link to `/wrapup`. Remove only the close steps the shared runbook owns.
- `workflow/coding-agent/prompts/plan.md` -- route its post-confirmation close (write-back + close) to one `/wrapup`.
- `workflow/coding-agent/prompts/document.md` -- route its close to `/wrapup` in the design; the document stub's formalization stays its own roadmap task.

Out of scope: `milestone-start` (milestone-record close, distinct from `/wrapup`'s iteration close), `auto` and `parallel-auto` (their acceptance substitutes for the operator gate), M3.2.2 (audit/review workflow cleanup), the disposal-bound skill files, the `/iter` gate collapse (roadmap row 83, separate).

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `/wrapup` is the consolidated close for the active-operator prompts `/iter`, `/plan` and `/document` only | `milestone-start` records the milestone (`/milestone-close` owns it); `auto`/`parallel-auto` substitute an autonomous review for the operator gate | roadmap row 84 landing note, operator scoping 2026-09-29 |
| `/iter` keeps its gates (Step 7, Gate 3) and routes only the mechanical Steps 8-9 close to `/wrapup` | the gates judge the work; the close runs it | `iter.md` Steps 8-9 |
| `plan` and `document` route their close to `/wrapup` but have no delivery commit in the `/iter` sense | a planning/docs session lands record-bearing commits, still one commit per unit | `plan.md` `## Close` |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | `/wrapup` is the one owner of the close; `/iter`, `/plan`, `/document` route to it and carry no duplicated close sequence | read the prompts; `milestone-start`, `auto`, `parallel-auto` name no `/wrapup` | Met |
| 2 | `/wrapup` covers closing ADRs and discussion docs whose work landed (step B7) | read `/wrapup` | Met |
| 3 | The single-commit close (one delivery commit carrying work + handover + write-back) stays home in `/wrapup` (B4, B8) | read `/wrapup`, `git_policy.md` cross-check | Met |
| 4 | `iteration_policy.md` Steps 8-9 keep the rules and name `/wrapup` the step owner; the loop-workflow ADR records `/wrapup` | read both | Met |
| 5 | roadmap row 84 marked landed with the active-operator scoping | roadmap row 84 | Met |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/wrapup.md` | consolidated close runbook: commit-discipline checkpoint (Part A) + shared close (Part B) + routing + failure modes |
| `workflow/coding-agent/prompts/iter.md` | Steps 8-9 route to `/wrapup` Part B; gates stay |
| `workflow/coding-agent/prompts/plan.md` | close routes to `/wrapup` after plan confirmation |
| `workflow/coding-agent/prompts/document.md` | infodump records the `/wrapup` close routing |
| `docs/operations/iteration_policy.md` | Steps 8-9 name `/wrapup` as step owner |
| `docs/adr/coding_agent_loop_workflow.md` | records `/wrapup` as a shared close runbook |
| `devlog/roadmap.md` | row 84 landed, active-operator scoping recorded |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The roadmap row's premise was that `/iter`, `/plan` and `/milestone-start` each carried a duplicated close; in the current tree only `/iter` held the Steps 8-9 close, and `plan`/`milestone-start` ended at write-back/promote | context | The dedup is prevention, not removal of three copies; scoped the routing to the active-operator prompts that end in a unit close |
| `milestone-start`, `auto`, `parallel-auto` must not invoke `/wrapup`: the first records the milestone, and the auto runs replace the operator gate with an autonomous review | scope | Binds which prompts route; recorded in ADR and roadmap row 84 |

## Deferred items

- The `/iter` gate collapse and per-prompt quality pass (roadmap row 83) -- the over-pausing finding is recorded there; `/iter` now routes its close to `/wrapup` but its gates are unchanged this iteration.
- `auto`/`parallel-auto` acceptance-substitution for `/wrapup` -- roadmap row `/auto` bypasses the two operator-acceptance points; settled when that row lands.
- `/document` formalization -- its stub carries the close routing; the formal runbook is its own roadmap task.

## What's Next

- `/iter` gate collapse and per-prompt quality pass (roadmap row 83) is the natural next task: it owns the over-pausing finding and now builds on `/wrapup`.
- The adversarial novel-bug review and class-scoped collateral hunters stay open as review-policy follow-ups.
- Roadmap-future rows 47 (regular mutation-run frequency) and 48 (2026-09-26 mutation survivors) are queued.
