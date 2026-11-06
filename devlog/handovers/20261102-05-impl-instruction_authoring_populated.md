---
date: 2026-11-02
milestone: M3.3.3 - The skill maintenance pipeline
status: Closed
type: Implementation
---

# Handover - the authoring skill holds both carriers

## Objective

Make `.agents/skills/instruction-authoring/` usable for both subjects it owns: a writer arriving with "write a prompt" or "write a skill" finds the carrier decision, the project-conventions block rule, the drafting steps, and a sheet per carrier, and the two sheets stop being files nothing loads.

## Scope

The roadmap row **`instruction-authoring` is populated for both carriers**, in the task group **M3.3.3 - The skill maintenance pipeline**, section **The authoring surface it owns**.

The unit is the front door and what it must reach. `SKILL.md` gains the carrier table, the `## Project conventions` block rule, the steps, and an index naming each sheet and sibling with the situation that opens it. The two carrier sheets become tracked, and the siblings they cite arrive beside them so their links resolve. The ADR gains a dated entry, because the framing this unit writes is a decision its glossary of kinds already half-states.

**Out of scope, one sentence each.** Retiring `skill-scaffolder` is row 2, which deletes it and repoints its carriers; retiring `docs/development/prompt-authoring-conventions.md` is row 3; seeding this skill into the provisioned corpus is its own open row; and `patterns/prose-entrypoint.md` is a scaffolder mechanic no sheet cites, so it waits for row 2.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The front door names both carriers and links the sheet each opens | `grep -c 'references/\(prompt\|skill\)-conventions.md' .agents/skills/instruction-authoring/SKILL.md` >= 2, and the linking gate passes | Agent [x]: 4 occurrences across the carrier table and the index, both links resolving |
| Every file the skill carries is named by the front door | iterate `find .agents/skills/instruction-authoring -type f -not -name SKILL.md` and grep each basename in `SKILL.md`; nothing is printed | Agent [x]: no unindexed file |
| The `## Project conventions` rule is stated once, in the front door, and the prompt sheet defers to it | `grep -c 'Project conventions' SKILL.md` = 1; `grep -c 'seeded stub' references/prompt-conventions.md` = 0 | Agent [x]: 1 and 0 |
| No live sentence in the skill says `skill-scaffolder` holds the mechanics | `grep -rc 'skill-scaffolder' .agents/skills/instruction-authoring/` sums to 0 | Agent [x]: 0 files mention it |
| Every sibling the two sheets cite is tracked beside them | `git ls-files .agents/skills/instruction-authoring` lists six files: `SKILL.md`, both sheets, both patterns, `runbook/review.md` | Agent [x]: six paths |
| The five kinds are one table, and the derivation is cited rather than restated | `grep -c 'deontic\|epistemic\|Kratzer\|RFC 2119' .agents/skills/instruction-authoring/SKILL.md` = 0; the glossary, the ADR and the citation hold the framework | Agent [x]: 0 hits; 61 lines, from 76 |
| The framing is stated once, and no live file calls the kinds a per-sentence classification a reader applies | `grep -rn 'applied by a reader' docs .agents` returns only records of what was decided then | Agent [x]: two hits, both the ADR's historical entries; the live ADR entry, the skill, `agent_workflow.md` and the citation record all state the tool framing |
| A writer holding only the front door picks the right carrier twice | one `pi -p` run given `SKILL.md` alone, asked to place a prompt and a skill | Agent [x]: `references/prompt-conventions.md` and `references/skill-conventions.md`, no other file read |
| `agent_workflow.md` describes the concept and delegates its vocabulary | `grep -c deontic`, `grep -c epistemic` and `grep -c 'RFC 2119'` over `docs/reference/agent_workflow.md` are each 0, and the section names the glossary, the ADR and the convention | Agent [x]: 0, 0, 0; all three homes named |
| The ownership rule has one statement, and it is the authoring skill's to place | `grep -c 'The document whose workflow produces' docs/reference/agent_workflow.md` = 0; `grep -c 'one source serves them all'` = 1 in `.agents/skills/instruction-authoring/SKILL.md` and 0 in `agent_workflow.md` | Agent [x]: 0, 1, 0 |
| The dispatch indexes on the authoring intent, not on the taxonomy | the description's first clause names a prompt or a skill, and a kind name appears no earlier | Agent [x]: "Writing or reviewing a prompt or a skill: ...", the five kinds third in the list |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The modality text stays top-level in `SKILL.md`, and the disclosure boundary is the carrier, not the kind | Every invocation classifies a sentence before it drafts; the carrier mechanics are read once a carrier is chosen, so that is the only cut where progressive disclosure saves a read instead of adding one | this record |
| Only the siblings the two sheets cite arrive with them; `patterns/prose-entrypoint.md` waits for row 2 | A sheet that cites a file the skill does not carry is the unindexed-sibling defect one level down, and the link gate refuses it; a pattern nothing cites has no reader yet | this record |
| The frontmatter sentence naming `skill-scaffolder` as the mechanics' home changes in this unit | Row 1 is what makes it false, so leaving it would land a self-contradicting skill | this record |
| The `## Why this cannot be a gate` argument is not trimmed here | It is a quality question about text the operator approved, not a defect this unit creates, and it would mix a rewrite into a population commit | this record |
| This unit carries the three siblings the sheets cite, and row 2's sentence is corrected in its write-back | The alternative lands two sheets whose links point at files the skill does not carry, which the linking gate refuses; retiring the scaffolder first would kill the replacement before it can be read | `devlog/roadmap.md`, row **`skill-scaffolder` retires into `instruction-authoring`** |
| Classification is a diagnostic for a sentence that reads wrong, not the first step of a draft | The retired ledger died of typing one pair per sentence, and a drafting order that begins there reinstates that typing as a procedure no second reader can replicate; one purpose and one concern is the test two readers apply the same way | this record; `docs/adr/instruction_modality.md` `## 2026-10-22` already states the same failure, so no new ADR entry |
| The five kinds are tools for choosing a mechanism, not a classification of a sentence, and strength is bought by what holds the sentence rather than by its kind | Prose and a gate can carry one rule, and the gate holds it tighter; the question a writer can answer is whether the mechanism fits the problem, while a per-sentence assignment is one two readers disagree about with nothing to report it | `docs/adr/instruction_modality.md`, the 2026-11-02 entry on tools, which supersedes the same day's "classification is a standard" framing |
| The framework is cited, not restated: the skill states what each kind means for the writer and points at the ADR and its citation for the derivation | A citation is written better than a restatement of it, and a restatement is a second copy that goes stale; the test for a writer is what the kind demands, not where the kind came from | this record |
| The architecture section describes the concept and points; it does not restate the vocabulary | Applying `writing-for-agents` `## Information hierarchy`: inline what every branch needs, push behind a pointer what only some do. A reader of the map needs to know the concept exists and what it buys; the base and the force are read by the writer who applies them | this record; the rule is `writing-for-agents`'s, so nothing new was added to hold it |
| `What lives where` is deleted, and the description indexes on the authoring intent rather than on the kinds | The table's rows were provenance in the place a drafter looks first: two said "this file" and "the derivation is elsewhere", and only the placement rule changed a reader's next action. The description opened on `kinds`, so a reader arriving with "write a skill" met the taxonomy before the trigger | this record |
| The source-of-truth paragraphs leave the architecture map: the rule about where a shared judgement lives is the authoring skill's, and which document owns what is `principle-single-source-of-truth`'s | The map described an ownership rule it does not own, and the rule had two statements in one section; placing a judgement is what a writer does mid-draft, which is where the authoring skill is read | this record; `principle-single-source-of-truth` already states the ownership half, so it was neither copied nor edited |
| The two questions, the RFC 2119 sentence and the six smell tests are deleted | The questions placed a sentence by its base and force, which is the classification this unit removes; the smell tests restated the five rows in the negative and named no rule the rows do not | this record |
| The `## Why this cannot be a gate` argument is reframed rather than trimmed | Its claim survives the new framing (a gate would read the sentence and guess), but its opening said the taxonomy is a standard, which is the sentence this entry replaces | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `20261102-04` triages its authoring-document finding to the row title this session replaced with three rows | record | a closed record now points at a row that no longer exists, so a reader cannot follow it in one hop | this record: left as written, because a record's past is not rewritten; row **`prompt-authoring-conventions.md` retires** states the same subject, so the pointer is still walkable |
| A shipped document cannot name this skill's `SKILL.md` until the convention joins the seeded corpus, so row 3's six carrier repoints have no path to write | gate | the retirement has a carrier form it may not use, which would push it toward a wording workaround | `devlog/roadmap.md`, row **An instruction-authoring convention joins the seeded corpus, or the gap is stated** |
| `nested-patterns.md` and `project-documentation`'s `references/organization.md` state two rules about one situation - a file that outgrew its place - and neither names the other | measured | a writer who reads one applies half the rule, and the two defects they name are different: an unindexed sibling, and a document carrying two diataxis modes | `devlog/roadmap.md`, row **The rule about a file that outgrew its place names its other home** |
| The M3.3.2 section still carries its eight-row checklist, five closed rows still carry implementation narrative, and three rows are superseded by later ones | record check | a reader of the roadmap reads a closed sub-milestone as work in flight, and two rows assert a state a later row replaced | `/milestone-close`, which owns compaction; not filed as a row, since a row would restate a step that prompt already runs |
| `devlog/roadmap.md:260` names `src/reasoning/agent/skills/source-catalog.json`, which the tree does not hold, and `:275` carries the pstack version literal instead of naming the file that owns it | record check | a path that does not exist cannot be followed, and a version literal in a closed row goes stale silently | `/milestone-close`, in the same compaction pass |
| The review proposed merging rows 290, 291 and 296, which it read as one subject with no owner distinguishing them | record check | the merge would reverse this session's ruling that populate, retire the scaffolder and retire the document are three tasks with three outcomes | this record: refused; the split is the operator's, and each row's end state names a different artifact |
| Three of the criteria verify by exact string, so a live file restating a rule in different words would pass | measured | the criterion asserts a string rather than the reading it stands for | this record: the read-only review read the live files and found no restatement; the criteria are left as stated rather than widened |

## Completed

Roadmap maintenance check, before the scope gate: `20261102-04` is `Closed`, its row carries `[x]`, and M3.3.3 reads `In progress`, so no maintenance run was due.

| File | Change |
|---|---|
| `.agents/skills/instruction-authoring/SKILL.md` | 58 lines: the five kinds as one table of what each means for the writer, the carrier table, the drafting steps, the sibling index and the `## Project conventions` rule; the description opens on "Writing or reviewing a prompt or a skill"; every sibling and every outside home it names is a link |
| `docs/adr/instruction_modality.md` | a dated entry: the kinds choose a mechanism, and a rule's strength is bought by what holds it |
| `docs/reference/agent_workflow.md` | `### Instruction modality` states what the concept is for in two paragraphs and names its three homes; the base-and-force definition, the five-name list and the RFC 2119 clause are gone, as are the two source-of-truth paragraphs, whose rule now lives in the authoring skill; the two lines that pointed at them repoint |
| `.agents/registry/citations/kratzer-relational-modality.json` | the `added` field's inference corrected: what the framework does not draw is a judgement about the problem, not a standard a reader applies; committed alone, in a commit of its own |
| `docs/development/prompt-authoring-conventions.md` | two pointers to `### Instruction modality` repointed: the duplicated placement rule is deleted, and the kind-decides-the-source rule points at the ADR. The rest of the document waits for row 3 |
| `devlog/AGENT_FEEDBACK.md` | `## Node`: the recurrence of a splice anchored on a heading string that the prose also names |
| `.agents/skills/instruction-authoring/references/prompt-conventions.md` | tracked; its `../SKILL.md` pointer becomes true |
| `.agents/skills/instruction-authoring/references/skill-conventions.md` | tracked |
| `.agents/skills/instruction-authoring/patterns/signposting.md`, `patterns/nested-patterns.md` | arrive so the skill sheet's citations resolve |
| `.agents/skills/instruction-authoring/runbook/review.md` | arrives so both sheets' review pointer resolves, with its bars repointed at this skill and `writing-for-agents` |
| `devlog/roadmap.md` | row **`instruction-authoring` is populated for both carriers** closed to its outcome; row **The rule about a file that outgrew its place names its other home** opened; row **`skill-scaffolder` retires into `instruction-authoring`** now says its remaining pattern joins two, since this unit moved the other two |
