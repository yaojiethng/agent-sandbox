# The principle corpus, a first map

**Status:** open
**Date:** 2026-11-16
**Procedure:** [`.agents/skills/instruction-authoring/references/corpus-survey.md`](../../.agents/skills/instruction-authoring/references/corpus-survey.md)
**Census:** [`20261116-report-open-principle_link_census.md`](20261116-report-open-principle_link_census.md)
**Dry run:** [`20261116-report-open-reader_context_dry_run.md`](20261116-report-open-reader_context_dry_run.md)

## What this is

The full survey over the 25 repo-owned principles, first pass. The dry run settled the rule. Each card has one **root defect** and a **remedy**. The family is the root defect. A card whose remedy lives on the other axis carries an **RT** to that axis. The map is provisional, and the operator's review is its acceptance.

## The cards

| Card | Family | Root defect | Remedy | Straddle |
|---|---|---|---|---|
| `define-terminology-before-use` | Context | the term is ambiguous | define before use | RT progressive |
| `write-for-the-reader` | Context | the referent is in the session | state it, or link the record once | RT progressive |
| `link-what-the-reader-can-open` | Context | the target is unreachable | dispatch to a reachable target | RT progressive |
| `attach-as-you-read` | Context | the phrase arrives before its structure | order the phrase after its structure | RT correct |
| `single-train-of-thought` | Context, RT | two lines at once | carry one line | RT context |
| `keep-a-subject-near` | Context, RT | the subject parts are apart | colocate them | RT context |
| `single-source-of-truth` | Source | a copy carries one subject and mode | name the owner, or delete the copy | RT correction |
| `minimal-corrections` | Source | a correction adds artifacts | one artifact | RT correction |
| `propagation-discipline` | Source | a carrier asserts the old state | sweep every carrier | RT correction |
| `show-dont-describe` | Grounding | a description where an artifact would do | give the artifact | -- |
| `only-derive-what-you-own` | Grounding | a derived value with no source | state the primary data, or name the source | -- |
| `name-the-value-not-a-literal` | Grounding | a literal reads as the chosen value | name the field | -- |
| `dont-forecast-undone-work` | Grounding | a forecast with no task | name the task, or write a gap | RT task-holding |
| `state-intent-delegate-method` | Instruction scope | the method is over-specified | state the intent, delegate the route | -- |
| `match-precision-to-stakes` | Instruction scope | the precision does not match the stakes | name the assumption, gap, undo and reporter | -- |
| `one-addressing-axis` | Instruction scope | two axes in one list | one axis per presentation | -- |
| `rewrite-syntax-never-semantics` | Instruction scope | a rewrite changes the meaning | change syntax, raise semantics | -- |
| `cut-what-serves-nothing` | Instruction scope | a sentence serves another mode | cut it and point at the owner | RT task-holding |
| `maximize-conceptual-leverage` | Instruction scope | the text has no leitwort | one word, defined once | RT terminology |
| `align-the-mental-model` | Instruction scope | a word and a thing disagree | one word for one thing | RT terminology |
| `check-placement` | Check placement | a check runs before its evidence | place it at the input | -- |
| `guard-the-context-window` | Check placement | a capacity claim has no reading | name the reading, unit and count | -- |
| `justify-materialization-cost` | Check placement | a stored copy has no cost or gate | derive, or materialize and gate | -- |
| `approval-writes-the-artifact` | Landed work | a decision lives in chat | write the source file | RT task-holding |
| `say-what-done-looks-like` | Landed work | work has no stated finish | name the inventory, bound and criterion | RT task-holding |

## The families

| Family | Root defect | Cards |
|---|---|---|
| Context disclosure | the reader lacks the context, or gets it in the wrong order or amount | 6 |
| Source | a copy or a carrier holds a state that another unit owns | 3 |
| Grounding | the text asserts what the reader cannot check or act on | 4 |
| Instruction scope | the instruction's meaning or scope is wrong | 7 |
| Check placement | a check or resource is placed or measured wrong | 3 |
| Landed work | a decision or a finish is not in the artifact | 2 |

## The edges

The only clear BT hierarchy is the reader-context cluster. `context disclosure` is the BT of `correct disclosure` and `progressive disclosure`. The context cards are NTs under the axis of their root defect, with an RT to the remedy axis.

The other families carry no BT umbrella yet. Their cards are RT within the family, and the cross-family RT groups are these:

- **Terminology.** `define-terminology-before-use`, `align-the-mental-model`, `maximize-conceptual-leverage`.
- **Correction.** `single-source-of-truth`, `minimal-corrections`, `propagation-discipline`.
- **Task-holding.** `dont-forecast-undone-work`, `say-what-done-looks-like`, `approval-writes-the-artifact`.
- **Cut's second rule.** `cut-what-serves-nothing`, `single-train-of-thought`, `single-source-of-truth`.

These are RT edges, not hierarchies, and they are pair-local.

## The docket

| Case | Parties | Issue | Status |
|---|---|---|---|
| D3 | `write-for-the-reader` | Is it a correctness card with a progressive remedy, or a merge into the umbrella? | resolved: correctness root, RT to progressive |
| D4 | the terminology trio | Is the terminology concern one family, or three cards that share a word? | open |
| D5 | the correction trio | Is the correction concern one family, and is `approval-writes-the-artifact` part of it? | open |
| D6 | the task-holding trio | Is the task-holding concern one family, or three cards that share a task? | open |
| D7 | `cut-what-serves-nothing` | Does its second rule, the sediment test, split into its own principle? | open; the roadmap row owns it |
| D8 | `keep-a-subject-near` | Does the card carry `colocation` as its leitwort? | open; the roadmap row owns it |

## Review packet

Review in three passes. Each pass has one question and the evidence it needs. The map is a proposal. Until you reason through it, your view and mine are the same.

### Pass 1, the context cluster

**Question.** Do the four NTs and two RTs hold, with `context disclosure` as the BT?

| Card | Root defect | Test core |
|---|---|---|
| `define-terminology-before-use` | the term is ambiguous | Point at the definition of each term the sentence relies on. |
| `write-for-the-reader` | the referent is in the session | Would the reader need the session to use it? |
| `link-what-the-reader-can-open` | the target is unreachable | For each pointer, does the target exist where the reader reads the text? |
| `attach-as-you-read` | the phrase arrives before its structure | At each phrase, can it attach to structure already built? |
| `single-train-of-thought` | two lines at once | Does each sentence advance the line the previous sentence was on? |
| `keep-a-subject-near` | the subject parts are apart | At each caveat, does the reader still hold the rule it qualifies? |

**Decision.** The cluster's shape. The umbrella, the two axes, and the four NTs against the two RTs.

### Pass 2, the five other families

**Question.** Does each card's root defect put it in the family the map gives it?

| Family | Card | Test core |
|---|---|---|
| Source | `single-source-of-truth` | Name the subject and the mode, then the unit that owns that pair. |
| Source | `minimal-corrections` | How many artifacts does this correction produce? |
| Source | `propagation-discipline` | Name every file that still asserts the old state. |
| Grounding | `show-dont-describe` | Must the reader interpret, or can they copy? |
| Grounding | `only-derive-what-you-own` | Point at where each value comes from. |
| Grounding | `name-the-value-not-a-literal` | Does the snippet carry a value the reader must choose? |
| Grounding | `dont-forecast-undone-work` | Name the task that owns the work. |
| Instruction scope | `state-intent-delegate-method` | Which decisions does the draft leave to the doer? |
| Instruction scope | `match-precision-to-stakes` | Name the assumption, the gaps, the undo path and the reporter. |
| Instruction scope | `one-addressing-axis` | Count the axes in the presentation. |
| Instruction scope | `rewrite-syntax-never-semantics` | Would the words allow a task the writer did not intend? |
| Instruction scope | `cut-what-serves-nothing` | Name the document's mode. |
| Instruction scope | `maximize-conceptual-leverage` | Is there one word the reader will carry away? |
| Instruction scope | `align-the-mental-model` | Could a reader place the word on a second thing? |
| Check placement | `check-placement` | Name the record the check reads and the gate that owns its decision. |
| Check placement | `guard-the-context-window` | Name the reading that supports the claim. |
| Check placement | `justify-materialization-cost` | What cost does materialization avoid? |
| Landed work | `approval-writes-the-artifact` | Point at the file, and the diff that put the artifact in it. |
| Landed work | `say-what-done-looks-like` | Point at the inventory, the bound and one criterion. |

**Decision.** The family boundaries. Name any card that belongs in two.

### Pass 3, the docket

**Question.** Which cases settle now, and which stay?

| Case | Parties | Issue |
|---|---|---|
| D4 | the terminology trio | Is the terminology concern one family, or three cards that share a word? |
| D5 | the correction trio | Is the correction concern one family, and is `approval-writes-the-artifact` part of it? |
| D6 | the task-holding trio | Is the task-holding concern one family, or three cards that share a task? |
| D7 | `cut-what-serves-nothing` | Does the sediment test split into its own principle? |
| D8 | `keep-a-subject-near` | Does the card carry `colocation` as its leitwort? |

**Decision.** Each case's status. A stay is acceptable.

### Review record

| Pass | Date | Result |
|---|---|---|
| Pass 1, the context cluster | 2026-11-16 | holds. The BT is `context disclosure`, the NTs are `correct disclosure` and `progressive disclosure`, and the four NTs and two RTs stand as mapped. The umbrella name is `context disclosure`, and `progressive context disclosure` is retired. |
| Pass 2, the five other families | 2026-11-16 | rejected. The families are keyed on the root defect, which is the trigger, not the skill's intent. The revision keys the family on the intent and keeps the defect as the axis within it; it is under review. |

The confirmed Pass 1 shape supersedes the `progressive context disclosure` premise in the roadmap's cluster row. That row's landing iteration carries the rewrite.

The families table above is the rejected first cut. It is kept as the record of what was rejected, not as the map. The dry run's model was family equals intent, with the defect as the axis within the family; the full map made the defect the family, and the intent was lost.

Pass 2's replacement is now materialized. The five reader-context skills carry the operator's `metadata.intent` and `metadata.mechanism`, and the convention and shape record state the rule. `write-for-the-reader` and `link-what-the-reader-can-open` share the intent and differ in the mechanism, so the intent is the family and the mechanism is the axis. The remaining 20 await the operator's ratification.

### Settled, provisional, not decided

Settled by the dry run: the root-defect rule, the RT rule, and the context cluster's two-axis model. Provisional: the six family boundaries and the cross-family RT groups. Not decided: the field values, the cluster rewrite, the link normalisation.

## What the map says

The method held at 25 scale. It produced six families, four cross-family RT groups and six cases from 25 cards, and it did so without closing an RT edge or forcing a merge. The reader-context cluster is the only family with a clear umbrella. The other families need a decision on whether they have one.

The map also supports the cluster reorganization you named. The reader-context cards are clean once the root defect and the remedy are separated, and the umbrella is `context disclosure`, not `progressive context disclosure`.

## Limits

The classification reads the descriptions and the test sentences, not the whole bodies. A card's family is a judgement, and the operator's review is the acceptance. The field stays `[]`; this map is not the field.
