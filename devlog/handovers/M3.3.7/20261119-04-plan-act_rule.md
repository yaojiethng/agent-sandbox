---
date: 2026-11-19
milestone: M3.3.7 - The principle corpus admission
type: Plan
status: Closed
---

# Handover - The act a sentence performs, and the rows that name it

## Objective

Settle the act rule's subject and its requirements, so the implementation runs with its ground fixed. The implementation is deferred: the unit vocabulary landed first, in [`20261119-05`](20261119-05-impl-language_unit.md).

## Scope

The act a sentence performs is hidden by the form that carries it. A directive written as a statement of state makes the reader infer the act, and an explanatory sentence carrying an imperative claims a duty it has no ground for. ASD-STE100 Issue 9 Rule 5.3 and Section 6 keep the rule from the voice rule, and the Google style guide states it for a procedural step.

The operator's note found the defect inside this iteration's own record. The act item's header states a condition rather than the work, and `devlog/roadmap.md` does so 30 times in 39 rows of the active sub-milestone. Ten rows name no class. So the rule lands with the convention whose rows break it, and the rows this iteration writes are its first carriers.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The act rule and the voice rule stand as two roadmap items, each with its source, its requirements and its dropped parts. | `grep -c "Write the act rule\|the act a sentence performs" devlog/roadmap.md` and the voice row beside it. | Not yet. |
| The draft leaf, its index line and its edge are gone from the tree and the installed copy. | The corpus gate reads 27 principles, and the skill directory is absent in both roots. | Not yet. |
| The task-list convention's row defects are recorded, with the count that shows them. | The Findings table holds the 30-of-39 header defect and the 10 rows naming no class. | Not yet. |
| The act item names the unit vocabulary as its dependency, so its implementation cannot land on an undefined unit. | The act item carries `Depends on:` the language unit row. | Not yet. |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The row-wording rule lands in `task-list`'s `Task granularity` paragraph, not in a new section. | The paragraph already decides what a row states; a new section would be a second home for one rule. | Pending. |
| The pointer names three principles, each on evidence from this milestone's own rows. | Headers state a condition 30 times in 39 rows, which is the act rule's defect; the rows instruct the method, which is `state-intent-delegate-method`'s; the rows carry dropped-framing prose, which is `cut-metadiscourse`'s. | Pending. |
| The remaining headers and the ten class-less rows are one filed row, not this iteration's sweep. | 40 repairs carry 40 judgements about what each row's work is, which is a sweep of its own and not a leaf admission. | Pending. |
| The rule is admitted at its own leaf rather than folded into `attach-as-you-read`. | The sources keep voice and clause type in separate sections, and the imperative has no voice contrast, so the merge would apply a voice rule to a form without voice. | Pending. |

## Decisions pending

| Question | Options | Recommendation |
|---|---|---|
| The slug | `communication-principle-say-what-the-sentence-asks`, `communication-principle-name-the-act-in-the-verb`, `communication-principle-make-the-ask-visible` | the first, since it carries the zero case where a sentence asks nothing |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The operator's instructions use "imperative" and "active voice" in four senses, and three of them already have owners. | Evidence | A correction that reads as one ask is four: voice, which is `attach-as-you-read`'s; intent-not-method, which is `state-intent-delegate-method`'s; the sentence's single line, which is `single-train-of-thought`'s and `attach-as-you-read`'s; and the act, which has no owner. | The split table in this record. |
| The operator's own term for the principle is "active voice, action forward". | Evidence | The mined log holds "action forward" from `2026-11-19 07:19` and the two-part decomposition from `2026-11-15 19:12`, "clarity of sentence intent ... as well as grammatical expression", which places the act rule in the grammatical half. | The action ask, as a name candidate. |
| The active sub-milestone's rows state a condition rather than the work, 30 times in 39 rows, and 10 name no class. | Record | The convention the rows are filed under states neither rule, so a compliant row cannot be told from a habitual one. | This iteration's `task-list` pointer, and the filed sweep row. |

## Completed

| File | One-line change summary |
|---|---|
| [`devlog/handovers/M3.3.7/20261119-04-impl-act_rule.md`](devlog/handovers/M3.3.7/20261119-04-impl-act_rule.md) | This record opens the iteration. |
| `devlog/roadmap.md` | Roadmap maintenance ran at the scope gate: markers, nesting and class compliance were checked across the active sub-milestone, and the two defects in the Findings table were reported. |
