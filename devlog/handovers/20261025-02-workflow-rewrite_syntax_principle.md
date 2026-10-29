---
date: 2026-10-25
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - The rewrite boundary as a stated judgement

## Objective

Make the boundary between what a rewrite may change and what its author owns a stated judgement in the communication corpus, with one home, one router line in the always-loaded layer, and one raise procedure for a disagreement.

## Scope

Continues the open iteration [`20261025-01-workflow-instruction_cleanup_pass.md`](20261025-01-workflow-instruction_cleanup_pass.md), which owns M3.2.2's counterparty check scope and the instruction-cleanup procedure; this sidequest owns the provenance judgement that procedure obeys, and returns there when it closes.

In scope: the judgement and its guard list, as a principle skill with its installed copy; the router line in the provider layer's `AGENTS.md`, in the repo source and the installed copy alike; and the link from `skill-scaffolder`, whose subject is instruction text. The provenance requirement the operator stated, that an instruction be written in the operator's words or a verbatim approved statement, is part of this unit, and so is the raise procedure that replaces a rephrase.

Out of scope: the instruction-cleanup procedure itself and the M3.2.2 takeover, which are the interrupted iteration's; the literal-reader test's other carriers, since the principle now owns it and `AGENTS.md` no longer states it; and any measurement of whether the judgement improves a review.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The judgement is a principle skill carrying the corpus shape and a claim | `bash scripts/lint.sh` counts it among the principle skills, with the claim named in its frontmatter | Agent [x] |
| The repo source and the installed copy are identical | `diff -rq` over the skill folder and `diff -q` over `AGENTS.md` | Agent [x] |
| The always-loaded layer carries the router line | `grep -c "Before rewriting a sentence someone else wrote"` in `AGENTS.md` prints 1 | Agent [x] |
| No paraphrase licence survives in the test | `grep -c "rephrased with that one"` in the principle prints 0 | Agent [x] |
| A failed literal read routes to the author | `grep -c "raised to the author"` prints 2 | Agent [x] |
| A skill's drafting step names the judgement | `grep -c` in `skill-scaffolder/SKILL.md` prints 1 | Agent [x] |
| The procedure that obeys the judgement names it | `grep -c` in `instruction-cleanup.md` prints 1 | Agent [x] |
| The gates are clean | `bash scripts/lint.sh` across 12 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The boundary is stated at the grain of the part: the clause, its turn of phrase and its instruction are the author's; connectives, linking and word order are the agent's | the first form used "content" and "form" in the everyday sense, which lost the strictness the boundary needs | the principle's title and body |
| The principle owns the literal-reader test, and `AGENTS.md` owns the pointer | one test, one home; a pointer that hands over the test alone is a looser constraint than the rule | `AGENTS.md`, the principle |
| A failed literal read is a disagreement, raised to the author with the rephrase offered as a suggestion under the raise | "the sentence is rephrased with that one" is the paraphrase permission the boundary exists to forbid | the principle, `**The test.**` and `**Disagreement.**` |
| "Replace a pure function word" narrows to "replace a definite or indefinite article" | every other function-word class carries a decision: quantifier scope, negation polarity, modal strength, pronoun referent, preposition relation, conjunction link | the principle's guard list |
| A misspelling inside a protected word is raised, not repaired | a typo can sit inside a negation or a keyword, and repairing it is an edit to the decision | the principle, `**Disagreement.**` |
| The term for the failure is "gratuitous reflow" | one phrase the agent aligns with, and it names the defect rather than the act | the principle's `**Why.**` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The principle shape gate fixes the part order as pattern, why, parts, test, so the operator's block could not keep its original sequence (test before the guard table) | convention | one structural move, reported when it was made; the order is enforced by `scripts/lint/document-shape.mjs` | this handover; the gate is unchanged |
| `AGENTS.md` no longer states the literal-reader test, so an agent holding only the always-loaded layer has the trigger and not the test | record | the cost of one home, accepted on operator direction; the skill is installed beside `AGENTS.md` | the operator's ruling, this handover |

## Completed

| File | Change |
|---|---|
| [`communication-principle-rewrite-syntax-never-semantics/SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/communication-principle-rewrite-syntax-never-semantics/SKILL.md) | the judgement, the guard list, the why, the disagreement procedure and the test; installed copy synced |
| [`AGENTS.md`](../../src/reasoning/providers/pi/config/agent/AGENTS.md) | the router line in the Communication Standards section, in the repo source and the installed copy alike |
| [`skill-scaffolder/SKILL.md`](../../.agents/skills/skill-scaffolder/SKILL.md) | the drafting step names the judgement for the instruction text a skill carries |
| [`devlog/roadmap.md`](../roadmap.md) | the outcome filed as a closed row under M3.2.2 |
