---
date: 2026-10-03
milestone: T1 - Workflow + Policy Organization
type: Workflow
status: Closed
---

# Handover - The write-back step keeps its mandate, its value may be None

## Objective

Replace the rule that every close raises one roadmap row per handover with a mandatory write-back step whose value may be None.

## Scope

The close invariant and its two echoes require the close to write "exactly one roadmap row event per iteration", and the runbook tells the agent to raise a subtask row when the iteration's task has none, so the pairing holds. The effect is that an iteration which changed no roadmap task still edits the roadmap, and 103 of the file's 175 rows exist because an iteration wrote back. The measured consequence is cause 2 of the churn study: 105 of 157 commits touch `devlog/roadmap.md`, and 80 of those change six lines or fewer.

The replacement keeps the step mandatory and makes its value nullable. An iteration that completed or rescoped a roadmap task marks that row in the same commit; an iteration that changed no task writes back nothing, and the close records that outcome rather than manufacturing a row to pair with the handover.

| In | Out |
|---|---|
| The close invariant in `iteration_policy.md`, reframed | Any change to `roadmap_policy.md`, whose marking rule is about a task that exists |
| `wrapup.md` B4 and B9 | The study's other improvements, L1, L2 and L4 to L7 |
| `handover-maintenance.md` Step 6.1 and its completion criterion | The study's own roadmap row, which stays as written |

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No rule requires a row per handover | `grep -rn "one row per handover\|exactly one roadmap row event\|write-back is unconditional" docs/ workflow/` returns nothing | Agent [x] |
| The step remains mandatory with a nullable value | `grep -n "Write-back" docs/operations/iteration_policy.md` names the step and states the None case | Agent [x] |
| The runbook carries the same framing | `grep -n "may be None" workflow/coding-agent/prompts/wrapup.md` | Agent [x] |
| The maintenance check tests the landed claim, not a pairing | `grep -n "is not a defect" workflow/coding-agent/skills/handover-maintenance.md` | Agent [x] |
| The records pass the gates | `bash scripts/lint.sh` reports clean across 6 gates | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/operations/iteration_policy.md`](../../docs/operations/iteration_policy.md) | the close invariant that mandates the pairing |
| [`workflow/coding-agent/prompts/wrapup.md`](../../workflow/coding-agent/prompts/wrapup.md) | B4 and B9 carry the mandate |
| [`workflow/coding-agent/skills/handover-maintenance.md`](../../workflow/coding-agent/skills/handover-maintenance.md) | Step 6.1 is the check that enforced it |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Keep the step mandatory and make the value nullable | the write-back is an assessment the close owes the record; requiring an artefact from that assessment is what produced the churn | this handover |
| Remove the pairing rather than widen it | a pairing test that admits None no longer tests a pairing, so the rule and the check both go | this handover |
| Leave `roadmap_policy.md` untouched | its rule marks a task the iteration resolved, which is a task that exists, not a row per handover | this handover |
| Land this iteration without a roadmap row of its own | an instance of the rule it introduces; the handover is the record | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The rule's cost was measurable before it was removed: 103 of 175 rows exist because an iteration wrote back, and the close self-check treated a report of no change as a violation. | mechanism | removed here; the study's cause 2 and improvement L3 |
| The three carriers of the rule were the invariant, the runbook that applies it, and the maintenance check that audits it. A rule with an enforcer per layer costs three edits to retire. | workflow | recorded for the study's requirement R3, which asks that invariants be machine-checkable |

## Completed

| File | Change |
|---|---|
| `docs/operations/iteration_policy.md` | the close invariant reframed: mandatory step, nullable value |
| `workflow/coding-agent/prompts/wrapup.md` | B4 and B9 carry the same framing; the subtask-raising instruction is gone |
| `workflow/coding-agent/skills/handover-maintenance.md` | Step 6.1 tests the landed claim instead of a pairing |
