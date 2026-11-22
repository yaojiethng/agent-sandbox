---
date: 2026-11-22
milestone: M3.3.7 - The principle corpus admission
type: Workflow
status: Closed
---

# Handover - voice and structure land on the shipped instruction surface

## Objective

Give the voice rule the owner that fires for every output, take the pattern that carried it out of the incremental-parsing principle, and state the indent-outline form beside it.

## Scope

The `## Output` section of the shipped `AGENTS.md`, the two principles that carried or routed the rule, the ASD-STE100 citation record, and the roadmap row. Not in scope: the clause-type rule, which keeps its leaf; the concision half of the operator's brief, which `cut-metadiscourse` owns; and the `**Voice.**` paragraph in `.agents/skills/project-documentation/SKILL.md`, which governs a record's register rather than grammatical voice.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The rule is stated once, where every output is written. | The shipped `AGENTS.md` `## Output` carries `**Voice.**`. | Agent [x] |
| The parsing leaf no longer states it. | `grep -c passive communication-principle-order-for-incremental-parsing/SKILL.md` reads `0`. | Agent [x] |
| No principle routes voice to another principle. | `grep -rn "voice" src/reasoning/agent-runtime/pi/config/agent/skills/` reads nothing. | Agent [x] |
| The citation record names the new placement. | `asd-ste100.json` `kept` says the instruction surface rather than a principle. | Agent [x] |
| The corpus still passes its gates. | `check_principle_frontmatter.sh`, `lint.sh`, the suite. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The rule lives in the shipped `AGENTS.md`, not the project one and not a principle. | Rule 3.6's scope is "when you write in STE": it holds for procedural and descriptive text alike, in every project this harness runs, and a principle fires on a writing act, so no principle can own a rule with no trigger. The shipped file loads before the project file and ships beside the corpus, so a skill can link it. | The shipped `AGENTS.md`; the roadmap row. |
| The surface states the condition, not the quote, and names no source. | The operator's ruling over three passes: a rule stated for every output carries its own condition, and a citation there is reading instruction the writer does not act on. The provenance stays in the citation record. | The shipped `AGENTS.md`; `asd-ste100.json`. |
| The corpus's object-topic passive is stated as one condition of the rule. | The surface states what to do; the citation record marks which condition the standard does not permit. | The shipped `AGENTS.md`; `asd-ste100.json` `added`. |
| The indent-outline rule joins voice under one `## Output` section, as `**Structure.**`. | The operator asked for both in one section; the two rules are the two things an output's prose is judged on, and one section states them once. | The shipped `AGENTS.md`. |
| The operator's structure text lands verbatim. | They wrote it and asked for it verbatim; the one departure is the non-ASCII idiom in the goal line, which `doc-ascii` refuses, so the goal reads as its own gloss: "Enable \"scanning ten lines at a glance\"". | The shipped `AGENTS.md`; this record. |
| The register paragraph in `project-documentation` is deleted rather than renamed. | The operator's ruling: the paragraph governed a record's register, and with `**Voice.**` now naming grammatical voice on the surface, one label for two rules had no repair short of a second name. The register test it carried is the new authorship principle's test, so nothing is lost. | `.agents/skills/project-documentation/SKILL.md`; this record. |
| The parsing leaf keeps no voice clause at all. | The attribution and role-reversal cost was real but is not incrementality; leaving a clause behind would keep a second statement of the same rule. | The parsing leaf. |
| The act leaf no longer routes voice. | With the rule on the surface, a routing sentence in a shipped skill would point a reader in another project at a file that does not ship, and restate a rule the surface already carries. | The act leaf. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `.agents/skills/project-documentation/SKILL.md` carried a `**Voice.**` paragraph governing a record's register, so one label named two rules. | Terminology | The paragraph is deleted, and its register test moves to the authorship principle that replaces `rewrite-syntax-never-semantics`. | `.agents/skills/project-documentation/SKILL.md`; this record. |
| The operator's brief carried a Chinese idiom for the goal, and `doc-ascii` bans non-ASCII in prose. | Gate | The goal lands as "a reader stops at any depth and still holds the essentials", which is the idiom's meaning without the characters. | The shipped `AGENTS.md`. |
| The parsing leaf's source line cited `asd-ste100.json` for the actor and nothing else. | Code | The record leaves the leaf's source list, and the sentence drops to the one record it still uses. | The parsing leaf. |
| Rule 3.6's explanatory text gives the `by whom or by what?` question to find a passive, not to license one. | Evidence | The surface states the question as a step, after the conditions, so it cannot read as a permission. | The shipped `AGENTS.md`. |
| The structure text's second sentence, "Information is to be made as concise and dense and stripped-down as possible", is `cut-metadiscourse`'s intent word for word. | Duplication | One sentence now stands in two places; when either moves, both need the read-back. Left verbatim on the operator's instruction, and recorded here rather than edited. | Flagged for the operator. |
| The new `## Output` section broke the instruction-surface gate until the subject table gained a row. | Gate | The surface table is the manifest a session reads its layers from, so a section without a row is invisible to it. | `docs/development/instruction-surface-conventions.md`. |

## Completed

| File | One-line change summary |
|---|---|
| [`src/reasoning/agent-runtime/pi/config/agent/AGENTS.md`](../../../src/reasoning/agent-runtime/pi/config/agent/AGENTS.md) | A new `## Output` section states `**Voice.**` and `**Structure.**`. |
| [`communication-principle-order-for-incremental-parsing/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-order-for-incremental-parsing/SKILL.md) | The actor bullet, the passive exception and the ASD source entry leave; a verbatim quote is the remaining exception. |
| [`communication-principle-structure-instructions-imperatively/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-structure-instructions-imperatively/SKILL.md) | The voice routing sentence leaves, and Rule 3.6 leaves its source list. |
| [`.agents/registry/citations/asd-ste100.json`](../../../.agents/registry/citations/asd-ste100.json) | `kept` names the instruction surface; `added` records the object-topic extension. |
| [`.agents/skills/project-documentation/SKILL.md`](../../../.agents/skills/project-documentation/SKILL.md) | The `**Voice.**` register paragraph is deleted. |
| [`docs/development/instruction-surface-conventions.md`](../../../docs/development/instruction-surface-conventions.md) | The subject table gains the `Output` row. |
| [`devlog/roadmap.md`](../../roadmap.md) | The voice row closes on the move. |
| [`20261122-06-workflow-voice_on_the_surface.md`](20261122-06-workflow-voice_on_the_surface.md) | This record. |
