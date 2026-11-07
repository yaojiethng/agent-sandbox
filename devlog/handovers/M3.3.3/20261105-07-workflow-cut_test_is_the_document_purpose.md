---
date: 2026-11-05
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - the cut test is the document's purpose, and the principle is renamed

## Objective

`cut-what-carries-nothing` tested whether a sentence carried information, and information is not the question: a document has one purpose, fixed by its Diataxis mode, and a sentence that serves another mode's purpose is that document's, not this one's. The principle states that test, cites `principle-single-source-of-truth` as its ground, and is renamed to `communication-principle-cut-what-serves-nothing`, because the old name is a reader's routing surface and it names the test that was wrong.

## Scope

The operator's widening, in two steps: first the mode test, then its consequence -- that a sentence serving a neighbouring mode is a second source for a job another document maintains, so it goes and the reader is pointed at the document that does that job.

One file carries the judgement and eight carriers name it. The seed under `src/reasoning/providers/pi/config/agent/skills/` is what a delivery ships; the installed copy under `$AGENT_HOME/agent/skills/` is a bind mount and delivers nothing; the shipped index line carries the trigger; four principle skills name it in `**What it does not cover.**`; `project-documentation` and `scope.md` cite it; and the `writing-for-agents` fork names it inline twice, so the rename is a fork divergence its registry record now states.

Ruled out of scope: the quadrant-to-corpus map, which `docs/adr/documentation_quadrants.md` owns; and the `/iter` pass, filed as a row of its own.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The principle is named for the test it applies | `git ls-files \| rg -c 'cut-what-carries-nothing'` prints 0, and the path `.../cut-what-serves-nothing/SKILL.md` exists | Agent [x] |
| No live carrier names the old skill | `rg -n 'cut-what-carries-nothing' --glob '!devlog/**'` prints nothing | Agent [x] |
| The purpose is the test, and it is the Diataxis mode | `rg -n 'Diataxis mode' .../cut-what-serves-nothing/SKILL.md` prints the opening | Agent [x] |
| The mismatch cites the principle that grounds it | `rg -n 'principle-single-source-of-truth' .../cut-what-serves-nothing/SKILL.md` prints the citation | Agent [x] |
| The description and the shipped index carry the new trigger | the index line reads as the mode test, and the description names the neighbouring-mode case | Agent [x] |
| The seed and the installed copy are the same text | `diff -q` between them exits 0 | Agent [x] |
| The rename and its reason are recorded with the alternatives | `rg -n 'cut test is the document' docs/adr/principle_skill_shape.md` prints the entry | Agent [x] |
| The fork's names follow, and its record says so | `rg -n 'cut-what-serves-nothing' src/reasoning/agent/skills/writing-for-agents/SKILL.md` prints two references, and the registry record names the rename | Agent [x] |
| Every decision this unit recorded is realized in the files | the `## Decisions` table read against the tree | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The criterion is the document's purpose, and the name changes with it | the name is what a reader routes on, and a name stating the information test applies it whatever the body says | the skill, and the ADR entry |
| Diataxis is named and the quadrant map is not | the framework holds the mode vocabulary, and this repository's mapping from quadrant to corpus is `documentation_quadrants.md`'s | the skill, and the ADR entry |
| The mode mismatch is one case of `principle-single-source-of-truth` | two documents stating one job is a second source, which the principle already defines as one subject in one mode | the skill's opening, and the ADR entry |
| The fork's references follow the rename and its record carries the divergence | a fork that silently diverges stops being a fork anyone can compare, and a dangling name is worse than a recorded one | the registry record |
| Both the seed and the installed copy take the change | the seed ships and the installed copy is what this session reads; an edit to one alone leaves the other asserting the old test | the two skill files |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The old name asserted an information test the body had already abandoned, so a reader routing on the name applied the test the principle exists to replace | defect, text | the name is the routing surface, so the corpus answered the wrong question before the body was read | this unit |
| The first cut of the mode test stated it three times -- three example readers, then the rule, then the restatement -- and kept a table row repeating the trim rule | defect, text | the principle asked for the trim it describes, in the document that states it | this unit, on the operator's reading |
| A rename in this corpus is a divergence in the vendored fork, whose record must state it | drift | the fork's inline names are the reason it is a fork, so a stale one is an unrecorded divergence | this unit, in the registry record |
| The `/iter` prompt carries explanation its reader cannot act on -- `This is the collapsed gate the operator-involved workflows share`, and `There is no document registry; the docs tree is the authoritative file list` | defect, text | a how-to's reader spends attention on the workflow's architecture where the next step is what they need | the roadmap row **The `/iter` prompt carries what a how-to reader cannot use** |

## Completed

| File | Action |
|---|---|
| [`src/reasoning/providers/pi/config/agent/skills/communication-principle-cut-what-serves-nothing/SKILL.md`](../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-cut-what-serves-nothing/SKILL.md) | renamed from `cut-what-carries-nothing`; the purpose is the test, the mismatch is one case of the SSOT unit, and the description and `Fires on` carry the new trigger |
| `/home/agentuser/.pi/agent/skills/communication-principle-cut-what-serves-nothing/SKILL.md` | the installed copy, renamed and edited to the seed's text; it delivers nothing |
| [`src/reasoning/providers/pi/config/agent/AGENTS.md`](../../src/reasoning/agent-runtime/pi/config/agent/AGENTS.md) | the index line states the purpose test instead of the sentence test |
| [`docs/adr/principle_skill_shape.md`](../../docs/adr/principle_skill_shape.md) | the dated entry for the rename, the Diataxis ground and the three rejected alternatives |
| [`src/reasoning/agent/skills/writing-for-agents/SKILL.md`](../../src/reasoning/agent/skills/writing-for-agents/SKILL.md) | the fork's two inline references follow the rename |
| [`.agents/registry/sources/mattpocock-skills.json`](../../.agents/registry/sources/mattpocock-skills.json) | the fork's record now names the rename among its divergences |
| four principle skills, [`project-documentation`](../../.agents/skills/project-documentation/SKILL.md), [`scope.md`](../../workflow/coding-agent/prompts/scope.md) | each cross-reference takes the new name |
| [`devlog/roadmap.md`](../roadmap.md) | the `/iter` row, filed from the operator's worked case |
