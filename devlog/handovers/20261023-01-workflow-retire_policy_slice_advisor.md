---
date: 2026-10-23
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - Retire the policy-slice advisor

## Objective

Retire the policy-slice writing advisor, leave the part of its method that has no other home as a `review` runbook under `skill-scaffolder`, and take the surviving parts of `pi-reviewer-dispatch` into it so that skill can be retired in turn.

## Scope

The roadmap row **Retire the policy-slice advisor**, a sub-row of **Retire the policy form** under M3.3.2. The row's ending admits deletion or a re-scope to the reviews the loop still runs. This iteration takes the re-scope: the policy-slice prompt is deleted, and its surviving method becomes `.agents/skills/skill-scaffolder/runbook/review.md`, a sibling the skill indexes and dispatches.

The same pass mines `pi-reviewer-dispatch` for the parts a review brief owns: the read-only frame, the handling of a returned report, and the rule that agreement between the pair is the signal. Its mechanism -- the pinned pair, the script, the log and model read-back, the failure table -- stays where it is, and a roadmap row is opened to retire that skill once its mechanism has an owner. The overlap with the open model-bypass draft is named in that row, not resolved here.

The survey that settled what survives: the dispatch steps, the pair, the dirty-tree precondition and the claim-verification handling repeat `pi-reviewer-dispatch`, `iter.md` and `commit.md`; the repeated-content, misattribution, inconsistency and structure lenses repeat `doc-maintenance`'s diagnostic register and its Steps 4-5; the cut bound repeats `communication-principle-cut-what-carries-nothing`. Four blocks have no other home: the rule-loss walk against the source being absorbed, the per-file length verdict with quantified cuts, the keep list and rule-preservation bound, and the measured/inferred/guessed evidence label. The report shape carries them, and it survives too.

Out of scope: `doc-maintenance`, which is the canonical owner of the document checks this runbook cites; `/document` Step 7, which keeps its hand-built review brief, because a shipped prompt cannot name a project-only skill path and the document iteration's reviewer is not a skill review; M3.2.2's review-surface consolidation, which may later merge this runbook into a canonical prompt; and the post-hoc rule-loss audit over the eight retirement slices, which is its own unit, has its own roadmap row, and is dispatched through this runbook.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The policy-slice prompt is deleted, source and seeded copy | `test ! -e src/reasoning/providers/pi/config/agent/prompts/doc-advisor-policy.md && test ! -e /home/agentuser/.pi/agent/prompts/doc-advisor-policy.md` exits 0 | Agent [x] |
| The runbook exists at `runbook/review.md` and the scaffolder indexes and dispatches it | `test -e .agents/skills/skill-scaffolder/runbook/review.md`, and `grep -c 'runbook/review.md' .agents/skills/skill-scaffolder/SKILL.md` is 2 | Agent [x] |
| The scaffolder's signpost names the review trigger | `grep -c '^description:.*review' .agents/skills/skill-scaffolder/SKILL.md` is 1 | Agent [x] |
| The runbook keeps every block that has no other home, over a subject named as an instruction surface | `grep -c 'The subject is an instruction surface: a skill or a prompt'` is 1, and the file carries the rule-loss walk, the length verdict, the keep list, the preservation bound, the evidence label, the report shape, the read-only frame and the pair-agreement handling | Agent [x] |
| The duplicated lenses are cited, not restated, and the dispatch names the stable owner | `grep -c 'doc-maintenance' .agents/skills/skill-scaffolder/runbook/review.md` is 1, `grep -c '## Running Review Subagents'` is 1, and `grep -En 'policy-retirement\|retired policy\|--provider\|dispatch_role_model'` prints nothing | Agent [x] |
| The roadmap carries the write-back | the advisor row reads `[x]` with its re-scope note, `grep -c 'Retire .pi-reviewer-dispatch. into its mechanism owner' devlog/roadmap.md` is 1, and the rule-loss audit row is present | Agent [x] |
| Every decision this iteration recorded is realized in the files | each row of the Decisions table against the tree | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The surviving method becomes a runbook at `skill-scaffolder/runbook/review.md` | The scaffolder is where a skill is made, so its review is the same skill's counterpart; the skill index is the mechanism a sibling is loaded through, and `patterns/nested-patterns.md` states that an unindexed sibling is never loaded. A `runbook/` directory separates the ordered procedure from the `patterns/` a writer consults, on the runbook-versus-pattern split `prompt-authoring-conventions.md` states | this record |
| Only the blocks with no other home are kept; the document lenses become a pointer to `doc-maintenance` | A second copy of a rule `doc-maintenance` already owns is the duplication this review exists to catch | this record |
| The evidence-label rule stays, in the runbook | It has no other home, it was added after an operator caught an unlabelled inference presented as fact, and it is a review-quality rule rather than a campaign rule | this record |
| The review is dispatched from the scaffolder's workflow, not from a shipped prompt | `skill-scaffolder` is project-only and absent from the `initialize` corpus, so the linking gate forbids a shipped prompt from pointing at it; the skill's own step and the operator are its dispatchers | this record; the `linking` skill's `## The check` |
| The policy-slice prompt is deleted rather than kept beside the runbook | One review for a skill, at the scaffolder; a second surface would be the same brief with a dead subject | this record |
| The review brief names the provider `AGENTS.md` `## Running Review Subagents` for dispatch, not `pi-reviewer-dispatch` | That section is the stable owner of the mechanism; it names the skill today and will name its replacement later, so the runbook takes no dependency on a surface slated for retirement | this record |
| `pi-reviewer-dispatch` is slated for retirement in its own row, not in this unit | Mining the brief's parts is this unit's work; moving the pair, the script and the failure rules to their owner is a mechanism change with its own test, and it overlaps the open model-bypass draft | `devlog/roadmap.md` |
| The runbook's subject is an instruction surface -- a skill or a prompt -- that was created, folded into, or shortened | The retirement slices it must serve landed in prompts as often as in skills, so a skill-only subject could not review them, and a review that cannot serve the slice it was built for is a surface with no caller | this record |
| The post-hoc audit, when it runs, is dispatched through this runbook rather than through the old prompt | Neither surface has ever run, the rule-loss method is the same on both, and a finding table produced by the prompt would leave the runbook unexercised while the prompt is deleted | this record |

## Decisions pending

None. The operator answered the audit question on 2026-10-23: run it, through this runbook.

## Findings

None.

## Completed

| File | Change |
|---|---|
| `.agents/skills/skill-scaffolder/runbook/review.md` | new: the rule-loss and length review over an instruction surface, carrying the brief parts mined from `doc-advisor-policy` and `pi-reviewer-dispatch`, and citing `doc-maintenance` for the document checks |
| `.agents/skills/skill-scaffolder/SKILL.md` | the `runbook/review.md` index row, a **Review the Result** workflow step, and a description that names the review trigger |
| `src/reasoning/providers/pi/config/agent/prompts/doc-advisor-policy.md` | deleted: the retired campaign prompt |
| `/home/agentuser/.pi/agent/prompts/doc-advisor-policy.md` | the seeded copy, deleted with its source |
| `devlog/roadmap.md` | the advisor row closes on its re-scope branch; the `pi-reviewer-dispatch` retirement row opens under M3.2.2; the rule-loss audit row opens under M3.3.2. The pre-handover maintenance check found the prior row already `[x]`, so no repair was needed |
