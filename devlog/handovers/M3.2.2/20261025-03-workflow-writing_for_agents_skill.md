---
date: 2026-10-25
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - The vendored writing-for-agents skill

## Objective

Land the operator's chosen third-party reference as a skill in this repository, so that a future `prose-review` can call it as a runbook: the source text verbatim, apart from two mechanical changes and the points that restate a principle this repository already holds.

## Scope

Continues the open iteration [`20261025-01-workflow-instruction_cleanup_pass.md`](20261025-01-workflow-instruction_cleanup_pass.md), which settles the cleanup pass method; this sidequest lands the reference that method's `prose-review` shell will call, and returns there when it closes.

In scope: `SKILL.md` and `SKILL-MECHANICS.md` from `mattpocock/skills` at commit `5beb35b0`, the provenance line naming the URL and the commit, the eleven pointers to ten principles, and the arrow-glyph conversion the ASCII gate requires.

Out of scope: `prose-review` and its call site, which the two base skills row owns; the two synthesis findings below, which are the bucket ladder's dedup step; and any measurement of whether the document improves a review.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Both files land, with the source content intact apart from the stated changes | diff against the fetched source shows only the provenance block, the eleven pointers and the two arrow replacements | Agent [x] |
| The provenance names the source and the commit | `grep -c "5beb35b040e3de97e54fa9e386d7e42d15c295c2"` prints 1 | Agent [x] |
| Every point restating a principle names it rather than duplicating it | `grep -c "providers/pi/config"` prints 11, over ten distinct targets | Agent [x] |
| The sibling link is not broken | `SKILL-MECHANICS.md` exists beside `SKILL.md`, and the linking gate resolves the pair | Agent [x] |
| The gates are clean | `bash scripts/lint.sh` across 12 gates | Agent [x] |
| The outcome is filed | one `[x]` roadmap row naming the skill, the URL and the commit | pending the close |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| It lands under the source's own name, `writing-for-agents` | the operator's direction; the name is the source's, and renaming it would break the provenance the tag exists to establish | this handover |
| It lands at `src/reasoning/agent/skills/` rather than the pi-config corpus root | that root holds the vendored third-party skills; the pi-config root holds the in-house principle corpus, whose `principle-` shape this document must not be bent to | this handover |
| Both files land, though only `SKILL.md` was quoted | `SKILL.md` links its sibling, so landing one leaves a broken link | this handover |
| The provenance sits in a blockquote above the opening sentence, not in the frontmatter | the frontmatter is the author's verbatim block, and a key added there weakens the byte-identity claim the tag rests on | this handover |
| A point restating a principle this repository holds names that principle and keeps its description | the operator's direction of 2026-10-25, so the document is not a second origin for a judgement we already own, while the gloss and examples stay readable | this handover |
| The rewrite's own boundary is named in the provenance block, not in the body | the body makes no claim about rewrites; the block is the act that needs the authority | the skill's provenance block |
| Two correspondences were declined: `single-train-of-thought` and `dont-forecast-undone-work` | neither has a site here: the train's sentence claim is already `cut-what-carries-nothing`'s, and the document writes no forecast | the Findings table below |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The copy family -- `principle-single-source-of-truth`, `communication-principle-only-derive-what-you-own` and `principle-guard-derived-state` -- all fired on one clause, and choosing among them needed a distinction the corpus does not state | corpus | a writer must arbitrate between three principles before picking one; three units, one relation | M3.2.2 dedup step, as a synthesis candidate |
| `communication-principle-cut-what-carries-nothing` and `communication-principle-single-train-of-thought` make one judgement at sentence granularity: "would the reader act differently if it were gone" against "advances that line or belongs elsewhere"; the train's unique claim is at section level | corpus | the overlap is paid twice, and a site match becomes a coin flip | M3.2.2 dedup step, as a synthesis candidate |
| No principle governs a pointer's wording as a trigger -- when the agent reaches out-of-context material at all -- and three reader-facing principles competed for one clause with nothing stating where each fires | corpus | the vendored document is now the only place in this repository that states pointer triggering | a roadmap open row under M3.2.2, as a coverage gap |
| The ASCII gate bans U+2192, so "verbatim" cost two glyphs, and the provenance line states the change | gate | mechanical, reported rather than absorbed | this handover |

## Completed

| File | Change |
|---|---|
| [`writing-for-agents/SKILL.md`](../../src/reasoning/agent/skills/writing-for-agents/SKILL.md) | the source document, the provenance block, and eleven pointers to ten principles |
| [`writing-for-agents/SKILL-MECHANICS.md`](../../src/reasoning/agent/skills/writing-for-agents/SKILL-MECHANICS.md) | the skill-specific branch of the reference, verbatim |
| [`devlog/roadmap.md`](../roadmap.md) | row 170 marks the landed skill `[x]`; row 168 names the vendored skill in the `prose-review` runbook set; row 169 files the pointer-triggering gap as an open row |
| [`20261025-01-workflow-instruction_cleanup_pass.md`](20261025-01-workflow-instruction_cleanup_pass.md) | one Findings row naming this sidequest and its reason |
