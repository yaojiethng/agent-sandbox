---
date: 2026-11-17
milestone: M3.3.7 - The principle corpus admission
type: Workflow
status: Closed
---

# Handover - The operator writes a principle, and the agent scaffolds the questions

## Objective

Rewrite the corpus's change procedure so the operator writes every part of a principle skill and the agent supplies the questions, the evidence and the checks.

## Scope

One continuation line: this sidequest interrupts [`20261117-08-impl-produce_on_demand.md`](20261117-08-impl-produce_on_demand.md), which stays `Active` and resumes after this close.

The interrupted iteration's Findings records the contradiction this sidequest answers. The procedure changed here, and the principle that iteration adds is not part of this scope.

The corpus's change procedure is [`runbooks/principle-change.md`](../../../.agents/skills/instruction-authoring/runbooks/principle-change.md). Its five steps assign the generative work to the doer. The operator states the opposite intention: every part of a principle skill is written by the operator, and the agent scaffolds and asks.

The general authoring procedure is agent-authored by design, [`SKILL.md`](../../../.agents/skills/instruction-authoring/SKILL.md) steps 3 and 4, so a silence in the principle runbook defaults to the agent writing. This sidequest makes the departure explicit where the doer reads it.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The runbook asks and generates nothing, and each question names what the agent brings. | `grep -nE "^[0-9]+\. \*\*(Name\|Find\|Settle\|Collect\|Land)"` on the runbook prints nothing; each question's third column names a command or a path. | [x] Accepted. The grep prints nothing and the table carries one row per part. |
| The reference states authorship for every part, and the two-field sentence is gone. | `grep -c "operator-led" references/principle-skills.md` prints 0; `grep -n "written by the operator"` prints the general rule. | [x] Accepted. 0 and 1. |
| A doer reading `SKILL.md` step 2 meets the departure. | `grep -n "written by the operator" SKILL.md` prints the clause, and it names the runbook. | [x] Accepted. Step 2's principle clause carries both. |
| The ADR records the authorship decision and the alternative it rejected. | Read the 2026-11-17 entry's Rejected list. | [x] Accepted. It names agent-drafted proposals as an intent failure, an operator form as a boundary failure, and the two-field rule as an execution failure. |
| Every decision this sidequest records is realised in the files. | Read each `## Decisions` row against the tree. | [x] Accepted. |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The defect is structural, not a missing sentence. | Three of the runbook's five steps are the generative act, the operator enters at step 4, and the ruling arrives after the draft. | This record; the parent's Findings row. |
| The authorship rule is generalised from `intent` and `mechanism` to every part. | The reference's paragraph is the only place that states authorship, and it carries the two fields the ADR's 2026-11-16 entry names. A rule about two of six fields leaves four to the default. | This record; the reference. |
| The procedure's questions replace its steps, and the answers are recorded as they arrive. | The operator's words must survive a context loss, and the record is the trace the diff is checked against. | This record; the parent's write-back rule. |
| The runbook's `## Steps` becomes `## The sequence`, and the three rules sit under it. | The steps no longer exist, so a heading named for them is a stale carrier, and the sequence's rules have no other home. | This record; the runbook. |
| `## What a change owes the record` shrinks to the answers, the case, the edge and the witness. | The nearest set and the decision are the answers themselves, so a list that repeats them is a second source. | This record; the runbook. |
| The question table's third column names the command or path the agent brings. | The agent's contribution is evidence rather than prose, and a column that states it is checkable at the gate. | This record; the runbook. |
| The authorship entry sits above the reference-split entry in the ADR. | Both landed on 2026-11-17 and the later change is authorship, so the file reads newest first by the date it shares. | This record; the ADR. |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| The proposed question sequence, its three rules and the two replacement sentences. | Every file in this iteration. | Released as presented, or amended. |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `SKILL.md` step 3 says the operator's clauses keep their meaning and the drafter keeps the arrangement, which reads as licence for the agent to draft a principle skill. | contradiction | The general procedure and the intended one give opposite answers for the same artefact, and the general one is read first. | The step's principle clause. It now reads "written by the operator, so the runbook carries a question sequence and this procedure's drafting steps do not apply". |
| The runbook's intro, its `## Steps` heading and its closing list all described an agent-authored procedure, so the change reached three paragraphs beyond the steps it replaced. | propagation | A procedure edit that stopped at the step list would have left the file asserting authorship it no longer gave. | This record; the runbook's intro and its closing section. |

## Completed

| File | One-line change summary |
|---|---|---|
| `.agents/skills/instruction-authoring/runbooks/principle-change.md` | The five steps become a question sequence, with three rules, and the intro and closing section follow. |
| `.agents/skills/instruction-authoring/references/principle-skills.md` | Authorship generalised from `intent` and `mechanism` to every part. |
| `.agents/skills/instruction-authoring/SKILL.md` | Step 2 names the departure and the runbook that carries it. |
| `docs/adr/principle_skill_shape.md` | New entry: the operator writes every part, with the alternatives it rejected. |
| `devlog/roadmap.md` | A row states the defect and its landing. |
| `devlog/handovers/M3.3.7/20261117-09-workflow-operator_authors_principles.md` | This record. |
