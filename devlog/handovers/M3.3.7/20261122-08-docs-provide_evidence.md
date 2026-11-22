---
date: 2026-11-22
milestone: M3.3.7 - The principle corpus admission
type: Documentation
status: Closed
---

# Handover - the evidence principle, and three unslop rules under it

## Objective

Give the abstract-trigger rule a name that states the act, land the three unslop rules in it, and ban the word that names nothing.

## Scope

`show-dont-describe` renamed and rewritten, its five carriers, the two neighbour edges, the `thing` entry in the terminology registry, and the roadmap rows. Not in scope: the corpus-wide sweep of `thing`, which its own row holds, and the metaphor row that also stands in `maximize-conceptual-leverage`.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The name states the act and carries the leitwort. | The skill is `communication-principle-provide-evidence`; `leitwort: evidence`. | Agent [x] |
| The title is not an aphorism. | The H1 reads `Provide evidence`; "Show, don't describe" is gone. | Agent [x] |
| Every table row names a case a writer meets. | Twelve rows: each left cell is a quoted string or a named artifact; the two rows that restated the principle are dropped. | Agent [x] |
| The three unslop rules are owned. | Feeling words, mannered prose and over-compression each have a row; the portability and restate cuts sit in `The test`. | Agent [x] |
| `thing` is banned with its replacements. | The terminology registry entry names the artifact classes to write instead. | Agent [x] |
| The edges are symmetric. | `principle-vacuous` and `principle-say-what-done-looks-like` list it; it lists both. | Agent [x] |
| The gates hold. | `check_principle_frontmatter.sh`, `lint.sh`, the suite. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The skill is renamed `communication-principle-provide-evidence`. | The old name is a play on "show, don't tell", which the new mannered-prose row bans, and it names two modes rather than the act. The operator chose the new name. | The skill; its seven carriers. |
| The leitwort is `evidence`. | It states why the artifact is wanted rather than what it is, and it recruits the pretrained sense for free. `artifact` left the body with it. | The skill. |
| The three unslop rules land here, not in three principles. | Each is one failure: a sign standing where the thing it signs would go -- a feeling for the mechanism, a metaphor for the literal phrase, an arrow for the sentence. | The skill; this record. |
| The table keeps only rows whose left cell is a case. | A row that restates the principle teaches nothing the title did not; two went on that test. | The skill. |
| `thing` is banned. | It names no referent, so no reader can check it, and no replacement list can be shorter than the sentence that needs it. | `docs/reference/terminology.md` |
| The served row is the general one: the work was done is proved by the diff. | The agent meets it every run, and it is the instance the operator named as the rule. | The skill. |

## Decisions pending

| Decision | Options | Where it will land |
|---|---|---|
| Which of the two metaphor rows yields. | Keep this skill's row and cut `maximize-conceptual-leverage`'s, or the reverse. | The two skills. |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The metaphor row repeats `maximize-conceptual-leverage`'s "a metaphor standing in for the mechanism". | Content | Two sources for one judgement; a reader cannot tell which is authoritative. | `communication-principle-maximize-conceptual-leverage` |
| `thing` stands in about fifty live carriers. | Propagation | The ban is stated and unenforced until the sweep runs. | The roadmap row for the sweep. |
| The archived discussion `20261019-design-draft-prose_standards_specs.md` names the old slug. | Record | An archived record keeps what was true then, as the handovers do. | Left as history. |
| `intent` and `mechanism` were personified and jargon-heavy before this pass. | Content | Both now name the act; the mechanism clause still reads awkwardly. | `communication-principle-provide-evidence` |

## Completed

| File | One-line change summary |
|---|---|
| [`communication-principle-provide-evidence/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-provide-evidence/SKILL.md) | Renamed and rewritten: `leitwort: evidence`, twelve case rows, the three unslop rules, the cut tests. |
| [`docs/reference/terminology.md`](../../reference/terminology.md) | `thing` is banned, with the artifact classes to write instead. |
| [`principle-say-what-done-looks-like/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/principle-say-what-done-looks-like/SKILL.md) | Gains its first neighbour edge. |
| [`principle-vacuous/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/principle-vacuous/SKILL.md) | The edge names the new slug. |
| [`src/reasoning/agent-runtime/pi/config/agent/AGENTS.md`](../../../src/reasoning/agent-runtime/pi/config/agent/AGENTS.md) | The principle list links the new name and path. |
| [`.agents/skills/instruction-authoring/references/principle-skills.md`](../../../.agents/skills/instruction-authoring/references/principle-skills.md) | The exemplar names the new slug. |
| [`workflow/coding-agent/prompts/scope.md`](../../../workflow/coding-agent/prompts/scope.md) | Both citations name the new slug. |
| [`devlog/roadmap.md`](../../roadmap.md) | The iteration row closes; the `thing` sweep opens as its own row. |
| [`20261122-08-docs-provide_evidence.md`](20261122-08-docs-provide_evidence.md) | This record. |
