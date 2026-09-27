# Agent Handover

**Date:** 2026-09-27
**Milestone:** M3 - Autonomous Task Execution, Manual Review Workflow
**Type:** Workflow
**Status:** Closed

## Objective

Replace the rule that a closed record is untouchable with one rule that covers every record in the repository: a closed record's content does not change, it gains its type's marker, and a record that tracks state also gains a successor entry.

## Scope

Six policy sites, one unit each, one commit each, in dependency order. The shared principle is written first because the other five reference it; the other five are then brought into line and their superseded wording removed.

| Unit | Site | Change |
|---|---|---|
| 1 | `docs/operations/documentation_policy.md` | the shared principle, the direction and the agent's checks, propagation, archival, and the per-type table |
| 2 | `docs/operations/handover_policy.md` | the principle applied to handovers, with the qualifying situations |
| 3 | `docs/operations/roadmap_policy.md` | the state-record mechanic and the milestone anchor; the changelog half's rationale corrected |
| 4 | `docs/operations/git_policy.md` | amending stated as when and how, as principles for maintaining git state |
| 5 | `docs/operations/iteration_policy.md` | what may be amended after close, and at whose direction |
| 6 | `src/reasoning/providers/pi/config/agent/AGENTS.md` | the coarse rule dropped |

The change came out of a corrections clause this session could not apply: a closed handover was silent on a limit of its own experiment, the rule's trigger was an illustrative list, and two readers took opposite views of the same case without either breaking the rule. The operator's own framing then corrected two of the agent's drafts, and the resulting rule is scoped across all records rather than to handovers.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | `documentation_policy.md` states the principle, the direction, the two stops and one smell, propagation, and archival, and carries a per-type table naming the form for each record type | read the section | Agent [x] accepted: `ec986a3`, amended by `dfb3e3e` |
| AC2 | The claim that the correction procedure is the same across document types is gone, and the table replaces it | `grep -n "the procedure is the same"` | Agent [x] accepted: no match |
| AC3 | `handover_policy.md` states the principle, the three qualifying situations, and the rewrite-and-mark form | read the section | Agent [x] accepted: `14036e2`, trimmed by `3c10fa1` |
| AC4 | `roadmap_policy.md` states the state-record mechanic, the successor entry, and the milestone anchor including the open-milestone case | read the section | Agent [x] accepted: `1f0b9d3` |
| AC5 | `git_policy.md` prescribes no list of amendable cases and no prior-iteration boundary, and states when and how as principles | read the section | Agent [x] accepted: `fc92719` |
| AC6 | `iteration_policy.md` states what may be amended after close and at whose direction | read the section | **Withdrawn.** The operator asked what the odds are that an agent reads `iteration_policy.md` when asked to correct a record, and the read-trigger table in `AGENTS.md` answered it: its trigger is iteration start or end, new task, story, investigation or milestone transition, and a correction is none of them. The content moved to the always-loaded `AGENTS.md`, and this file gains nothing by restating it |
| AC7 | The shipped provider `AGENTS.md` no longer carries "Close -> done. No commits after close." | `grep -n` | Agent [x] accepted: `6a061a2`, and the second carrier with it |
| AC8 | Negative check: no file still asserts a superseded rule. `grep -rn` for "No commits after close", "Do not amend commits from prior iterations", "the procedure is the same" and "sufficient notice" across `docs/` and the shipped `AGENTS.md` returns nothing | the grep | Agent [x] accepted: no match on any of the five phrases, including the fifth carrier found in `AGENTS.md` line 20 |
| AC9 | Every link added by the six units resolves | a link check over the six files | Agent [x] accepted: all added links resolve; four pre-existing placeholder links inside examples remain and are not from this change |
| AC10 | The suite is green at 998 units and lint is clean | `bash scripts/run_tests.sh` and `bash scripts/lint.sh` | Agent [x] accepted as 1001 units, 0 failed -- the count rose when the track branches were consolidated earlier in the session, and the AC's figure is stale rather than the suite wrong; lint clean at every commit |
| AC11 | Handover committed with the delivery commits, Status Closed | `git log` | Agent [x] accepted |

## Hot files

| File | Why in scope |
|---|---|
| `docs/operations/documentation_policy.md` | unit 1 |
| `docs/operations/handover_policy.md` | unit 2 |
| `docs/operations/roadmap_policy.md` | unit 3 |
| `docs/operations/git_policy.md` | unit 4 |
| `docs/operations/iteration_policy.md` | unit 5 |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | unit 6 |
| `docs/operations/study_policy.md` | reference: already delegates, needs no change |
| `devlog/handovers/20260927-07-workflow-correction_principle_across_records.md` | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The principle covers every record, not handovers alone | the observed defect was not a handover defect: a completed roadmap row, a row closed on partial scope and a record silent on a limit all met it | the shared section |
| Two mechanics, not one, keyed to what the record is for | a record that states what is true is corrected in place and marked; a record that tracks state gains a marker and a successor entry, because a completed task is not a claim to be rewritten | the shared section and `roadmap_policy.md` |
| The changelog is the roadmap's archived half, not a separate kind of document | operator correction; the milestone anchor in the existing marker already presupposed that model | `roadmap_policy.md` |
| No coined terms; the table maps document types to forms | a record is already a defined term in this policy, and a second axis of vocabulary invites one-term-one-meaning drift | the shared section |
| `git_policy` states when and how, `iteration_policy` states what | operator direction; the two questions are separable and belong to different files | units 4 and 5 |
| The provider `AGENTS.md` loses the rule entirely | operator direction: too coarse a rule for that document, and it is the file that seeds the host | unit 6 |
| A threshold question gets no threshold in policy | the operator's request is the trigger, so "correction too small for its own handover" is a common case rather than a rule the agent applies | the shared section |
| `study_policy.md` is left alone | it already delegates to the shared section and carries only its own form, which is the pattern the other sites are being brought into | reference in Hot files |
| The lifecycle statement goes in the always-loaded `AGENTS.md`, not in `iteration_policy.md` | operator direction, and the read-trigger table supports it: `iteration_policy.md`'s trigger does not fire for a correction, while `AGENTS.md` is read before anything else | this handover, AC6 |
| Two `AGENTS.md` clauses carried the restriction, not one | the operator named the "Close -> done" line; a grep found the operative one at line 20, naming corrections and limiting them to the same iteration. Deleting only the named line would have left the rule standing where every session reads it | this handover, Findings |
| The decision record is an ADR, and the policy sections carry rules only | operator direction, and the standing declarative-framing ADR, which an earlier draft of a policy section violated | [`closed_record_corrections.md`](../docs/adr/closed_record_corrections.md) |
| The iteration lands as one commit, not one per section | operator direction. The unit rule in `auto.md` makes the smallest change that lands as one commit one unit, and one subject writes this diff, so ten section-by-section commits were one unit split nine ways | this handover, Findings |

## Findings

| Finding | Type | Impact | Triage |
|---|---|---|---|
| The milestone-anchored marker has no form for a correction landing inside an open milestone, which is the common case for this kind of work | gap | three records were corrected mid-milestone in this session and none could be tagged under the vocabulary as written | resolved by the anchor rule: the marker names the milestone carrying the correction, open or closed, with the iteration as the fallback |
| `documentation_policy.md` claimed the correction procedure is identical across document types while `roadmap_policy.md` forbade rewriting | policy conflict | the false claim is why the handover case read two ways | resolved by the per-type table |
| The changelog half of `roadmap_policy.md` was justified by a readability argument, which is the argument for the opposite mechanic | record defect | the rationale contradicted the rule it sat under | resolved by the state-tracker framing: the changelog is the roadmap's archived half |
| The always-loaded `AGENTS.md` stated the restriction twice, and the clause that would govern an agent's behaviour was not the one flagged | policy defect | deleting only the "Close -> done" line would have left "Correction commits fix an earlier commit in the same iteration" standing in the file every session reads first, with the relaxation invisible in the case it exists for | resolved in `6a061a2`; recorded here because the operator's instruction named the other line |
| A proposed policy section would have been invisible: `iteration_policy.md`'s read-trigger does not fire for a correction | design defect | a rule no agent reads is not a rule; the same class of failure as a rule two readers interpret differently | resolved by moving the statement to `AGENTS.md` and withdrawing AC6 |
| A policy section drafted with a rationale paragraph violated the standing declarative-framing ADR | record defect | the ADR names this exact defect -- mixed rationale and rule -- and the section would have carried a second one | caught before commit; the reasoning moved to the ADR and the two committed sections were trimmed in `3c10fa1` |
| A correction crossing two iterations inherits no record set, so nothing says which records it reaches | unsolved design case | the propagation rule has a gap at its own boundary | routed to `roadmap.md` as a named row (da2dfe7) |
| A roadmap row corrected twice has no marker ordering | gap | handovers order their tags; roadmap rows do not | routed to `roadmap.md` as a named row (da2dfe7) |
| The agent and the operator read "unit" differently: one policy decision became ten commits, one per section | divergence in how a unit is read | the history reads as ten unrelated edits rather than one decision, which is the shape the amendment rule this iteration wrote exists to prevent | routed to handover `20260927-08-workflow-unit_boundary_proposal_and_commit_granularity`, which owns its resolution |

---
[CORRECTION -- 2026-09-27: The iteration's ten commits are folded into one at operator direction, so the Commits line below names the folded commit rather than the ten it replaced. The same correction adds the unit divergence to Findings and records the fold in Decisions. The finding is routed to handover `20260927-08-workflow-unit_boundary_proposal_and_commit_granularity`, which owns its resolution.]

---

## Completed

| File | Change |
|---|---|
| `docs/operations/documentation_policy.md` | the shared principle, direction, two stops and one smell, propagation, archival, and the per-type table; the false cross-type claim removed |
| `docs/operations/handover_policy.md` | the three qualifying forms, the reopen path, and the metadata rule restated as an end-state constraint |
| `docs/operations/roadmap_policy.md` | the state-record mechanic, the successor entry, the milestone anchor including the open case, and the corrected changelog statement |
| `docs/operations/git_policy.md` | amending as principles for when and how; the case list and the prior-iteration boundary removed |
| `docs/adr/closed_record_corrections.md` | the decision record: six requirements, the decision, the rationale, eight rejected alternatives with failure loci, and the edge cases |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | both restriction clauses replaced or removed, with a pointer to the decision |
| `devlog/roadmap.md` | two rows for the open edge cases |
| `devlog/handovers/20260927-07-workflow-correction_principle_across_records.md` | this handover |

One commit carries this iteration, typed `workflow:` per the primary change. Its subject: `workflow: replace the closed-record correction rule across every record type`.

## Deferred items

| Item | Why deferred | Where it goes |
|---|---|---|
| Measure the cost of the fold against the alternative of a commit per correction | the rule prefers the fold and the cost is unmeasured | the T1 workflow rows |
| Define "left this container" as a checkable condition, so the git principle's shared-history bullet stops relying on the operator's judgement | the operator defined it operationally and the principle states it without inventing a term | the T1 workflow rows |
| Add a link from the close step to the correction rule | the operator's discoverability question answered against adding a paragraph to `iteration_policy.md`; the rule now lives in the always-loaded file, so the close step gains little | not scheduled |

## What's Next

M3. Six policy sites rewritten to one rule.
