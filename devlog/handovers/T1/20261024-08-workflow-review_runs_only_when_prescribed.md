---
date: 2026-10-24
milestone: T1 - Workflow + Policy Organization
type: Workflow
status: Closed
---

# Handover - A review runs only where a workflow calls it

## Objective

Make the skill-scaffolder offer a review instead of dispatching one, and bound the rule-preservation clause to the case it was written for.

## Scope

The scaffolding procedure's review step, the review runbook, and this record. The `/scope` prompt and its record are a separate unit, closed in [`20261024-07-workflow-restore_approved_scope_prompt.md`](20261024-07-workflow-restore_approved_scope_prompt.md).

Three items are ruled out with a reason each. The provider `AGENTS.md` is not changed: it states the review mechanism, which is unchanged, and the rule about when a review may run is workflow authority that would then load in every session. No new gate is added: the incident's dispatch command was composed from the runbook's prose rather than copied, so a text scan would not have caught it. No second review runbook is added: the procedure is identical in both cases and only the preservation bound differs.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The scaffolder offers the review and dispatches it only on the operator's word | `grep -n 'Offer the Review' .agents/skills/skill-scaffolder/SKILL.md` | Agent [x] |
| The runbook names only the scaffolding procedure and the operator as callers | `sed -n '/^## Called from/,/^## Steps/p' .agents/skills/skill-scaffolder/runbook/review.md` | Agent [x] |
| The rule-preservation clause carries both cases | `grep -n 'bounds every cut on a move' .agents/skills/skill-scaffolder/runbook/review.md` | Agent [x] |
| Lens 1 agrees with the clause | `grep -n 'landed somewhere in the subject' .agents/skills/skill-scaffolder/runbook/review.md` | Agent [x] |
| The record passes its gate | `bash scripts/check_handover_format.sh devlog/handovers/20261024-08-workflow-review_runs_only_when_prescribed.md` | Agent [x] |
| The gates stay clean | `bash scripts/lint.sh` across 12 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The scaffolder asks before running a review | it dispatched automatically, and on 2026-10-24 that meant an agent-initiated review rewrote a prompt the operator had released | `.agents/skills/skill-scaffolder/SKILL.md` step 6 |
| The "who may call this" rule lives in the runbook's `## Called from`, not in `AGENTS.md` | it is workflow authority, not review mechanism, and `AGENTS.md` would load it into every session | the review runbook |
| Rule preservation is bounded to a move | the clause was written for a policy retirement where the base rule set was invariant; the reused form made any source's rules owed in the subject | the review runbook, the clause and lens 1 |
| A directed reduction is governed by the direction, not by the reviewer's inference | the operator's direction decided the cuts, and the reviewer restored them because the brief asked it to infer retirements from a general direction | the review runbook, the clause |
| One runbook, not a move runbook and a cut runbook | both cases run the same steps and read the same bars; only lens 1's bound differs, so a second file would duplicate the brief | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The clause's provenance: it was written 2026-10-15 for the policy-slice advisor, where the source was a retired `docs/policies/*_policy.md`, the operator's mandate was "shortening the content without affecting the base rule set", and rules had to land "somewhere" | record | the bound was carried by the operator's mandate and the subject paragraph, not by the sentence | fixed here: the clause states the move case and the reduction case |
| On 2026-10-23 the sentence moved into the review runbook with the retired-policy frame dropped, "somewhere" tightened to "in the subject", and the mandate turned into an exception the reviewer had to infer; the agent noted the risk in the same session and wrote the broader form anyway | mechanism | a reviewer audits a directed cut as rule loss | fixed here |
| The `/scope` review applied that clause to a released prompt and rewrote it from 77 to 95 lines without the operator reading the result | defect | an agent-initiated review landed as if approved | fixed in `20261024-07`, and the dispatch path is closed here |

## Completed

| File | Change |
|---|---|
| [`skill-scaffolder/SKILL.md`](../../.agents/skills/skill-scaffolder/SKILL.md) | step 6 becomes "Offer the Review", dispatching only on the operator's word |
| [`skill-scaffolder/runbook/review.md`](../../.agents/skills/skill-scaffolder/runbook/review.md) | a `## Called from` section, a call step that no longer decides whether a review happens, and a two-case rule-preservation clause with lens 1 aligned |
| [`devlog/handovers/20261024-08-workflow-review_runs_only_when_prescribed.md`](20261024-08-workflow-review_runs_only_when_prescribed.md) | this record |
