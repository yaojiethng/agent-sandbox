---
date: 2026-11-17
milestone: M3.3.7 - The principle corpus admission
type: Workflow
status: Closed
---

# Handover - The change is a discussion, and the agent scaffolds the evidence

## Objective

Rewrite the change runbook so it describes the discussion, the presentation, the butler pass, the supplement and the write, in the operator's structure and imperative voice, and so that the evidence each decision needs is scaffolded rather than improvised.

## Scope

Continues the interrupted [`20261117-08`](20261117-08-impl-produce_on_demand.md), which cannot write its principle until the procedure that writes it matches the way the operator works. The interruption is recorded in its Findings.

The work is the runbook, the reference paragraph it contradicts, and the ADR entry that recorded the superseded model. The principle row 390 stays open and takes its butler pass after this lands.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The runbook carries the operator's structure: a discussion, a presentation the operator releases, a butler pass, the supplement, and the write. | Read the headings in order against the five decisions the operator named, and check each decision names what the operator decides and the evidence the agent brings. | Agent verified. |
| The write follows the supplement, so no part of the skill is written before the judgement settles. | Read `## Take the supplement, write the file, and hold it for review` and the `## Hold the write` bullet above it. | Agent verified. |
| The reference states the dictation split, and gives `**Why.**` the motivation-first direction. | Read `principle-skills.md`'s operator-led paragraph and its `## The body` section. | Agent verified. |
| The ADR supersedes the entry that made the operator the writer, and records both rejected models with their failure locus. | Read the 2026-11-17 entry beginning "The operator dictates a principle"; the earlier entry reads `Status: historical` and points at it. | Agent verified. |
| The runbook carries no faux numbering, leads with the act where a prohibition stood, and speaks in the imperative. | Read each heading and bullet; the phrases "three acts", "in order", and "not evidence" are absent. | Agent verified. |
| Every decision this iteration records is realized in the files. | Read each `## Decisions` row against the tree. | Agent verified. |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A change is a discussion with five operator decisions, and the agent writes the file under the operator's words. | The judgement is the operator's and the writing is the agent's, and `communication-principle-rewrite-syntax-never-semantics` separates them. A procedure that assigns the writing to the operator makes the operator type what the agent reflows. | This record; the ADR's 2026-11-17 entry. |
| The five decisions are subjects, taken in any order and reopened freely. | The operator stated the order is not prescribed, so a fixed sequence misdescribes the work. | This record; the runbook's first section. |
| A butler pass sits between the presentation and the write. | It mines the discussion for answers already given, gathers the placement evidence the proto-skill makes possible, and lists the gaps the operator supplements. Without it the write improvises the research. | This record; the runbook's third section. |
| The runbook is written in nested self-contained levels, in the imperative, leading with the act. | The operator supplied the format and the three style rules, and the file is read by an agent that runs it. | This record; the runbook. |
| The wording alone raises no roadmap row; the procedure change does. | A row records work no other row holds, and the wording is part of the procedure change. | The roadmap row below. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The 09 sidequest recorded "every part of a principle skill is written by the operator" in the runbook, the reference and the ADR. The operator reversed it: the agent writes and the operator dictates. | contradiction | Three carriers stated a procedure the operator does not use, and the runbook's `## The sequence` asked the operator to state each part. | All three updated here; the ADR entry is marked historical. |
| A borrowed domain term has no home. The runbook asks the operator to pick the field and its terms, and nothing says whether the term goes into `docs/reference/terminology.md` or stays in the skill. | gap | A change that borrows a term has to decide the same question again, and the registry and the skill can each end up carrying it. | The next change that borrows a term, which is row 390's butler pass if it takes one. |
| `docs/adr/principle_skill_shape.md` orders its entries by date except where the 2026-11-16 intent-and-mechanism entry sits after a 2026-11-17 entry. | drift | A reader scanning for the current state meets an older decision above a newer one. | `/milestone-close`, with the other ADR maintenance. |

## Completed

| File | One-line change summary |
|---|---|
| [`.agents/skills/instruction-authoring/runbooks/principle-change.md`](../../../.agents/skills/instruction-authoring/runbooks/principle-change.md) | Rewritten as the discussion, the presentation, the butler pass, the supplement and the write, in nested self-contained levels. |
| [`.agents/skills/instruction-authoring/references/principle-skills.md`](../../../.agents/skills/instruction-authoring/references/principle-skills.md) | The dictation split replaces the operator-writes paragraph, and the body section gains the `**Why.**` direction. |
| [`docs/adr/principle_skill_shape.md`](../../../docs/adr/principle_skill_shape.md) | A 2026-11-17 entry records the split and the rejected models; the entry it supersedes is marked historical. |
| [`devlog/roadmap.md`](../../roadmap.md) | The procedure row closes, and the parent's row stays open. |
| [`devlog/handovers/M3.3.7/20261117-08-impl-produce_on_demand.md`](20261117-08-impl-produce_on_demand.md) | Its Findings names this sidequest and the reason for the interruption. |
