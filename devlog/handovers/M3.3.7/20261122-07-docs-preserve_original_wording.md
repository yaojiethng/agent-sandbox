---
date: 2026-11-22
milestone: M3.3.7 - The principle corpus admission
type: Documentation
status: Closed
---

# Handover - the rewrite rule preserves the original wording

## Objective

Narrow `communication-principle-rewrite-syntax-never-semantics` from a licence to reflow an author's prose to a rule that fixes a mistake and raises everything else, and rename it for the act it now governs.

## Scope

The principle, its frontmatter, the six live carriers of its name, the shape ADR, and the roadmap row. Not in scope: the agent's own prose in prompts, skills and records written from scratch, which the rule does not touch, and the `cut-metadiscourse` boundary case, which stays with its own row.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The rule states two categories and no third. | Read the body: minor mistakes are fixed, disagreements raised. | Agent [x] |
| The raise carries its evidence. | The five steps name the quote, the requirement, the evidence, the proposal and the review. | Agent [x] |
| Text the author asked for counts as the author's. | The `Asked for by the author` paragraph states it. | Agent [x] |
| The name states the rule the body carries. | The skill is `communication-principle-preserve-original-wording`; the old slug resolves nowhere outside `devlog/handovers/`. | Agent [x] |
| The record of the supersession exists. | The shape ADR carries a 2026-11-22 entry. | Agent [x] |
| The gates hold. | `check_principle_frontmatter.sh`, `lint.sh`, the suite. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The skill is renamed `communication-principle-preserve-original-wording`. | The old name instructed the act the body refuses. The operator proposed the new one, and `original` is defined in the opening line as the wording as the author left it, so it cannot be read as the first version of a revised text. | The skill; the ADR. |
| "Error" leaves the vocabulary; every non-minor-mistake is a disagreement. | The operator's ruling: a factual error is raised like any other disagreement, and one word names one thing. | The skill. |
| The raise carries evidence, as far as it exists. | A disagreement the author cannot check is a claim; the evidence is the fact, the source, the conflicting clause or the reading the text produces. | The skill. |
| Text the author asked for becomes the author's wording. | A section the agent drafted on request, and output the author asked to include, enter the text by the author's decision, so a later edit treats them as the original. | The skill; the ADR. |
| The `**Why.**` part stays gone. | The operator's rule is that a reason phrased as an agent's motive carries a presumption; the factual basis sits in `The wording` instead. | The skill. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The shape ADR's 2026-11-17 rationale says the rule separates "semantics from the dialogue, syntax from the writer", which the new body reverses. | Record | The old entry keeps its history and its name; the new entry states the reversal. A reader who opens only the old entry gets the superseded split, which is what a dated entry is for. | The ADR. |
| The old slug survives in `devlog/handovers/`, which are closed records of what was true then. | Record | No live carrier names it; the handover chain keeps the name it recorded. | Left as history. |
| The corpus's `neighbours: []` on this skill stays empty. | Design | Its two boundaries are stated as links in `What it does not cover`, and the roadmap row that asks for the reference edge is a separate item. | `communication-principle-preserve-original-wording`. |

## Completed

| File | One-line change summary |
|---|---|
| [`communication-principle-preserve-original-wording/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-preserve-original-wording/SKILL.md) | Renamed, and rewritten: minor mistakes fixed, disagreements raised with evidence, asked-for text counted as the author's. |
| [`docs/adr/principle_skill_shape.md`](../../adr/principle_skill_shape.md) | A 2026-11-22 entry supersedes the split that gave the agent the syntax. |
| [`.agents/skills/instruction-authoring/runbooks/principle-change.md`](../../../.agents/skills/instruction-authoring/runbooks/principle-change.md) | The write step cites the new name. |
| [`.agents/skills/instruction-authoring/SKILL.md`](../../../.agents/skills/instruction-authoring/SKILL.md) | The body step cites the new name. |
| [`instruction-cleanup/SKILL.md`](../../../workflow/coding-agent/skills/prose-review/runbooks/instruction-cleanup/SKILL.md) | The cleaned-surface judgement names the new slug. |
| [`src/reasoning/agent-runtime/pi/config/agent/AGENTS.md`](../../../src/reasoning/agent-runtime/pi/config/agent/AGENTS.md) | The principle list links the new name and path. |
| [`devlog/roadmap.md`](../../roadmap.md) | The iteration's row lands, and the boundary row names the new slug. |
| [`20261122-07-docs-preserve_original_wording.md`](20261122-07-docs-preserve_original_wording.md) | This record. |
