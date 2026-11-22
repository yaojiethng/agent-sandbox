---
date: 2026-11-18
milestone: M3.3.7 - The principle corpus admission
type: Implementation
status: Closed
---

# Handover - The value skill's cases move to the owners it restated

## Objective

Remove `communication-principle-only-derive-what-you-own`, land its self-count case as a metadiscourse antipattern, and leave its copied-value and pointer cases with the owners that already carry them.

## Scope

A placement scan's fifth action, `Remove`, ruled by the operator after reading every clause of the skill to an owner. The measurement that settles it: each of the skill's six table rows and both of its boundary paragraphs answer to `cut-metadiscourse`, `single-source-of-truth` or `justify-materialization-cost`, and no row is left without one.

The carriers are six hits in six files: the index line in the agent `AGENTS.md`, the paragraph in `principle-justify-materialization-cost` that calls the value question its neighbour, two mentions in the `/scope` prompt, and one citation each in the vendored `writing-for-agents` and in `active-tracker`. Each names `principle-single-source-of-truth` where it named the removed skill. The edge the removal revealed lands here too: `principle-single-source-of-truth` declares `principle-justify-materialization-cost`, since a materialized artifact derived from the owner does not violate the single source, and `communication-principle-cut-metadiscourse`, since both cut a thing stated twice at different grains. The operator widened the scope to take both.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill is gone and the corpus reads 26 principles with no findings. | `bash scripts/check_principle_frontmatter.sh` reports 26 and 0, and `node scripts/principle_inventory.mjs` lists no such principle. | Accepted. 26 and 0, and the inventory lists 26 without it. |
| `cut-metadiscourse` carries the self-count as its fourth antipattern, and its description names the shape. | Read its `**Antipatterns.**` list and its `description`; a reader writing "two rules" meets the rule there. | Accepted. The fourth antipattern is "the self-count", and the description names the shape. |
| `principle-justify-materialization-cost` states the value case itself, without pointing at a deleted skill. | Read the "A value in a sentence is the neighbouring question" paragraph: the subject stays, the pointer to the removed skill goes, and `single-source-of-truth` is named as the owner. | Accepted. |
| No live file names the removed skill. | `grep -rn "only-derive-what-you-own" --include=*.md src .agents docs workflow`, with the `devlog/` records excepted, returns nothing. | Accepted. Nothing outside `devlog/`. |
| The new edges are declared on both sides, and the inventory reports them. | `node scripts/principle_inventory.mjs` lists `principle-single-source-of-truth` under `justify-materialization-cost` and `communication-principle-cut-metadiscourse`, and both under it. | Accepted. Both declared on both sides. |
| Every decision this iteration records is realized in the files. | Read each `## Decisions` row against the tree. | Accepted. |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The skill is removed rather than narrowed. | Every clause maps to one of three owners, so a narrowed skill would restate an owner and fail `single-source-of-truth` at the smallest grain. | This record. |
| The self-count case lands in `cut-metadiscourse`. | A count that lists its own parts is redundant with the list, which is the deletion test's case, and the operator ruled it metadiscourse rather than a separate judgement. | This record; the skill. |
| The copied-value case needs no new text. | `single-source-of-truth` already lists "a validation, a state, a rule, a step" as things another unit carries, and a value retyped from a gate run is a state. | This record; the skill's `## What a violation looks like`. |
| `principle-single-source-of-truth` declares `principle-justify-materialization-cost`. | The single source declares one owner, and materialization lets an artifact be derived from that owner without violating it, because the split is on a functional axis that declares the exception. | This record; both skills' `metadata.neighbours`. |
| `principle-single-source-of-truth` also declares `communication-principle-cut-metadiscourse`. | Both cut a thing stated twice. The grains differ, a unit against a passage, and the mechanisms differ with them, an ownership test against a deletion test, so an edge reads the defect and the grain rather than the mechanism. The operator rejected the edge first and ruled it in when the shared logic was read at the two grains. | This record; both skills' `metadata.neighbours`. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The census found two carriers the scope line did not name, `writing-for-agents` and `active-tracker`, since both cite the skill in prose rather than in a link list. | Process | The `grep` for the name is what found them, not the reading of the files that description and link checks cover. A removal census reads every live citation, not only the index. | This record. |
| The skill was grouped by its mechanism, a sentence that states a value, rather than by its defect. | Design | Its defect set held two, a copy that drifts and a count that adds nothing, so one skill stated two judgements and each belonged elsewhere. The corpus's family key is the aim, and this is the case that shows what happens when the sentence's shape is used instead. | The edges row in the roadmap. |

## Completed

| File | One-line change summary |
|---|---|
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-only-derive-what-you-own/SKILL.md` | Deleted; its cases answer to three owners. |
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-cut-metadiscourse/SKILL.md` | Gains the self-count antipattern, its description, and the edge to `single-source-of-truth`. |
| `src/reasoning/agent-runtime/pi/config/agent/skills/principle-single-source-of-truth/SKILL.md` | Declares two neighbours. |
| `src/reasoning/agent-runtime/pi/config/agent/skills/principle-justify-materialization-cost/SKILL.md` | States the value case itself, names SSOT, declares it. |
| `src/reasoning/agent-runtime/pi/config/agent/skills/active-tracker/SKILL.md` | Its citation names `single-source-of-truth`. |
| `src/reasoning/agent/skills/writing-for-agents/SKILL.md` | Its citation names `single-source-of-truth`. |
| [`src/reasoning/agent-runtime/pi/config/agent/AGENTS.md`](src/reasoning/agent-runtime/pi/config/agent/AGENTS.md) | The index line goes; 26 principles load. |
| [`workflow/coding-agent/prompts/scope.md`](workflow/coding-agent/prompts/scope.md) | Two mentions leave its question lists. |
| [`devlog/roadmap.md`](devlog/roadmap.md) | The row closes with its landed summary. |
| `devlog/handovers/M3.3.7/20261118-02-refactor-value_skill_removal.md` | This record. |
