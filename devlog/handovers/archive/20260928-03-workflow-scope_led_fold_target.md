# Agent Handover

**Date:** 2026-09-28
**Milestone:** M3 - Autonomous Task Execution, Manual Review Workflow
**Type:** Workflow
**Status:** Closed

## Objective

Settle the open edge case of the correction principle: a correction that could attach to either of two units has no stated fold target. The 2026-09-27 decision recorded the case as unsolved. This iteration resolves it, records the decision in the ADR, and closes the roadmap row that carried the question.

## Scope

Two files, one commit, one unit: the ADR gains the resolution entry and the roadmap row closes with a landing note. The resolution and its reasoning are the deliverable; the change came out of a check-in discussion with the operator, who refined the agent's draft of the rule.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | The ADR's `Current:` date is 2026-09-28 and the newest entry carries the scope-led fold-target decision with rationale and rejected alternatives | read `docs/adr/closed_record_corrections.md` | Agent [x] accepted |
| AC2 | The 2026-09-27 edge-case clause that declared the case unsolved carries a `[CORRECTION -- 2026-09-28]` marker pointing at the resolution | read the edge cases | Agent [x] accepted |
| AC3 | The roadmap row closes `[x]` with a landing note naming the resolution entry and this handover | read `devlog/roadmap.md`, row 112 | Agent [x] accepted |
| AC4 | No other surface restates the old "no owner" or "unsolved" wording | `grep -rn` across `docs/`, `workflow/`, `devlog/` | Agent [x] accepted: only the two corrected records matched before the fix; both now carry the resolution |
| AC5 | Lint clean, one commit carrying the handover, Status Closed | `lint.sh`, `git log` | Agent [x] accepted |

## Hot files

| File | Why in scope |
|---|---|
| `docs/adr/closed_record_corrections.md` | the decision record gains the resolution entry |
| `devlog/roadmap.md` | row 112 closes with the landing note |
| `devlog/handovers/20260928-01-workflow-scope_led_fold_target.md` | this handover, rides the commit |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The fold target is the unit whose target scope the fix fits, not the unit whose content the fix corrects | a unit's scope is fixed when the iteration starts, so "does the fix fit the current unit's scope" is a yes-or-no question, not a judgement; keying the target to the corrected content would fold into an arbitrary past commit | `closed_record_corrections.md`, entry 2026-09-28 |
| The realization point selects the mechanics, never the target | in scope and in flight, the fix is the unit's regular work; out of scope, the patch is stashed apart and squashed into the latest relevant commit; after delivery it folds via fixup and autosquash | `closed_record_corrections.md`, entry 2026-09-28 |
| A fix in scope of the current unit is not a correction at all | the correction machinery exists to keep records clean; a fix that belongs to the unit's own target scope rides the unit's commit as a regular entry, no marker, no special fold | `closed_record_corrections.md`, entry 2026-09-28 |
| A tracked record amended for a correction carries its type's marker per R2 | the fold alone would leave the record change unmarked | `closed_record_corrections.md`, entry 2026-09-28 |
| The work is attributed to M3 and recorded in a retroactive handover | operator direction: the settlement is milestone work under M3, and it should have ridden an iteration handover rather than a bare commit | this handover |

## Findings

| Finding | Type | Impact | Triage |
|---|---|---|---|
| The rule set keys ownership to the corrected unit's content where it should key to the realization point and the unit's scope | design gap | R4 and R6 presuppose a single target unit, so the spanning case looked unsolved; the row's two proposed options presupposed the correction is an object rather than a choice of scope | resolved by the 2026-09-28 ADR entry |
| The "not a correction" branch was absent | coverage | the row's premise assumed the correction machinery applies to the most common case, where it does not | resolved by the 2026-09-28 ADR entry |
| The row asked which iteration owns the correction, when the answer is a commit-history question keyed to scope and realization | framing | two of the row's three "does not say" claims were already answered by R5 and by the choice of target | resolved by the landing note |

## Completed

| File | Change |
|---|---|
| `docs/adr/closed_record_corrections.md` | `Current:` to 2026-09-28; the scope-led fold-target entry (decision, rationale, three rejected alternatives, edge cases); `[CORRECTION -- 2026-09-28]` marker on the old unsolved clause |
| `devlog/roadmap.md` | row 112 closed `[x]` with a landing note naming the resolution entry and this handover |

One commit carries this iteration, typed `workflow:` per the governance change. Its subject: `workflow: settle the scope-led fold target for spanning corrections`.

## Deferred items

| Item | Why deferred | Where it goes |
|---|---|---|
| Ordering for two correction markers on one roadmap row | the resolution touched the fold target, not marker ordering; the 2026-09-27 decision recorded it as open | `roadmap.md`, the marker-ordering row |
| Measure the cost of the fold against a commit per correction | the rule prefers the fold and the cost is unmeasured | the T1 workflow rows |

## What's Next

M3. The settlement closes the correction-principle edge case. The T1 sweep continues to hold the open rows the check-in filed under the milestone.
