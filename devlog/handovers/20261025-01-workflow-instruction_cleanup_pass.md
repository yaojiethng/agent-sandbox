---
date: 2026-10-25
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - The instruction cleanup pass

## Objective

Settle the method a pass over a review-instruction surface follows: the census, the categories it sorts into, the screen the operator reads, the evidence a proposal carries, and the fold.

## Scope

Continues **The review-pass family** under M3.2.2, task item one, and its instrument is task item two's consolidation. The directive narrowed the unit to the consolidated instruction set for reviewer dispatch: the counterparty row's eight checks stay as instructions; its invocation at the three gateless closes moves to the dispatch command surface, M3.2.3.

In scope: the cleanup method, stated once in [`instruction-cleanup.md`](../../workflow/coding-agent/prompts/instruction-cleanup.md) so every later pass over another surface runs it rather than re-deriving it; the counterparty's check scope as the first body of work the method will carry; and the design record for the check scope. Out of scope: measuring yield, running any prompt or eval, and the dispatch seam's three questions (who formats a seat's result, who processes it, who assigns the verdict).

The design record is [`20261025-design-active-counterparty_check_scope.md`](../discussions/20261025-design-active-counterparty_check_scope.md).

## Acceptance criteria

- One cleanup procedure stated once, in [`instruction-cleanup.md`](../../workflow/coding-agent/prompts/instruction-cleanup.md), with no open question left in it.
- Every fault it names has a test for raising it and a rule for settling it, and a fault it cannot yet name has a route to the operator.
- The procedure carries the contract of what it builds: a runbook, its scope kinds, its optional focus, and the two base skills.
- The design record for the first body of work the procedure will carry is written and current.
- `bash scripts/lint.sh` is clean, and no prompt is run and nothing is measured.

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The pass runs census, categories, provenance, judgement, screen, fold, and decides top-down while applying bottom-up | a ruling needs its whole use case in view, and a file must never be half-migrated; the two are keyed differently, so one unit cannot serve both | `instruction-cleanup.md` The pass |
| A census row covers one unit of logic, keyed by site, in seven kinds | keying by site makes a missing kind a re-labelling rather than a re-read; the kinds are the smallest spans ruling independently | `instruction-cleanup.md` The census |
| A category is a use case and becomes one runbook; the shared body is its own category and is decided first | the rules more than one skill reads are what every later runbook is written against, so a body fixed afterwards rewrites all of them | `instruction-cleanup.md` The categories |
| A rule's placement is decided by whether one change must land in both sites: it must, and the rule is promoted; it need not, and each site keeps its copy behind a pointer | `principle-single-source-of-truth` forbids the second copy, and a shared shape over different content costs a framework and reads worse than the repetition | `instruction-cleanup.md` The categories |
| Provenance is one register per unit, entries in one shape, each graded a reason or a proof; the register is kept apart from the judgement that reads it | provenance is the looser word by design: an operator ruling is a reason for a rule to exist, not a proof that it is sound, so one table cannot carry both and a second axis of direction would replace the operator's judgement with the agent's | `instruction-cleanup.md` The provenance |
| A conflict entry names a set and offers two to four resolution options, never a condemned member; a duplication entry is the agent's judgement and the operator's ruling settles it | the surface proves the set inconsistent and says nothing about which member is wrong, while two sites stating one rule is a judgement no record can supply | `instruction-cleanup.md` The provenance, The judgement |
| The screen has two shapes: a removal batch where no objection removes, and an option batch where `accept edit 3` applies a recommendation | the first needs a settled case and a homogeneous batch; the second is safe only where the recommendation is one of the visible options, the text already exists, and no live preference is at stake | `instruction-cleanup.md` The screen |
| The pass's own vocabulary is defined before the census; the surface's terms are findings, not preconditions | a procedure depends on fixed terms and only discovers whether they were adequate | `instruction-cleanup.md` The census |
| The kinds are ratified on a one-file calibration and the map of categories on the first category | a wrong taxonomy surfaces after one file rather than after the surface, and the calibration is also the map's first test | `instruction-cleanup.md` The census, The categories |
| The census logic is inlined in the prompt, with fault modes left to the screen | one consumer today; extraction waits on a second pass, the same test that counts a rule's consumers | `instruction-cleanup.md` The census |
| A runbook is what is dispatched to a fresh context; a procedure the working agent runs over its own records is a check skill | the test is invocation, not subject: the three maintenance skills are run in-session by `/iter` and `/wrapup`, so no judgement about their content is needed to place them | `instruction-cleanup.md` The runbooks |
| A runbook declares the scopes it accepts, and the scope kinds are a delta and a set | a diff answers what changed and a path set answers what is structurally true, so a structural sweep cannot take a range and a change review cannot take a module set; a runbook declaring no scope is the defect that made whole-tree sweeps unrepeatable | `instruction-cleanup.md` The runbooks |
| An optional focus narrows only, and a focused run returns no verdict | a focus that could widen would smuggle a whole-tree sweep back in, and a verdict over a subset is a false assurance | `instruction-cleanup.md` The runbooks |
| The four faults and the entry kinds are vocabulary rather than a closed set, and a fault the agent cannot yet name is flagged for the operator instead of dropped | a format is a filter, and a filter that runs before the operator sees anything turns "the agent could not fill the fields" into "there is nothing here"; the census is the net under it, since every unit is already in front of the operator as a row | `instruction-cleanup.md` The pass, The judgement, The screen |
| `The runbooks` and `Creating the shells` stay in the pass until the base skills exist to receive them | the pass is the artifact's only author until its first fold, and a contract in a skill that does not exist has no home; the pass's own placement test extracts on the second consumer | `instruction-cleanup.md` The runbooks, Creating the shells |
| The prompt carries no list of its agent-written sections; authorship is recorded in this handover instead | a prompt's reader needs the rules, not an audit of who supplied the words, and the list decayed within a day of the rename it named | `instruction-cleanup.md` The wording |
| The pass creates both skill shells and files a missing runbook as a coverage gap | a shell is structural and a review prompt is improvement, which the pass refuses | `instruction-cleanup.md` Creating the shells |

## Decisions pending

None. The audits line settled on invocation rather than subject, and a missing base runbook is a coverage gap rather than a question.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The Milestone Summary shows M3.6.4 and M3.6.5 as `In progress` while their commits live only on unmerged branches | record | a reader takes the milestone for further along than the tree is, and M3.4 was just filed for the same reason | flagged at the scope gate; the row edit is M3.6's or this iteration's write-back, at the operator's choice |
| The milestone summary for M3.2.2 was `Not started` against an opened milestone | record | corrected in the opening commit, before this handover existed | the opening commit `43942db7`, recorded here |
| The rewrite-provenance judgement was raised mid-iteration and lands as a sidequest, [`20261025-02-workflow-rewrite_syntax_principle.md`](20261025-02-workflow-rewrite_syntax_principle.md) | record | the judgement governs every rewrite of the operator's wording, so it is a durable outcome the M3.2.2 leftover does not own; this handover's Completed rows for the principle, `AGENTS.md` and `skill-scaffolder` move to that handover | the sidequest |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../roadmap.md) | the promotion check: M3.2.2's summary row set to `In progress` when the milestone opened, in commit `43942db7` |
| [`devlog/discussions/20261025-design-active-counterparty_check_scope.md`](../discussions/20261025-design-active-counterparty_check_scope.md) | the design record: the three gateless sites, the eight checks, the verdict and the rows it refines |
| [`workflow/coding-agent/prompts/instruction-cleanup.md`](../../workflow/coding-agent/prompts/instruction-cleanup.md) | the reusable cleanup procedure, settled: the order of work, the census's unit of logic and seven kinds, the co-change test that places a shared rule, the provenance register graded reason and proof, the four faults with a flag route for the one the agent cannot name yet, the three screen sets and the two shapes, the runbook contract with its scopes and focus, the fold, and the shells -- no open questions left |
| [`docs/adr/coding_agent_loop_workflow.md`](../../docs/adr/coding_agent_loop_workflow.md) | registered as an active-operator prompt beside `/iter`, `/plan` and `/document` |
| [`devlog/roadmap.md`](../roadmap.md) | the procedure's row reworded to the four faults as one vocabulary, the comparison draft filed, and the census instrument's gate filed dormant |
| [`.agents/drafts/instruction-cleanup-goal-only.md`](../../.agents/drafts/instruction-cleanup-goal-only.md) | the same task stated as a goal alone, for a comparison of a detailed runbook against an abstract goal |
