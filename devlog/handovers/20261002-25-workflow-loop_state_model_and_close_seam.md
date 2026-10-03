---
date: 2026-10-02
milestone: T1 - Workflow + Policy Organization
type: Workflow
status: Closed
---

# Handover - The loop state model and the close seam

## Objective

Deliver the loop's state model and the iteration-close / milestone-close seam: redraw the framing ADR's diagram as one arrow per workflow, and move compaction, the changelog, escalation clearance and the review gate out of `/iter` and `/wrapup` to `/milestone-close`. The per-prompt quality pass on `/milestone-start` and `/milestone-close`, and the rule map that finds leaks and overlaps, were claimed by the earlier objective and are not delivered here; they are filed on the roadmap instead.

---
[CORRECTION -- 2026-10-02: the Objective named the per-prompt quality pass, which this iteration did not deliver. It now names the loop state model and the close seam, the work that landed. The title and the filename are retitled to the dominant activity.]

## Scope

The loop's state model and the iteration-close / milestone-close seam. In scope: the state diagram in [`coding_agent_loop_workflow.md`](../../docs/adr/coding_agent_loop_workflow.md), the prompts `iter.md`, `wrapup.md` and `milestone-close.md` under `workflow/coding-agent/prompts/`, and the compaction-caller line in [`roadmap_policy.md`](../../docs/operations/roadmap_policy.md). All three error classes the state map reported are in scope: diagram errors, gap errors, and seam divergences. Out of scope: the autonomous-run prompts, which stay out until the milestone that lands them, and `G6`, the merged-branch write-back, which is recorded rather than wired.

---
[CORRECTION -- 2026-10-02: the Scope named `milestone-start.md` as in scope; the iteration never touched it. The pass on that prompt is filed on the roadmap, so the scope now names only the files the seam changed.]

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | The ADR diagram draws the state model agreed in this handover | `grep -c "ms:close-gate" docs/adr/coding_agent_loop_workflow.md` returns 1 or more | met - 3 occurrences |
| 2 | Every arrow carries exactly one label and one edge type | each arrow in the diagram names one file or one decision | met - every arrow names one prompt or one decision |
| 3 | `/iter` carries no milestone-grain or pre-close work | `grep -n "sub-milestone cleanup" workflow/coding-agent/prompts/iter.md` returns nothing | met - 0 occurrences |
| 4 | `/wrapup` does not run the milestone close | `grep -n "top-level milestone close" workflow/coding-agent/prompts/wrapup.md` returns nothing | met - 1 occurrence, the hand-off sentence in B4 |
| 5 | `roadmap_policy.md` no longer names `/wrapup` as a compaction caller | `grep -n "Invoked by" docs/operations/roadmap_policy.md` names `/milestone-close` only | met - /milestone-close only |
| 6 | The interim map is gone | `ls devlog/discussions/20261002-report-loop_state_map_interim.md` fails | met - file removed |
| 7 | Suite and lint green | `bash scripts/run_tests.sh`; `bash scripts/lint.sh` | met - 1037 passed, lint clean across 5 gates |

## The state model

One workflow is one arrow. A node is a state the loop rests in; a gate is a node where the loop waits for the operator. Decisions are the arrows out of a gate.

Three edge types: workflow-implemented, operator decision, and workflow-assisted operator decision, the last labelled with the assisting workflow or skill. Triage is one such label, not the type.

One milestone is modelled, the active one. Its successors are handwaved behind `ms:successor?`, so the per-node state set a multi-milestone view would need does not appear.

```text
MILESTONE GRAIN

  [ms:none]                                  no active milestone
      |
      |  "milestone to promote?"              workflow-assisted operator decision
      |    no  -> /milestone-start shapes one     (/milestone-start presents the shapes)
      |    yes -> the operator picks one
      v
  [ms:active]  ----------  iterations run against this milestone
      |
      |  /milestone-close                     workflow-implemented
      v
  [ms:close-gate]                            compaction, changelog, boundary presented
      |
      |  operator release                     operator decision
      v
  [ms:successor?]                            handwaved: one milestone is modelled
      |
      |  yes -> promote                       workflow-assisted operator decision
      |  no  -> shape one                    (edge to ms:none above)
      v
  [ms:active]  (the successor)

ITERATION GRAIN  (drawn once; runs against whichever node is ms:active)

  [it:open] --/iter--> [it:scope-gate] --operator decision--> [it:implementing]
                                                                    |
                                                             /iter Step 7
                                                                    v
  [it:closed] <--operator decision-- [it:acceptance-gate] --/wrapup--> (Part B)
      |
      |  all tasks complete? /wrapup recommends
      +-- yes --> ms:close-gate
      +-- no  --> [it:open]   (operator picks the next task)
```

## Hot files

| File | Why in scope |
|---|---|
| `docs/adr/coding_agent_loop_workflow.md` | carries the state diagram this iteration redraws |
| `workflow/coding-agent/prompts/iter.md` | loses the milestone-grain work the model moves out |
| `workflow/coding-agent/prompts/wrapup.md` | loses the milestone close and the compaction step |
| `workflow/coding-agent/prompts/milestone-close.md` | gains the close-boundary section and the compaction step |
| `docs/operations/roadmap_policy.md` | names the compaction caller, which moves |

## Completed

| File | Change |
|---|---|
| `docs/adr/coding_agent_loop_workflow.md` | diagram redrawn to the agreed state model: one workflow per arrow, gates as states |
| `workflow/coding-agent/prompts/iter.md` | out: the sub-milestone close and the pre-close review gate; in: an acceptance-gate section |
| `workflow/coding-agent/prompts/wrapup.md` | B4 loses compaction; the scope line narrows to iteration grain |
| `workflow/coding-agent/prompts/milestone-close.md` | the close-boundary section points at the policy instead of restating it; the compaction step invokes the `roadmap-maintenance` skill, which the `/wrapup` edit had orphaned |
| `docs/operations/roadmap_policy.md` | the compaction caller narrows to `/milestone-close`; the maintenance trigger distinguishes write-back from compaction |

## Decisions

1. **Grain: one workflow is one arrow.** A workflow internal step is not a transition. This removes C1, C7, C8, C9 and C16 from the collision list, which were one shared sub-procedure counted once per caller.
2. **Gates are states, decisions are arrows out of them.** it:scope-gate, it:acceptance-gate, ms:close-gate. it:closing is not a state: closing is the work after the acceptance decision.
3. **Three edge types**, the third labelled by the assisting workflow.
4. **One milestone is modelled**, with ms:successor? handwaving the rest. Several milestones may be shaped at once, which is why a flat global state sequence cannot express the grain.
5. **it:done routes on completeness**: to ms:close-gate when the milestone rows are all closed, else to a new it:open after the operator picks a task.
6. **Gap rulings.** G1 is wired. G2, G3 and G4 are drawn as operator or workflow-assisted operator decisions. G5 is excluded until the milestone that lands the autonomous-run prompts. G6 is recorded, not wired.
7. **The seam is expressed as state, not as a rule about prompts.** iter.md:187 had no home because the model had no acceptance-gate; under the model it is one arrow and the milestone-grain content moves to ms:close-gate.

## Decisions pending

None. The `milestone_policy.md` ownership ruling is deferred, not settled: this iteration did not make it, and the one-line claim here previously said otherwise. It stays open as the `milestone_policy` expansion row beneath the loop-documentation structure decision.

---
[CORRECTION -- 2026-10-02: the row read `None` and claimed the `milestone_policy` ownership ruling was settled. The ruling was not made; it stays open as the `milestone_policy` expansion row on the roadmap.]

## Findings

None.

---
[AMENDMENT -- 2026-10-03: the record carried a `## Deferred` section holding `None.`, which the format gate forbids, and no `## Completed`. The forbidden section is removed and `## Completed` is split out of `## Hot files`, which the format now states separately. Handover `20261003-02` recorded the decision to leave this section as history, on a cutover of `20261003`; the window is now `20261001`, so the section is inside it and that decision no longer holds.]
