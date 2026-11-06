---
date: 2026-10-31
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - The grill-me input contract

## Objective

State where the `grill-me` problem summary comes from, so a caller that already holds the goal, the problem and the gathered context is not asked to restate them.

## Scope

Delivers the M3.3.3 row **The `grill-me` input contract is stated**, under the sub-milestone's authoring surface, from the open iteration that closed at handover `20261030-04`.

The skill's `## Problem summary first` section names the three parts and asks for any part that is missing, but it does not say that a session which already recorded the goal, problem and context supplies them. `/plan` passes exactly that context to the interview, and a direct invocation holds the conversation, so the contract changes who supplies the summary rather than whether it exists.

In scope: the skill's input contract and the maintenance record that states the adaptation from the upstream text.

Out of scope, one sentence each with the reason: `/plan` needs no edit because its `## Interview` already passes the recorded goal, problem, gathered context and confirmed scope; the record corrections the check-in flagged are left for operator direction, because the `closed_record_corrections` ADR says corrections to closed records are proposed and not applied unasked; a test for the contract is not built because the skill is prose with no callable seam and the lint gates check its form; and the other M3.3.3 rows stay with their own iterations.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `SKILL.md` states where the three parts come from and that only a part the session lacks is asked for | `rg -n 'session already holds'` and `rg -n 'part the session lacks'` on the skill | Agent [x] |
| The skill states the summary stays required, and a caller with no prior context is asked for all three parts | `rg -n 'required of every session'` and `rg -n 'all three parts'` on the skill | Agent [x] |
| `MAINTENANCE.md` records the adaptation and names the two callers | `rg -n 'where the three parts come from'` on the record; `bash scripts/check_skill_sources.sh` | Agent [x] |
| The roadmap row is `[x]` with handover `20261031-01` and a completion note | `rg -n 'input contract is stated' devlog/roadmap.md`; `git diff devlog/roadmap.md` | Agent [x] |
| Every decision recorded this iteration is realized in the files | read `## Decisions`; check each destination | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The problem summary is taken from the session where the session holds it, and elicited only for a part the session lacks. | `/plan` records the goal and problem and gathers context before the interview, and a direct invocation holds the conversation; asking for what the session already holds is the defect the row names. | `grill-me/SKILL.md` `## Problem summary first`; this record |
| The summary stays required of every session; the contract changes who supplies it, not whether it exists. | The interview tests each branch against the summary, so an absent summary leaves nothing to test against; a caller with no prior context is asked for the three parts before the interview. | `grill-me/SKILL.md`; this record |
| No ADR. | The contract governs one skill and is stated where its callers read it; `/plan` already passes the context, so no other component must match a new standing principle. | this record |
| No edit to `/plan`. | It already passes the session's recorded goal, problem, gathered context and confirmed scope to the skill; the missing statement is in the skill the caller reads. | `plan.md` `## Interview`; this record |

## Decisions pending

None.

## Findings

None.

## Completed

| File | Change |
|---|---|
| `src/reasoning/agent/skills/grill-me/SKILL.md` | States where the three summary parts come from and that only a missing part is asked for. |
| `src/reasoning/agent/skills/grill-me/MAINTENANCE.md` | Records the input-contract adaptation and its two callers. |
| `devlog/roadmap.md` | Marks the row `[x]` and records the outcome. |
| `devlog/handovers/20261031-01-workflow-grill_me_input_contract.md` | Closed this handover. |
