# The reader-context five, a dry run

**Status:** concluded
**Date:** 2026-11-16
**Procedure:** [`.agents/skills/instruction-authoring/references/corpus-survey.md`](../../.agents/skills/instruction-authoring/references/corpus-survey.md)
**Census:** [`20261116-report-concluded-principle_link_census.md`](20261116-report-concluded-principle_link_census.md)

## Why this exists

The five-card dry run tests the survey on the family the reverted migration already found contested. It produces the cards, the family map, the candidate edges and the docket, and it stops for the operator's correction before the full survey.

## The cards

| Card | Judgement | Defect it prevents | Grain | Moment |
|---|---|---|---|---|
| `define-terminology-before-use` | A term that can carry two meanings here is defined before the work relies on it. | a term carries two meanings, so readers proceed on two definitions | term | before the work relies on it |
| `attach-as-you-read` | Give the reader something to attach each phrase to before the next phrase arrives. | a phrase arrives before the reader can attach it | sentence | write, revise |
| `single-train-of-thought` | Carry one line of reasoning through the document, and let each sentence advance it. | a second line placed beside the first | argument line | write, revise |
| `write-for-the-reader` | Every text is written for the reader who holds it, not for the session that produced it. | the referent lives in the session or an earlier version | session or file history | write, revise |
| `link-what-the-reader-can-open` | A pointer claims a target exists and is reachable from where the citing text is read; link what the reader can reach and name what they cannot. | the pointer's target is not reachable from the reader's copy | pointer | write, revise |

The five test sentences are the evidence: each names the thing the reader fails to hold, and each names a different thing.

## The map, two readings

**Reading A, the defect is the distinct failure.** Each card carries its own defect, so there are five families of one card. No RT edge is proposed inside a family of one. The shared category, progressive context disclosure, becomes a candidate **BT** umbrella over five narrower judgements. This reading produces no tangle, because no card is a family with another.

**Reading B, the defect is the shared category.** All five defects are read as "the reader lacks context on the path they read", so the five are one family. Every pair shares the defect and differs in grain, so all ten pairs are RT candidates. That is the tangle, and its cause is the defect facet's granularity, not the cards.

The dry run cannot choose between the readings by itself. The choice is the process's load-bearing decision: the defect facet's granularity. Reading A makes the family the judgement and the category the umbrella. Reading B makes the category the judgement and the grains its parts.

**Reading C, the operator's cut (2026-11-16).** The umbrella is one judgement, and it has two sides, which are its narrower terms.

- **Prior disclosure.** The context arrives before the item, so the reader can parse it. The cards are `define-terminology-before-use` (term), `attach-as-you-read` (sentence), and `write-for-the-reader` (session or file history).
- **Forward dispatch.** The item points to context elsewhere, so the reader knows where to go and the detail does not clutter the current purpose. The card is `link-what-the-reader-can-open` (pointer).

The defect facet names the **direction of disclosure**, not the shared category and not the distinct failure. The umbrella is the BT, the two sides are its NTs, and the four cards are NTs under a side. `single-train-of-thought` is not disclosure; it is RT to the umbrella, not a NT.

The operator's resolution (2026-11-16) confirms the RT. Good progressive disclosure leads with the important context and discloses details in order, so a clean single train of thought is a neighbouring goal the same rules serve. It is not the umbrella's intent. The umbrella's intent is to smooth the engagement and improve transference.

## The candidate edges

Under Reading C: the umbrella is the BT of `prior disclosure` and `forward dispatch`; each side is the BT of its cards. `write-for-the-reader` and `link-what-the-reader-can-open` are RT under the umbrella at different directions, not a duplicate. `single-train-of-thought` is RT to the umbrella as a neighbouring goal.

One pair deserves a separate look. `write-for-the-reader` and `link-what-the-reader-can-open` both tell the writer to link the session or the target once. They differ in grain (session or file history against the pointer), so they are RT under either reading, not a duplicate.

## The docket

| Case | Parties | Issue | Evidence | Status |
|---|---|---|---|---|
| D1 | the five, and `single-train-of-thought` | Is progressive context disclosure one judgement with two sides, and does `single-train-of-thought` sit outside it? | Reading C; the operator's four-card list | resolved: `single-train-of-thought` is RT to the umbrella |
| D2 | the five | Does the defect facet name the distinct failure or the shared category? | Reading A and Reading B above | resolved: the direction of disclosure, prior against forward dispatch |

D2 is resolved by Reading C. D1 narrows to one question, the placement of `single-train-of-thought`. A stay is acceptable while that is open: the map can record the four cards, the two sides and the umbrella candidate, and the field stays `[]`.

## What the dry run says about the process

The process reached a decision rather than a tangle: the operator supplied the two-sided cut and resolved the single-train placement. That is the behaviour the reverted migration lacked. The cost was five cards, not twenty-five.

The census supports the dry run: the five carry 11 of the 30 cross-references, and `What it does not cover` is the part that carries most of them. The cards can be read without opening a body.
