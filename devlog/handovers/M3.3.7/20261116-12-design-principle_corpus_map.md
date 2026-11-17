---
date: 2026-11-16
milestone: M3.3.7 - The principle corpus admission
type: Design
status: Active
---

# Handover - The principle corpus, a first map

## Objective

Apply the survey to all 25 principles and hand the operator a provisional map of six families, their RT groups and the open cases, so the corpus organization is decided from evidence rather than from the migration's collapsing values.

## Scope

The M3.3.7 row **The full corpus survey over the 25**. In scope: the 25 cards, six families, the reader-context BT hierarchy, the cross-family RT groups and the docket. No skill is edited and the field stays `[]`.

Out of scope: the cluster reorganization itself, the link normalisation and the cases D4 to D8, which the map dockets for a later decision.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The 25 cards, six families, the context hierarchy, the RT groups and the docket exist in the map. | Read `devlog/discussions/20261116-report-open-principle_corpus_map.md`. | Agent [x] |
| The operator reviews the map and confirms or corrects the families. | The operator's reply on this handover. | Operator: Pass 1 confirmed; Pass 2 and 3 outstanding. |
| No principle skill is edited and the field stays `[]`. | `git diff --stat` shows no `src/reasoning/agent-runtime/pi/config/agent/skills/` file. | Agent [x] |
| Every open case is in the docket with its parties and its issue. | Read the docket table. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The map has six families by root defect: context, source, grounding, instruction scope, check placement and landed work. | The root defect is what the card prevents. Grouping by remedy would put correctness cards beside progression cards and recreate the straddle. | This record; the map |
| The reader-context cluster is the only clear BT hierarchy. | It has a named umbrella and two axes. The other families have RT groups but no umbrella that the cards agree on. | This record; the map |
| `write-for-the-reader` is a correctness card with a progressive remedy, not a merge into the umbrella. | Its root defect is a missing referent. Its remedies are prior or forward, which is the RT. | This record; the map's D3 |
| Cases D4 to D8 stay open. | They are structure decisions the map surfaces but does not settle: the terminology, correction and task-holding groups, and the two roadmap rows. | This record; the map's docket |
| The review runs in three passes: the context cluster, the five other families, the docket. | The context cluster is the settled model, so it is the calibration. The other families are provisional. The docket is the decisions. | This record; the map's review packet |
| Pass 1 holds. The BT is `context disclosure`, the NTs are `correct disclosure` and `progressive disclosure`, and the four NTs and two RTs stand as mapped. | The operator confirmed the review packet. The umbrella name `progressive context disclosure` is retired, and the roadmap's cluster row now states the confirmed structure. | This record; the map's review record; the roadmap's cluster row |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| D4 to D8 in the map's docket. | The families' umbrellas and the two roadmap rows. | Each case's options are in the docket. |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The corpus has six families, not one tree, and only the reader-context cluster has a clear umbrella. | record | The map is a faceted organization, not a hierarchy. A single tree would force false parents. | The map |
| Four cross-family RT groups appear: terminology, correction, task-holding and cut's second rule. | record | They are RT edges, pair-local and non-transitive, so the map does not close over them. | The map |
| The reader-context cluster reorganizes cleanly once the root defect is separated from the remedy. | record | The umbrella is `context disclosure`, with `correct` and `progressive` as its NTs, and the six cards split 3 and 1 plus two RTs. | The map; the progressive-context row |

## Completed

| File | One-line change summary |
|---|---|
| `devlog/discussions/20261116-report-open-principle_corpus_map.md` | The 25 cards, six families, the RT groups, the docket and the three-pass review packet. |
| `devlog/roadmap.md` | Links the map from the open full-survey row. |
| `devlog/handovers/M3.3.7/20261116-12-design-principle_corpus_map.md` | This record. |
