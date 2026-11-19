---
date: 2026-11-19
milestone: M3.3.7 - The principle corpus admission
type: Plan
status: Closed
---

# Handover - The act rule and the voice rule become two items

## Objective

Split a badly controlled slice into two task items with proper detail, keep the decisions that still hold as requirements, drop the ones that do not, and defer the implementation to a later commit.

## Scope

The iteration began as the imperative correction, was scoped on the symptom, and drafted a leaf named for a mood that mixed four axes. The review found three things the draft could not survive.

- The voice rule already has an owner, [`communication-principle-attach-as-you-read`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-attach-as-you-read/SKILL.md), and ASD-STE100 Issue 9 Rule 3.6 scopes it with a clause and a test the owner does not carry.
- The modal strength already has five homes, and `docs/adr/instruction_modality.md` rejects a keyword rule on a 12-of-20 reader agreement, so the draft's `must` row became a sixth statement of one scale.
- The mode decides both rules. Procedural writing takes the imperative and never the passive; descriptive writing takes no imperative and the passive only where the agent is unknown.

The draft leaf is reverted. This record plans the work; it implements none of it.

## What would be done differently

| The change | What it was | What it should be |
|---|---|---|
| Owners first | the leaf was drafted, then two of its rows died to owners already in the tree | inventory the owners, then draft what is genuinely unowned |
| The measure | the count measured the word `should` and the imperative rate, which is the symptom's vocabulary | act-classification accuracy over a sample that includes requirement-heavy text |
| The scope | one axis per iteration, but the correction's wording named clause type, voice, strength and order at once | one axis, and the correction's vocabulary is a symptom to be decomposed first |
| The name | taken from the correction | taken from the axis, after the axis is fixed |

An option not taken: keep the corpus at 27 and put the clause-type rule in the `instruction-authoring` convention, which is where a drafter reads. It is cheaper and it matches the evidence that the drift is in drafting. It is rejected here because a principle is the only place a rule is named as a judgement, and this one is a judgement.

## Requirements preserved, and their destination

| Requirement | From | Lands in |
|---|---|---|
| The unit is the logical statement | the operator's granularity | the act item |
| Explanatory prose is defined once, distinct from the `description` field that routes | the terminology clash the operator raised | the act item |
| The source phrasing is quoted with its locator, never paraphrased | the operator's `technical-writing` reading | both items |
| The mode decides where each rule applies | the sources' own scope clauses | both items |
| The leaf cites the modality scale and does not restate it | the five-home find | the act item, and the deferred item in `devlog/roadmap_future.md` |
| Voice stays with `attach-as-you-read` and the act stays with its own leaf | the source structure and the grammar, since an imperative has no voice contrast | both items |
| The provenance carries the free-copy credit | the operator's source | both items |

## Requirements dropped

| Dropped | Why |
|---|---|
| The name `match-the-mood-to-the-act` | it names the writer's bookkeeping, which is the focus the operator rejected |
| The `must` and `should` rendering rule | it is the modality case, filed in `devlog/roadmap_future.md` |
| The edge to `principle-match-precision-to-stakes` | the two rules are a rendering rule and a strength rule; whether they join is the deferred item's decision |
| "Call to action" as the impact | not every sentence directs, so the general form is what the sentence asks, including nothing |
| The claim that `technical-writing` "restates" the voice rule | the defect is the missing scope clause and test, not the phrasing |

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Two items exist, one per axis, each naming the rule, the source, the requirements and the dropped parts. | `grep -c "The act a sentence performs" devlog/roadmap.md` reads 1 and `grep -c "The voice rule has one owner" devlog/roadmap.md` reads 1. | Accepted. |
| The draft leaf is gone from the tree, the index and the installed copy. | `ls` on the skill directory, the index leaf count at 27, and the installed copy at 27. | Accepted. |
| The two items carry every preserved requirement and every dropped decision with its reason. | Read the tables above against both items. | Accepted. |
| The gates pass and the tree is clean after the plan commit. | `scripts/lint.sh`, `scripts/check_principle_frontmatter.sh`, `git status --short`. | Accepted. |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The slice splits into an act item and a voice item. | The sources keep the two rules in different sections, and the grammar forbids merging them, since the imperative has no voice contrast. | `devlog/roadmap.md`, both items. |
| Implementation is deferred and the plan is committed alone. | The plan states the requirements a later iteration implements, and a half-built leaf in the tree would be a claim the plan has not made. | This record; the commit. |
| The draft leaf is deleted rather than parked. | It was named for a rejected focus and stated a scale the ADR rejects; parking it would carry both defects into the next iteration. | This record. |
| The remaining six `technical-writing` rows stay as filed. | Each restates a rule with a different owner, and the census still holds for them. | `devlog/roadmap.md`. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The iteration was scoped on the operator's symptom rather than on an axis, so the slice inherited four axes from one phrase. | Process | A correction phrased in mixed vocabulary needs decomposing before a scope is cut, or the scope inherits the mixture and the draft dies to owners that were already in the tree. | This record; the two items. |
| The sources keep the voice rule and the clause-type rule in separate sections, and the imperative has no voice contrast. | Evidence | The two rules cannot merge, and a leaf that merged them would apply the voice rule to a clause type that has no voice. | Both items. |
| The mode decides both rules. | Evidence | `organize-by-diataxis`'s mode switch is load-bearing for a rule neither leaf owns today: procedural takes the imperative and bars the passive, descriptive takes no imperative and limits the passive to an unknown agent. | Both items, as the mode requirement. |

## Completed

| File | One-line change summary |
|---|---|
| [`devlog/roadmap.md`](devlog/roadmap.md) | The census row for `attach-as-you-read` becomes the voice item, and a new act item joins it, both carrying their requirements and their dropped parts. |
| [`devlog/roadmap_future.md`](devlog/roadmap_future.md) | Unchanged from the draft: the deferred item for the modal vocabulary, stating the problem only. |
| `devlog/handovers/M3.3.7/20261119-03-plan-act_and_voice_split.md` | This record, replacing the implementation handover. |
| The draft skill, its index leaf and its edge | Reverted, so the plan commit carries no implementation. |
