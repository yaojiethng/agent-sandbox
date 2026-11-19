---
date: 2026-11-18
milestone: M3.3.7 - The principle corpus admission
type: Workflow
status: Closed
---

# Handover - The change runbook writes each decision as it settles

## Objective

Make the change runbook write a principle into its file as each decision settles, so an approved part never waits in the conversation.

## Scope

Continues the close of [`20261117-08`](20261117-08-impl-produce_on_demand.md), whose Findings filed this row: the runbook holds the file until the discussion ends, and the iteration that just closed landed its principle in three pieces across a dozen turns because of it.

The work is [`principle-change.md`](../../../.agents/skills/instruction-authoring/runbooks/principle-change.md) and the carriers that describe the write. The judgement is [`principle-approval-writes-the-artifact`](../../../../.pi/agent/skills/principle-approval-writes-the-artifact/SKILL.md), which the runbook contradicts.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No section of the runbook tells the reader to hold the file until the discussion ends. | Search the runbook for "hold" and read every hit against the rule: a hold that defers the write is a finding. | Accepted. One hit, `**Hold the finished file for review.**`, which holds a finished artifact for a reader. |
| The write is stated once, as a standing rule, and each step writes without restating it. | Read `## Write discipline` and the four step sections: the rule appears at the top and no step repeats its reasoning. | Accepted. Two bullets at the top, and the steps carry their own actions only. |
| The presentation the operator releases is the file, which stands as the proto-skill. | Read the presentation section against the rule: it names the file, not a draft. | Accepted. The release makes the file the proto-skill. |
| `principle-skills.md` agrees that the agent writes each part as the operator dictates it. | Read its operator-led paragraph against the runbook's. | Accepted. It says the agent writes the file, and the runbook's lead says the same, so neither needed an edit. |
| Every decision this iteration records is realized in the files. | Read each `## Decisions` row against the tree. | Accepted. |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The runbook writes each settled decision into the skill file, and the file lands incomplete. | `approval-writes-the-artifact` holds the rule the runbook breaks: a decision kept in the conversation cannot be reverted, resumed or checked, and the iteration that closed showed the cost. | This record; the runbook. |
| One `## Write discipline` section states the standing rules, and the steps stop restating them. | Four section-level patches said one thing six times, which is the smell the operator named. A rule stated once at the top and cited by the owner leaves each step describing only itself. | This record; the runbook. |
| The section carries no count and no announcement line. | `only-derive-what-you-own` refuses a total computed from a list that lives elsewhere, and `cut-metadiscourse` refuses a sentence that talks about the section. | This record; the runbook. |
| The dictation split stays in the lead paragraph and leaves `## Write discipline`, and the record rule leaves the discussion step. | Both were the same rule twice in one document. The lead states the split where a reader starts, and the standing rule keeps the rationale the step bullet carried. | This record; the runbook. |
| The consolidation is net shorter: the release bullet joins its paragraph and the record's six label bullets become one sentence. | A section that states a rule once should leave the file smaller than the clauses it replaced. Both cuts removed a list where each item was a label rather than a claim. | This record; the runbook. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The write rule needed six scattered edits before the standing-rules section existed. | Plan | The first four sections each gained a clause about when to write, and the sweep for criterion 1 then found two more holds in the lead and the butler pass. The operator called the edit count a smell and asked for a `## Write discipline` section. | Fixed here: the six edits revert to one section of two bullets. |

## Completed

| File | One-line change summary |
|---|---|
| [`.agents/skills/instruction-authoring/runbooks/principle-change.md`](../../../.agents/skills/instruction-authoring/runbooks/principle-change.md) | Gains `## Write discipline`; the hold leaves the discussion and butler steps; the release bullet and the record list are folded. 72 to 66 lines. |
| [`devlog/roadmap.md`](../../roadmap.md) | The row closes with its landed summary. |
| `devlog/handovers/M3.3.7/20261118-01-workflow-write_the_file_as_it_settles.md` | This record. |
