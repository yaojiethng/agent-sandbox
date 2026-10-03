---
date: 2026-10-02
milestone: T1 - Workflow + Policy Organization
type: Workflow
status: Closed
---

# Handover - The procedure map for the roadmap-touching prompts and skills

## Objective

Map every procedure step in the prompts and skills that read or write the roadmap, giving each step its current home and its correct home -- then land the moves the map proves, and deconflict the four loop-workflow prompts.

## Scope

The second of two passes. The policy map mapped the rule layer; this maps the procedure layer, so the two can be read against each other. The shortlist is selected by mention, so a reader can reproduce it.

| File | Mentions |
|---|---|
| `workflow/coding-agent/skills/roadmap-maintenance.md` | 16 |
| `workflow/coding-agent/prompts/milestone-close.md` | 10 |
| `workflow/coding-agent/prompts/milestone-start.md` | 5 |
| `workflow/coding-agent/prompts/plan.md` | 4 |
| `workflow/coding-agent/prompts/iter.md` | 4 |
| `workflow/coding-agent/prompts/bootstrap.md` | 4 |
| `workflow/coding-agent/prompts/wrapup.md` | 1 |
| `workflow/coding-agent/prompts/gm.md` | 1 |
| `workflow/coding-agent/prompts/backlog-triage.md` | 1 |

**The map's applications landed in the same iteration**, mirroring the policy map. The deconfliction pass covered `/plan`, `/milestone-start`, `/milestone-close`, `/wrapup` and `/document`, grouped into one roadmap row naming all five at the operator's direction:

| File | What the pass landed |
|---|---|
| `/plan` | the grain statement, and a quality read |
| `/milestone-start` | the decision axes delegated to their owner, and a quality read |
| `/milestone-close` | three restatements dropped, and a quality read |
| `/wrapup` | the stale frontmatter claim, and a quality read |
| `/document` | the human review gate the operator named |

**Deferred.** The **deconfliction review** -- reading one map against the other to expose a rule with no home, a rule with two, and a procedure that restates a rule. This iteration did that read where the answer was already available (the 40 `point` verdicts, below); the systematic pass is the next unit.

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | The procedure map covers every procedure step in the nine shortlisted files | one row per step: the step, its current home, its correct home, a verdict; no silent drop | met -- 235 rows across all nine |
| 2 | Every row carries a verdict | every row reads stays, move, duplicates or no home; none blank | met |
| 3 | The 40 `point` verdicts are applied or explicitly deferred | each resolved against the prompt it governs, or named as still open with the reason | met -- 6 resolved by a move, 14 with their restating site found and fixed, 16 already correct, 4 out of scope and named |
| 4 | The prompt-side moves land | `/plan` states its inferred grain and both `plan` definitions widen; `gm.md` reads blocking as ordering and loses its duplicate rule; `roadmap_policy` carries no procedure | met |
| 5 | The five loop-workflow prompts name a canonical owner per rule and per step | the review findings applied against `prompt-authoring-conventions.md` | met -- 30 duplicate rule statements dropped across eight files |
| 6 | Suite and lint green | `bash scripts/run_tests.sh`; `bash scripts/lint.sh` | met -- 1037 passed; lint clean across 5 gates |

## Hot files

| File | Why in scope |
|---|---|
| [`workflow/coding-agent/skills/roadmap-maintenance.md`](../../workflow/coding-agent/skills/roadmap-maintenance.md) | 13 duplicate rule statements, the largest cluster in the set, against its own stated contract |
| [`workflow/coding-agent/prompts/iter.md`](../../workflow/coding-agent/prompts/iter.md) | nine duplicates, one verbatim repetition, and the acceptance-gate boundary |
| [`workflow/coding-agent/prompts/milestone-close.md`](../../workflow/coding-agent/prompts/milestone-close.md) | four duplicates, and the close-boundary section that is the model |
| [`workflow/coding-agent/prompts/plan.md`](../../workflow/coding-agent/prompts/plan.md) | the grain statement, and a stale claim from the close seam |
| [`workflow/coding-agent/prompts/wrapup.md`](../../workflow/coding-agent/prompts/wrapup.md) | the stale frontmatter claim |
| [`workflow/coding-agent/prompts/gm.md`](../../workflow/coding-agent/prompts/gm.md) | the classification axes, now their owner |
| [`docs/operations/roadmap_policy.md`](../../docs/operations/roadmap_policy.md) | the three gap fills, all in one file |

## Decisions

1. **The verdict vocabulary drops `point`.** The policy map's `point` means a policy states a rule it does not own and should point at the owner. A runbook has no equivalent: a runbook that restates a rule is duplicating it, and the fix differs, because a runbook that states no rule cannot be read as the owner. The four verdicts are `stays`, `move`, `duplicates` and `no home`.
2. **The fix for a duplicate is a deletion plus a pointer, not a rewrite.** The runbook keeps the check and the correction and drops the rule statement. Thirteen of `roadmap-maintenance.md`'s checks needed exactly that.
3. **The classification vocabulary gets one home: `gm.md`.** Size, Progress and Impact were defined twice, in `gm.md`'s inventory and `milestone-start.md`'s decision axes, with identical value sets. `gm.md` owns them because its table is what a reader meets first; `/milestone-start` grades its audited pool on them and reads them there.
4. **All three gaps fill into `roadmap_policy.md`.** The coherence invariant, the outcome-summary marker and the `active-milestone` frontmatter transitions are all statements about the roadmap record, so home where the object lives puts all three in the file that governs it.
5. **Three of the map's own rows were corrected during the fix pass.** Rows 165, 166 and 169 were called duplicates; reading the owner again showed the policy states the *standard* while the prompt states the *step*. A step is what a procedure is for.
6. **`/plan`'s grain is inferred and stated, never passed.** A caller forced to know the grain before it can invoke `/plan` has been given the wrong interface.

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| 30 runbook statements restate a rule a policy owns -- 13 of them in `roadmap-maintenance.md`, which declares in its own purpose that it does not do this | contradiction | fixed in place. Triaged to: the map's Findings, and the runbooks themselves |
| The close seam's stale claims survived in two sites the iteration did not reach: `wrapup.md`'s frontmatter and `plan.md`'s Close both still assigned compaction to `/wrapup` | bug | fixed in place |
| `iter.md` stated the steering-received rule twice, verbatim, with the prompt-scope paragraph between the two | bug | fixed in place |
| The Size / Progress / Impact vocabulary had two homes with identical value sets | contradiction | fixed in place. Triaged to: `gm.md` as owner |
| Four `point` verdicts (`story_policy` 5, `study_policy` 4, 9, 13) name a restating document that is outside both maps' shortlists, so the site is still unfound | gap | roadmap. Triaged to: roadmap.md -- *The four point verdicts neither map can reach* |
| The agent reported having run out of room and stopping short, with no signal behind the claim; a search found the environment exposes no capacity variable at all | bug | fixed in place. Triaged to: `devlog/AGENT_FEEDBACK.md` `[A]` entry, and the two provider-layer `AGENTS.md` rules it produced |
| The producer-owns-the-definition rule is applied here but stated nowhere in the policy layer | steering | roadmap. Triaged to: roadmap.md -- *Record the producer-owns-the-definition rule* |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/skills/roadmap-maintenance.md` | 13 rule statements dropped to pointers; checks and corrections kept |
| `workflow/coding-agent/prompts/iter.md` | the unit rule, the type table and the defect rule reduced to pointers; the acceptance-criteria standards delegated; the duplicate bullet removed |
| `workflow/coding-agent/prompts/milestone-close.md` | three restatements dropped to named owners |
| `workflow/coding-agent/prompts/milestone-start.md` | the decision axes delegated to `gm.md`; the Record shape pointer tightened |
| `workflow/coding-agent/prompts/plan.md` | the grain stated; the stale compaction claim removed; the scoped unit named at its grain |
| `workflow/coding-agent/prompts/wrapup.md` | the frontmatter claim corrected |
| `workflow/coding-agent/prompts/gm.md` | the duplicated cosmetic rule dropped; the classification axes marked as this prompt's to own |
| `workflow/coding-agent/prompts/backlog-triage.md` | the nine-type enumeration dropped for the owner |
| `docs/operations/roadmap_policy.md` | the **One record** block, the outcome-summary marker, and the **Frontmatter** paragraph |
| `docs/operations/handover_policy.md` | the `plan` type widened from milestone scoping to any grain |
| `docs/operations/git_policy.md` | the `plan` entry and the `plan` vs `docs` distinction widened to any grain |
| `devlog/AGENT_FEEDBACK.md` | an `[A]` entry: a capacity claim stated as fact with no signal behind it |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | the two rules that entry produced: unobservable state is marked an inference, and no capacity claim without a signal |
| `devlog/roadmap.md` | five rows closed, one filed |
