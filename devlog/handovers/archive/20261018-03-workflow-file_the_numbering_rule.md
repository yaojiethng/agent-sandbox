---
date: 2026-10-18
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - File the numbering rule per document class

## Objective

State one numbering rule that a writer applies while drafting, with a scheme declared per document class, the unit letters defined, the chat label form, the write-back rule, and a gate over the three violations a machine can see.

## Scope

The rule is a project convention skill, because a writer applies it mid-draft and discovers it by description. The taxonomy gains a descriptive column naming each class's scheme, so the class decides without a per-unit decision at write time. A small gate enforces contiguity and reference resolution. One real duplicate section number is renumbered, which is the first edit the rule caused.

Not in scope: the pointer work that removes the four restatements of the rule, which is the next iteration; the roadmap's task-row identity, which belongs to M3.5; and any allocator, resolver or baseline.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| One skill states the criterion, the per-class table, the forms, insertion and the flow direction | `.agents/skills/numbering/SKILL.md` | Accepted |
| Each of `F`, `Q`, `D`, `R` is defined once, in a table | `numbering_skill_defines_every_letter` | Accepted |
| A reply's items take a group letter and a position, `A1` | the skill's `## Chat: one token per item` | Accepted |
| A chat label does not become a reference in the record | the skill's `## Write-back`, with the worked `D2` line | Accepted |
| Every rule cites the story it serves, and every story is served | `numbering_skill_rules_cite_a_story`, `numbering_skill_stories_are_served` | Accepted |
| A gap, a repeat and a dangling qualified reference fail | `tests/test_numbering.sh`, 12 cases | Accepted |
| A fenced block, a plain list and a closed archive tree carry no finding | cases `prose` and `archive` | Accepted |
| The gate is green on the tree after one real fix | `bash scripts/lint.sh` clean across 10 gates; the fix is `1.14` twice in `bash-coding-conventions.md` | Accepted |
| The suite is green | `bash scripts/run_tests.sh`, 1227 of 1227 | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The scheme is declared per class, not per unit | The criterion is a property of how the class is read, so one declaration per class makes the schemes consistent without a decision at write time. | the skill; the taxonomy column |
| Numbers for the audit report, identity codes for the task list | Findings are read in order and cited in place; roadmap rows are unordered and long-lived, and `T3` was retired without renumbering the rest. | the census record, criterion table |
| Four letters, not six | A finding, a question, a decision and a recommendation are the four units a record cites. An acceptance criterion is a table row that is checked, not cited; if a record cites one, it is a recommendation. | the skill's unit-letter table |
| A reply groups its choices and names each item `A1` | The inherited policy sentence forbade two axes and gave no mechanical form. A group letter plus a position makes a token unique inside the reply. | the skill's chat section |
| A chat label survives in a record at most once, as provenance | A label alone is unusable later. The record states the decision with a `D` number and quotes the label with its session. `option B` is the same defect, and the feedback record already carries it. | the skill's write-back section; `AGENT_FEEDBACK.md` |
| An open document renumbers on insert; a closed record appends | A closed record's numbers are frozen by `documentation_policy.md` `## Record maintenance`, so a new unit takes the next free number and may sit above a lower one. | the skill's insertion section |
| The check holds no baseline and no counter | A number is contiguous from 1 inside its scope, so a gap is the whole signal. A baseline would recreate the maintenance surface the operator rejected. | `scripts/lint/numbering.mjs` header |
| Historical trees are out of the check | An archive is a closed record; the rule bounds what is written now. | the skip list |
| The section check engages only on an uninterrupted numbered run | Two of the first three findings were prose enumerations beginning with a number. An unnumbered heading inside a depth means the numbers are not sections. | `numbering.mjs`; the `1.14` fix that survived |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Does the roadmap task row adopt a code now, or wait for M3.5? | whether a roadmap row can be cited as `M3.3.4/2` | adopt now; wait; a `T`-style code |
| Do the 130 state-bearing names get renamed to identity names? | whether a reference can name those records at all | rename; leave |
| Does a recommendation that becomes a task keep its `R` number, or gain a roadmap code? | the hand-off between an audit report and the roadmap | keep and add; gain only |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The live tree holds no finding, question, decision or recommendation unit: all 78 are in the archive. | measurement | The unit check is forward-looking. It costs nothing today and binds the first audit report written under the rule. |
| 17 documents number sections and the series is contiguous after one fix. | measurement | Section numbering is the only scheme with a live population, so it is where the gate earns its place now. |
| `bash-coding-conventions.md` carried `1.14` twice, and the series ran to `1.18` after it. | measurement | The first real defect the rule removed: five headings renumbered, no inbound anchor pointed at them. |
| Two of the first three section findings were prose enumerations, not section numbers. | diagnosis | A cheap check must distinguish a series from an enumeration, or it charges the writer for the checker's confusion. |
| The skill used the four letters before any table defined them. | diagnosis | An abbreviation a reader must infer is not a rule; the unit-letter table fixes it and a test keeps all four present. |

## Completed

| File | Change |
|---|---|
| [`.agents/skills/numbering/SKILL.md`](../../../.agents/skills/numbering/SKILL.md) | the rule: criterion, letters, per-class table, chat labels, write-back, insertion, flow, stories, cost |
| [`documentation_taxonomy.md`](../../../docs/reference/documentation_taxonomy.md) | an `Identification` column, and the convention named as the scheme's home |
| [`bash-coding-conventions.md`](../../../docs/development/bash-coding-conventions.md) | the second `1.14` becomes `1.15`, and the following headings shift by one |
| [`numbering.mjs`](../../../scripts/lint/numbering.mjs) | the three checks, one document at a time, no baseline |
| [`check_numbering.sh`](../../../scripts/check_numbering.sh) | the gate wrapper |
| [`lint.sh`](../../../scripts/lint.sh) | the gate joins the umbrella, 10 gates |
| [`test_numbering.sh`](../../../tests/test_numbering.sh) | twelve cases: units, sections, references, prose, archive, and three reading the skill |
