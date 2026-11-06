---
date: 2026-10-28
milestone: W2 - Communication Domain Taxonomy
type: Design
status: Closed
---

# Handover - The leitwort field's definition

## Objective

State what `metadata: leitwort:` is: the one word a skill's body is written around, where it is recorded, how it is chosen, and the guard that keeps it from becoming a flavour word.

## Scope

Opens the W2 row **Populate the leading words across the corpus**, at its definition half; the row's population pass stays open behind it. In scope: the definition in `communication-principle-maximize-conceptual-leverage`, the plain-style rewrite of `skill-scaffolder`'s signposting pattern, the W2 row, and the open `AGENT_FEEDBACK` entry the definition mitigates. The task is filed out of order against W2; the milestone is not promoted. Out of scope: naming a word for any further skill, the signalling experiment, and any gate over the field -- presence is all a gate can read and no gate sees a thinking trace.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The field is defined: one compact concept, recorded at `metadata: leitwort:`, set only where the body teaches it, speaking of a skill | read `**The pattern.**` and `**Placing it.**` | Agent [x] |
| `signposting.md` names the field as the recording site | `grep -c 'metadata: leitwort' .agents/skills/skill-scaffolder/patterns/signposting.md` | Agent [x] |
| The W2 row records the definition half closed, population still open | `grep -A8 'Populate the leading words' devlog/roadmap_future.md` | Agent [x] |
| The feedback entry is `mitigated`, and its mitigation names the definition | `sed -n '/A vocabulary was chosen/,+6p' devlog/AGENT_FEEDBACK.md` | Agent [x] |
| `signposting.md` is rewritten in the plain style: short sentences, a direct instruction, a test | read the file | Agent [x] |
| The leverage principle is about the leitwort, not general word choice | read the file | Agent [x] |
| W2 stays `Not started`; the unit is filed out of order | `grep 'W2 - Communication Domain' devlog/roadmap.md` | Agent [x] |
| Every decision in the handover is realised in the files | the Decisions table against `git diff` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The field is defined for any skill, not only a principle skill | the effect is on the skill's text, and the signpost pattern already governs every skill | this handover |
| The definition lives in `maximize-conceptual-leverage`; placement and the test stay in `signposting.md` | one owner for what the word is and which word leads, one for where it goes | this handover |
| The word is set only where the body already teaches it | the 2026-10-21 pass chose words for flavour and defended them afterwards; a defence written after the choice cannot fail | this handover |
| The effect is stated as a mechanism, not a measured claim | one word repeated at the signpost and at the rule gives the agent one direction; no gate measures the effect | this handover |
| The word need not appear in the name | the name is the shortest true summary of the description; `sediment` is the standing counterexample | this handover |
| The scaffolder's standard template does not carry the field | the template shows what the gate requires; an optional field in it invites a defaulted word | this handover |
| W2 is not promoted | the task is filed out of order, and the milestone stays `Not started` until its dependencies land | this handover |
| The signposting pattern is rewritten in the operator's plain style | the old text stacked aphorisms; the new text gives a direct instruction, a short reason and a test | this handover |
| The leverage principle is focused on the leitwort | the general word-choice framing buried its one device; the body now chooses a leitwort and anchors the text around it | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The placement authority never names the field: `signposting.md` states the three-fold test and the word's placement, and says nothing about where the word is recorded, so a reader who lands there cannot find `metadata: leitwort:` | gap | one sentence naming the field is added to the placement paragraph | fixed in this iteration |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-maximize-conceptual-leverage/SKILL.md` | rewritten around the leitwort: the definition, the guard, the two anchors, `leitwort: leitwort` |
| `.agents/skills/skill-scaffolder/patterns/signposting.md` | rewritten in the plain style; names the field as the recording site |
| `devlog/roadmap_future.md` | the W2 row gains the closed definition sub-row, population still open |
| `devlog/AGENT_FEEDBACK.md` | the 2026-10-21 entry moves to `mitigated` |
| `devlog/handovers/20261028-06-design-leitwort_definition.md` | this handover |
