---
date: 2026-10-05
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - The Placement Rule in the Maintenance Skill

## Objective

Correct the placement rule that `roadmap-maintenance` states, so the check applies the policy's placement default instead of certifying the misfiling it exists to catch.

## Scope

The eval trial found the defect. `roadmap-maintenance` check 3.10 read "A row belongs in the milestone whose section blurb claims the work", and check 3.12 reused the same reading in one clause. [`roadmap_policy.md`](/opt/sandbox/docs/operations/roadmap_policy.md) `### Filing rules` `**Roadmap task placement**` states the opposite default, that a row lands in the current sub-milestone's task list unless the operator directs otherwise.

The reading is the one the recorded negative case ran on. Three rows in one session were filed under a subject track, on the reasoning that a track's blurb claims every row that touches its subject, and the operator redirected all three. A checker that applied the same reasoning found nothing wrong with any of them.

1. **3.10 states the default and names its owner.** The rule now reads the placement default, points at the policy section that owns it, and says what a track's blurb is not.
2. **3.12 loses the same reading.** Its check clause named the copy that sits "under the milestone whose blurb claims the work"; it now names the copy the placement default does not claim.
3. **The correction is a single-edit defect.** No roadmap row was filed. Per `roadmap_policy.md` `### Single-edit record defects`, a defect one edit fixes, found by a gate or a survey, is corrected in place and named in a handover.
4. **The regression case exists before the fix.** `workflow/coding-agent/skills/eval/evals/placement-check.json` reproduces the negative case, and it shipped in the previous unit.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Check 3.10 states the placement default and names the policy section that owns it | read `workflow/coding-agent/skills/roadmap-maintenance/SKILL.md` | Agent [x] |
| No reading that makes a section blurb the placement authority survives anywhere in the tree | `grep -rn "blurb claims" workflow/ docs/` returns nothing | Agent [x] |
| The regression case's with-skill run reads the skill | the session file holds eleven references to the skill, including the `SKILL.md` path | Agent [x] -- and the run reported no placement finding, so the correction's behavioural effect is unproven |
| `bash scripts/lint.sh` is clean | the command | Agent [x] -- 8 gates, clean in 6s |
| `bash scripts/run_tests.sh` is clean | the command | Agent [x] -- 1101 tests across 75 files, 0 failed |
| The handover closes | this handover | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| `workflow/coding-agent/skills/roadmap-maintenance/SKILL.md` | checks 3.10 and 3.12 |
| `devlog/handovers/archive/20261005-11-workflow-the_placement_rule_in_the_maintenance_skill.md` | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The correction cites the policy section rather than restating the rule in full | the skill is a fast path, and the placement default has one home | `docs/development/prompt-authoring-conventions.md` `## Runbook versus advisor versus skill` |
| No roadmap row | the defect is one edit, and the policy sends such a defect to the handover instead | `roadmap_policy.md` `### Single-edit record defects` |
| One run, not a graded comparison | the fix is a document correction; a behavioural claim needs several runs per configuration, and one run cannot carry it | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| One run with the corrected skill still names no misplaced row and cites no placement rule, although it read the skill. It reported on other checks and never evaluated 3.10, so the run says nothing about the correction and the case cannot be closed on a single run. Run-to-run variance dominates at one run per configuration. | evidence, caught by the run | open | Triaged to: `placement-check.json`, which needs several runs per configuration, and to the skill, whose checks are not all exercised in one pass |
| The eval case's baseline run from the earlier trial missed the same row, so the failure reproduces and the case is valid. What is unproven is that the correction removes it. | evidence | open | Triaged to: the case set's next iteration |
| This unit's own delivery body ran 309 characters against the 280-character budget, and its subject ran 53 against the 50-character aim. The policy was in the writing agent's context, and that agent recorded the rule earlier the same session. The failure surfaced only when the body was measured, which is the feedback entry's mitigation and not an effect the wording has on its own. | evidence, caught at review | open | Triaged to: the case set, as its strongest data point so far, and to the T1 eval row |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/skills/roadmap-maintenance/SKILL.md` | check 3.10 states the placement default and its owner; check 3.12 drops the blurb reading |
| eval run artefacts, outside the tree | `$HOME/workspace/output/evals/skill-eval-placement-fix/`: the fixture facts, the session, the report and the run metadata |
