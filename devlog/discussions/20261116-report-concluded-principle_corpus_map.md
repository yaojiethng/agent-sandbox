# The principle corpus, a first map

**Status:** concluded
**Date:** 2026-11-16
**Procedure:** [`.agents/skills/instruction-authoring/references/corpus-survey.md`](../../.agents/skills/instruction-authoring/references/corpus-survey.md)
**Census:** [`20261116-report-concluded-principle_link_census.md`](20261116-report-concluded-principle_link_census.md)
**Dry run:** [`20261116-report-concluded-reader_context_dry_run.md`](20261116-report-concluded-reader_context_dry_run.md)

## What this is

The full survey over the 25 repo-owned principles. The dry run settled the rule. Each card has one **root defect**, the trigger, and a **remedy**. The family is the **family aim**, the higher intent the cards serve; the card's `intent` is its specific judgement; the defect is the axis within the family. A card whose remedy lives on the other axis carries an **RT** to that axis. The map is provisional, and the operator's review is its acceptance.

## The cards

| Card | Family | Root defect | Remedy | Straddle |
|---|---|---|---|---|
| `define-terminology-before-use` | Shared domain model | the term is ambiguous | define before use | RT sentence context |
| `write-for-the-reader` | Context | the referent is in the session | state it, or link the record once | RT sentence context |
| `link-what-the-reader-can-open` | Context | the target is unreachable | dispatch to a reachable target | RT sentence context |
| `attach-as-you-read` | Context | the phrase arrives before its structure | order the phrase after its structure | RT correct disclosure |
| `single-train-of-thought` | Context, RT | two lines at once | carry one line | RT context |
| `keep-a-subject-near` | Context, RT | the subject parts are apart | colocate them | RT context; co-location |
| `single-source-of-truth` | Organization | a copy carries one subject and mode | name the owner, or delete the copy | -- |
| `minimal-corrections` | Flagged for deletion | a correction adds artifacts | one artifact | -- |
| `propagation-discipline` | Organization | a carrier asserts the old state | sweep every carrier | -- |
| `show-dont-describe` | Grounding | a description where an artifact would do | give the artifact | -- |
| `only-derive-what-you-own` | Grounding | a derived value with no source | state the primary data, or name the source | -- |
| `name-the-value-not-a-literal` | Grounding | a literal reads as the chosen value | name the field | -- |
| `dont-forecast-undone-work` | Grounding | a forecast with no task | name the task, or write a gap | RT task-holding |
| `state-intent-delegate-method` | Instruction scope | the method is over-specified | state the intent, delegate the route | -- |
| `match-precision-to-stakes` | Instruction scope | the precision does not match the stakes | name the assumption, gap, undo and reporter | -- |
| `one-addressing-axis` | Instruction scope | two axes in one list | one axis per presentation | -- |
| `rewrite-syntax-never-semantics` | Instruction scope | a rewrite changes the meaning | change syntax, raise semantics | -- |
| `cut-what-serves-nothing` | Instruction scope | a sentence serves another mode | cut it and point at the owner | RT task-holding |
| `maximize-conceptual-leverage` | Shared domain model | the text has no leitwort | one word, defined once | -- |
| `align-the-mental-model` | Shared domain model | a word and a thing disagree | one word for one thing | -- |
| `check-placement` | Check placement | a check runs before its evidence | place it at the input | -- |
| `guard-the-context-window` | Check placement | a capacity claim has no reading | name the reading, unit and count | -- |
| `justify-materialization-cost` | Check placement | a stored copy has no cost or gate | derive, or materialize and gate | -- |
| `approval-writes-the-artifact` | Landed work | a decision lives in chat | write the source file | RT task-holding; RT meticulous execution |
| `say-what-done-looks-like` | Instruction scope | work has no stated finish | name the inventory, bound and criterion | RT task-holding |

## The families

The family is the family aim. The card's `intent` is its specific judgement, and the defect is the axis within the family. The five reader-context values, the shared-domain-model name and the organization aim are the operator's; the other aims are the survey's proposal awaiting ratification.

| Family aim | Cards | Defect axis |
|---|---|---|
| The reader can use the text | Context disclosure: `write-for-the-reader`, `link-what-the-reader-can-open`, `attach-as-you-read`; RTs `single-train-of-thought`, `keep-a-subject-near` | the referent, the target, the clause order, the line count, the distance |
| Shared domain model | `define-terminology-before-use`, `align-the-mental-model`, `maximize-conceptual-leverage` | the ambiguous term, the word and thing that disagree, the missing leitwort |
| The artifact has one authoritative place | Organization: `single-source-of-truth`, `propagation-discipline` | the duplicate copy, the stale carrier |
| The text carries what the reader can check or act on | Grounding: `show-dont-describe`, `only-derive-what-you-own`, `name-the-value-not-a-literal`, `dont-forecast-undone-work` | the description, the derived value, the literal, the forecast |
| The instruction means what it says and fits its doer | Instruction scope: `state-intent-delegate-method`, `match-precision-to-stakes`, `one-addressing-axis`, `rewrite-syntax-never-semantics`, `cut-what-serves-nothing`, `say-what-done-looks-like` | the over-specified method, the precision, the axes, the semantics, the purpose, the unstated finish |
| The check and its resources are measured | Check placement: `check-placement`, `guard-the-context-window`, `justify-materialization-cost` | the evidence order, the capacity claim, the stored copy |
| The decision is in the artifact | Landed work: `approval-writes-the-artifact` | the lost decision |

### The rejected first cut

Kept as the record of what was rejected. The first cut keyed the family on the root defect, which is the trigger, not the aim.

| Family | Root defect | Cards |
|---|---|---|
| Context disclosure | the reader lacks the context, or gets it in the wrong order or amount | 6 |
| Source | a copy or a carrier holds a state that another unit owns | 3 |
| Grounding | the text asserts what the reader cannot check or act on | 4 |
| Instruction scope | the instruction's meaning or scope is wrong | 7 |
| Check placement | a check or resource is placed or measured wrong | 3 |
| Landed work | a decision or a finish is not in the artifact | 2 |

## The edges

The only clear BT hierarchy is the reader-context cluster. `context disclosure` is the BT of `correct disclosure` and `sentence context`. The context cards are NTs under the BT; the root defect is the axis within the family, and the remedy axis carries the RT.

The document-load concern is `information hierarchy`. The context load is retrieval. Its failure is `overload`, its benefit is `findability`, and its moves are `progressive disclosure` (the ladder), `co-location` (the within), and `SSOT` (the source). The cognitive load is reasoning. Its failure is `extraneous load`, and its moves are the clarity rules. The cards keep `colocation` and `SSOT`; `findability` is the umbrella benefit. The [`writing-for-agents`](../../src/reasoning/agent/skills/writing-for-agents/SKILL.md) meta-skill holds the ladder, so the map records the concern rather than a card. The load-level terms are the umbrella's; a new principle that claims one defines it in its own body. The definitions follow Sweller's cognitive-load theory (1988, 1998, 2019) and the retrieval literature (information overload, Eppler and Mengis; information foraging, Pirolli and Card; findability, Rosenfeld and Morville).

The shared domain model is a family aim, not a BT. Its cards are `define-terminology-before-use`, `align-the-mental-model` and `maximize-conceptual-leverage`. The context cluster's BT stands, and `define` is a narrower term of `correct disclosure` while its family is the shared domain model.

The organization family is `single-source-of-truth` and `propagation-discipline`, RT within the family. `minimal-corrections` is flagged for deletion; its rule belongs with the ask, not the artifact.

The other families carry no BT umbrella yet. Their cards are RT within the family, and the cross-family RT groups are these:

- **Task-holding.** `dont-forecast-undone-work`, `say-what-done-looks-like`, `approval-writes-the-artifact`.
- **Meticulous execution.** `approval-writes-the-artifact`, `propagation-discipline`.
- **Cut's second rule.** `cut-what-serves-nothing`, `single-train-of-thought`, `single-source-of-truth`.

These are RT edges, not hierarchies, and they are pair-local.

## The docket

| Case | Parties | Issue | Status |
|---|---|---|---|
| D3 | `write-for-the-reader` | Is it a correctness card with a progressive remedy, or a merge into the umbrella? | resolved: correctness root, RT to sentence context |
| D4 | the terminology trio | Is the terminology concern one family, or three cards that share a word? | resolved: one family, `shared domain model`, with `define`, `align`, `maximize`; `define` keeps its `correct disclosure` broader term |
| D5 | the correction trio | Is the correction concern one family, and is `approval-writes-the-artifact` part of it? | resolved: the organization family is `single-source-of-truth` and `propagation-discipline`; `minimal-corrections` is flagged for deletion; `approval` is an RT in Landed work |
| D6 | the task-holding trio | Is the task-holding concern one family, or three cards that share a task? | resolved: an RT group, not a family; the three share a writing mechanism, and their intents differ: forecast (the just-in-time demand), say-done (dispatch alignment), approval (Landed work, with the note-taking discipline as its intent and meticulous execution as its neighbour) |
| D7 | `cut-what-serves-nothing` | Does its second rule, the sediment test, split into its own principle? | resolved: split. Part 1 is the organization principle: the Diataxis mode, with the technical concerns not conflated. Part 2 is the writing rule: trim the sediment by managing the amount of metadiscourse. They were combined by the removal-based drafting mechanism, not the aim. |
| D8 | `keep-a-subject-near` | Does the card carry `colocation` as its leitwort? | resolved: `colocation` is the leitwort; the mechanism is the placement of the parts, and `proximity` names its effect. The co-location organizes within the `information hierarchy`; the umbrella benefit is `findability`, and the failure is `overload`. The roadmap row lands the re-signpost and the name. |

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

**Question.** Does each card's intent put it in the family aim, with the defect as the axis within it?

| Family aim | Card | Test core |
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

**Decision.** The family boundaries. The operator confirmed the two-level reading: the family is the family aim, the card's `intent` is its specific judgement, and the defect is the axis. The card's intent alone would split the context cluster Pass 1 confirmed.

### Pass 3, the docket

**Question.** Which cases settle now, and which stay?

| Case | Parties | Issue |
|---|---|---|
| D4 | the terminology trio | Is the terminology concern one family, or three cards that share a word? |
| D5 | the correction trio | Is the correction concern one family, and is `approval-writes-the-artifact` part of it? |
| D6 | the task-holding trio | Is the task-holding concern one family, or three cards that share a task? |
| D7 | `cut-what-serves-nothing` | Does the sediment test split into its own principle? |
| D8 | `keep-a-subject-near` | Does the card carry `colocation` as its leitwort? |

**Decision.** Each case's status. A stay is acceptable. D4 to D8 resolved; the Pass 3 review is complete.

### Review record

| Pass | Date | Result |
|---|---|---|
| Pass 1, the context cluster | 2026-11-16 | holds. The BT is `context disclosure`, the NTs are `correct disclosure` and `sentence context`, and the four NTs and two RTs stand as mapped. The umbrella name is `context disclosure`, and `progressive context disclosure` is retired. |
| Pass 2, the five other families | 2026-11-16 | rejected. The families are keyed on the root defect, which is the trigger, not the skill's intent. |
| Pass 2, the intent axis | 2026-11-16 | holds. The operator confirmed the two-level reading: the family is the family aim, the card's `intent` is its specific judgement, and the defect is the axis. The family aims stand as the revised table. |
| Pass 3, D4 | 2026-11-16 | one family, `shared domain model`: `define`, `align`, `maximize`; `define` keeps its `correct disclosure` broader term. |
| Pass 3, D5 | 2026-11-16 | the organization family is `single-source-of-truth` and `propagation-discipline`; `minimal-corrections` is flagged for deletion; `approval` is an RT in Landed work. |
| Pass 3, D6 | 2026-11-16 | an RT group, not a family. The three share a writing mechanism; their intents differ: forecast serves the just-in-time demand, say-done serves dispatch alignment, approval serves Landed work with the note-taking discipline, neighbouring meticulous execution. |
| Pass 3, D7 | 2026-11-16 | split. Part 1 is the organization principle (the Diataxis mode; the technical concerns are not conflated). Part 2 is the writing rule (trim the sediment by managing the metadiscourse). The removal-based drafting mechanism combined them, not the aim. |
| Pass 3, D8 | 2026-11-16 | `colocation` is the leitwort; the mechanism is the placement of the parts; `proximity` names its effect. The co-location organizes within the `information hierarchy`; the umbrella benefit is `findability`, and the failure is `overload`. The roadmap row lands the re-signpost and the name. |

The confirmed Pass 1 shape supersedes the `progressive context disclosure` premise in the roadmap's cluster row. That row's landing iteration carries the rewrite.

The rejected first cut is kept under `### The rejected first cut` as the record of what was rejected, not as the map. The full map made the defect the family, and the intent was lost.

The five reader-context skills carry the operator's `metadata.intent` and `metadata.mechanism`. The values show `write-for-the-reader` and `link-what-the-reader-can-open` share an intent and differ in the mechanism, while `define-terminology-before-use`, `attach-as-you-read` and `single-train-of-thought` carry their own. So the family is the family aim and the card's `intent` is its specific judgement; the family is not the card's intent alone, which would split the confirmed cluster. The remaining 20 values await the operator's ratification.

### Settled, provisional, not decided

Settled: the root-defect rule, the RT rule, the context cluster's two-axis model, the two-level reading, where the family is the family aim and the card's `intent` is its specific judgement, the shared domain model family, the organization family, the task-holding RT, the D7 split, and the D8 leitwort. Provisional: the seven family aims and the cross-family RT groups. Not decided: the 20 field values, the cluster rewrite, the link normalisation, and the `minimal-corrections` deletion.

## What the map says

The method held at 25 scale. It produced seven family aims, three cross-family RT groups and six cases from 25 cards, and it did so without closing an RT edge or forcing a merge. The reader-context cluster is the only family with a clear BT umbrella; the other families are aims without a BT.

The map also supports the cluster reorganization you named. The reader-context cards are clean once the family aim, the card's specific intent and the defect are separated, and the umbrella is `context disclosure`, not `progressive context disclosure`.

## Limits

The classification reads the descriptions and the test sentences, not the whole bodies. A card's family is a judgement, and the operator's review is the acceptance. The remaining 20 fields stay `[]`; this map is not the field.
