---
date: 2026-11-16
milestone: M3.3.7 - The principle corpus admission
type: Design
status: Closed
---

# Handover - The principle corpus, a first map

## Objective

Apply the survey to all 25 principles and hand the operator a provisional map of seven families, their RT groups and the open cases, so the corpus organization is decided from evidence rather than from the migration's collapsing values.

## Scope

The M3.3.7 row **The full corpus survey over the 25**. In scope: the 25 cards, seven families, the reader-context BT hierarchy, the cross-family RT groups and the docket. No skill is edited and the field stays `[]`.

Out of scope: the cluster reorganization itself, the link normalisation and the cases D4 to D8, which the map dockets for a later decision.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The 25 cards, seven families, the context hierarchy, the RT groups and the docket exist in the map. | Read `devlog/discussions/20261116-report-concluded-principle_corpus_map.md`. | Agent [x] |
| The operator reviews the map and confirms or corrects the families. | The operator's reply on this handover. | Operator: Pass 1 confirmed; Pass 2 confirmed on the intent axis (reading A); Pass 3 complete (D4 to D8 resolved). |
| No principle skill is edited and the field stays `[]`. | `git diff --stat` shows no `src/reasoning/agent-runtime/pi/config/agent/skills/` file. | Agent [x] |
| Every open case is in the docket with its parties and its issue. | Read the docket table. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The map has seven family aims, and the defect is the axis within each family. | The five pilot values show the context cards carry different specific intents, while Pass 1 confirmed the cluster as a subject hierarchy. The card's intent alone would split the cluster. | This record; the map |
| The terminology trio is one family, `shared domain model`. | The three share the domain model and task intent as their aim; the words are the mechanism. `define` keeps its `correct disclosure` broader term. | This record; the map |
| D5 resolves to the organization family, `single-source-of-truth` and `propagation-discipline`, with the aim "the artifact has one authoritative place". `minimal-corrections` is flagged for deletion; `approval-writes-the-artifact` stays in Landed work with an RT. | The correction concern is the trigger, not the aim. SSOT and propagation keep one authoritative state; minimal is a scope rule about the ask, and approval is the decision's landing. | This record; the map; the roadmap |
| D6 resolves to an RT group, not a family. The three share the writing mechanism; their intents differ: `dont-forecast-undone-work` serves the just-in-time demand, `say-what-done-looks-like` serves agent-operator alignment at dispatch, and `approval-writes-the-artifact` serves Landed work with the note-taking discipline as its intent and meticulous execution as its neighbour. | The mechanism is not the family; the aim is. The forecast stays in Grounding, the say-done joins Instruction scope, and approval stays in Landed work. | This record; the map; the roadmap's just-in-time row |
| D7 resolves to a split. `cut-what-serves-nothing` carries two parts: the organization principle (the Diataxis mode; the technical concerns are not conflated) and the writing rule (trim the sediment by managing the metadiscourse). They were combined by the removal-based drafting mechanism, not the aim. | The aim is not the mechanism. The organization part joins the organization family; the writing part stays in Instruction scope. The landing is the roadmap row. | This record; the map; the roadmap's cut row |
| D8 resolves to `colocation` as the leitwort; the mechanism is the placement of the subject's parts, and `proximity` names its effect. The co-location organizes within the `information hierarchy`; the umbrella benefit is `findability`, and the failure is `overload`. The roadmap row lands the re-signpost and the name. | The leitwort is the concept; the mechanism is the act that applies it. The card's current `proximity` is the mechanism word; the body's "one place" is the concept. | This record; the map; the roadmap's colocation row |
| The reader-context cluster is the only clear BT hierarchy. | It has a named umbrella and two axes. The other families have RT groups but no umbrella that the cards agree on. | This record; the map |
| `write-for-the-reader` is a correctness card with a progressive remedy, not a merge into the umbrella. | Its root defect is a missing referent. Its remedies are prior or forward, which is the RT. | This record; the map's D3 |
| No case stays open. | D4 to D8 are resolved. The landings are the roadmap rows: the minimal deletion, the cut split and the colocation re-signpost. | This record; the map's docket |
| The review runs in three passes: the context cluster, the five other families, the docket. | The context cluster is the settled model, so it is the calibration. The other families are provisional. The docket is the decisions. | This record; the map's review packet |
| Pass 1 holds. The BT is `context disclosure`, the NTs are `correct disclosure` and `sentence context`, and the four NTs and two RTs stand as mapped. | The operator confirmed the review packet. The umbrella name `progressive context disclosure` is retired, and the roadmap's cluster row now states the confirmed structure. | This record; the map's review record; the roadmap's cluster row |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| None. | -- | -- |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The corpus has seven families, not one tree, and only the reader-context cluster has a clear umbrella. | record | The map is a faceted organization, not a hierarchy. A single tree would force false parents. | The map |
| The reader-context cluster reorganizes cleanly once the root defect is separated from the remedy. | record | The umbrella is `context disclosure`, with `correct disclosure` and `sentence context` as its NTs, and the six cards split 3 and 1 plus two RTs. | The map; the progressive-context row |
| Three cross-family RT groups appear: task-holding, meticulous execution and cut's second rule. | record | They are RT edges, pair-local and non-transitive, so the map does not close over them. The correction group is the organization family, and `minimal-corrections` is flagged for deletion. | The map; the roadmap |
| The family is the family aim, not the card's intent. | record | The card's `intent` is the specific judgement; the family aim is the higher intent the cards serve. Reading the family as the card's intent alone would split the confirmed context cluster. | This record; the map |
| The terminology trio is one family, the shared domain model. | record | The family is the aim, not the words; `define` keeps its `correct disclosure` BT while joining the family. | The map |
| `minimal-corrections` carries a scope rule, not an artifact principle. | record | Its intent is "when asked to make a correction, do just that; dont slip in any additional changes"; its body counts artifacts, which is the organization aim. The deletion is a roadmap row. | The roadmap; the map |
| The task-holding trio shares a writing mechanism, not an aim. | record | The forecast serves the just-in-time demand, the say-done serves dispatch alignment, and approval serves Landed work with the note-taking discipline, neighbouring meticulous execution. The RT group stays; the family does not. | The map; the roadmap's just-in-time row |
| `cut-what-serves-nothing` is two principles sharing a removal-based mechanism. | record | The organization part is the Diataxis mode; the writing part is the metadiscourse. The split's landing is the roadmap row. | The roadmap; the map |
| The colocation row's premise is stale. | record | The card carries `metadata.leitwort: proximity`, not no leitwort. `proximity` names the mechanism; `colocation` is the concept. The co-location organizes within the `information hierarchy`; the umbrella benefit is `findability`, and the failure is `overload`. The row is corrected. | The roadmap; the map |

## Completed

| File | One-line change summary |
|---|---|
| `devlog/discussions/20261116-report-concluded-principle_corpus_map.md` | The 25 cards, the seven family aims, the RT groups, the docket, the three-pass review packet, the Pass 2 revision, the shared domain model family, the organization family, the D6 approval refinement, the D7 split, the D8 leitwort and the document-load labels. |
| `devlog/roadmap.md` | Marks the full survey `[x]` with the landed summary; adds the `minimal-corrections` deletion row; updates the cut row to the split and the colocation row to the D8 leitwort. |
| `devlog/handovers/M3.3.7/20261116-12-design-principle_corpus_map.md` | This record. |
