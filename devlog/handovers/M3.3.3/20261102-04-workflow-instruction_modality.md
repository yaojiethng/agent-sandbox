---
date: 2026-11-02
milestone: M3.3.3 - The skill maintenance pipeline
status: Closed
type: Workflow
---

# Handover - a sentence's kind is five, with one owner per claim

## Objective

Replace a three-word vocabulary that carried two meanings with five kinds ordered by the base a sentence appeals to and the force it carries, and give the definition, the decision and the obligation one home each.

## Scope

The roadmap row **A sentence's kind is five, and the taxonomy has one owner per claim**, in the task group **M3.3.3 - The skill maintenance pipeline**, section **The authoring surface it owns**.

The unit is the taxonomy and its carriers. It creates `.agents/skills/instruction-authoring/` as the home the obligation will live in, and lands the taxonomy there as that home's first content.

**Out of scope, one sentence each.** The carrier sheets, the frontmatter and naming rules, and the retirement of `skill-scaffolder` are the migration's own units, and each moves content rather than restating it. The four live `norm` carriers in the shipped principle corpus are in scope; `.agents/drafts/communication-domain-taxonomy-run.md` is a draft and is left alone.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The five kinds are defined once, in the glossary, and the definitions appear nowhere else | `grep -n '## modality' docs/reference/terminology.md`; `grep -rn 'deontic' docs/reference .agents/skills` returns the glossary, the ADR and the one obligation file | Agent [x]: one `## modality`; the glossary holds the bases, the ADR the decision, the skill the obligations, and no file restates another's part |
| `agent_workflow.md` describes the kinds and claims no ownership of them | read `### Instruction modality`; `grep -c 'one place the kinds are defined' docs/reference/agent_workflow.md` = 0; and the section carries no numbered ladder | Agent [x]: 0 matches for the ownership sentence, and no numbered ladder in the section |
| The decision is an ADR whose filename carries no purged term, with its earlier entries intact | `ls docs/adr/instruction_modality.md`; `grep -c '^## 2026-' docs/adr/instruction_modality.md` = 4 | Agent [x]: `docs/adr/instruction_modality.md`, 4 dated entries; `git show b62f598c -- docs/adr/instruction_modality.md` is a rename plus one added entry |
| The obligations each kind owes are stated once, in the instruction surface | `grep -n 'What each kind owes' .agents/skills/instruction-authoring/SKILL.md`; five numbered obligations, no restatement of the definitions | Agent [x]: five numbered obligations in the one file, which restates none of the definitions |
| `norm` is gone from live prose except where it is named as a deprecated token, or quoted as an example of a loose synonym | `grep -rn '\bnorm\b' --include='*.md' .agents docs scripts src workflow` returns the glossary entry, the ADR history, `align-the-mental-model`'s example row, and the draft | Agent [x]: the glossary's token note, the ADR's history and its rename note, one example row, and one draft |
| `statement` is not used as a kind anywhere | `grep -rn 'statement' --include='*.md' docs/reference .agents/skills` returns no classification use | Agent [x]: the glossary's deprecated note and ordinary prose senses only |
| Every pointer to the retired section name or the old ADR filename resolves, in the slug form and the prose form | `grep -rni 'norm.kinds' --include='*.md' docs .agents`; `bash scripts/lint.sh` linking gate | Agent [x]: the two inline pointers in `agent_workflow.md` read `### Instruction modality`; the one match left is the ADR's dated 2026-10-22 entry, which states what was true then; lint clean |
| The framework is cited, and the adaptation recorded rather than narrated | read the ADR's decision paragraph; `ls .agents/registry/citations/kratzer-relational-modality.json` | Agent [x]: the paper, its journal and the 2012 collection, the DOI, and the record of what was kept and dropped |
| `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are clean | both commands, read for their summary line | Agent [x]: `Lint: clean in 10s across 19 gates`; `1440 tests across 105 files, 1440 passed, 0 failed` |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Five kinds, ordered by base and force | The three-kind test asked only whether an artifact detects a breach, which is a question about enforcement rather than about the sentence; two cells went missing and produced defects nothing reports | `docs/adr/instruction_modality.md` |
| The framework is Kratzer's relational semantics | It derives the kinds from a base and an ordering source instead of asserting a list, so a new kind has to earn its cell, and permission and claim fall out as the two existential cells | same |
| The classification is a standard, not a rule, and no gate or ledger records it | The base and the standard are context the sentence does not carry, so a gate reading the sentence alone would guess; the retired ledger's 12-of-20 agreement is evidence for the claim rather than a defect to fix | same; `.agents/skills/instruction-authoring/SKILL.md` |
| `permission` is a kind, not a footnote to MAY | A reader told they may do a thing will do it, so a permission owes a granter; unnamed, it is a suggestion, and saying so is what stops advice being read as a grant | same |
| `claim` replaces `statement`, and `fact` is an evidenced claim | `claim` is already the genus in `linking` `## Citations`, and leaving `statement` in place kept two words for one kind | same |
| `norm` is purged, including from the ADR filename | The term carried the flavour of an unrestrained past and its ledger was the mistake this unit corrects, so a rename is a correction rather than churn; the glossary notes it as a deprecated token | glossary entry; the ADR |
| One owner per claim: decision in the ADR, definition in the glossary, obligation in the instruction surface, description in the reference | A reference may describe and may state what a procedure must not break; it may not own, which is what the section it replaces was doing | `docs/adr/instruction_modality.md`, the 2026-11-02 entry, which states the split for later claims |
| `.agents/skills/instruction-authoring/` is created as the obligation's home, with the taxonomy as its first content | The how-to corpus is where an obligation belongs, and creating the home first lets each later unit move content into it rather than rename it twice | `docs/adr/instruction_modality.md`; `.agents/skills/instruction-authoring/SKILL.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Splicing the `agent_workflow.md` section by first-occurrence `indexOf` matched the prose mention of the old heading rather than the heading, and removed `### Skill files` and `### Prompt templates` with it | measured | two sections of a shipped reference vanished, and the link gate caught it only because their anchors were still linked; a section nobody linked would have gone silently | this record: rebuilt by matching the heading line, and the whole file re-read for headings afterwards |
| `communication-principle-align-the-mental-model` keeps `norm` in its table of loose synonyms | measured | it is now an example of a word the repository has retired, which makes the row more true rather than less, so it is left as written | this record: deliberately not purged |
| `docs/development/prompt-authoring-conventions.md` still names itself as the authoring bar for skill files and prompt templates, in `agent_workflow.md` | measured | two documents claim to be the bar until the migration lands | `devlog/roadmap.md`, row **Move the documentation-writing and skill-writing guidelines under `skill-scaffolder`**, which retires the document and repoints both sentences |
| A permission and a claim both sit at possibility, so the pair is separated by base rather than by strength | measured | a reader who classifies by strength alone cannot tell a permission from a claim, which is the one place the two-question procedure has to be applied in order | this record: the file states the questions in order |
| A provisioned project receives seven convention-skills and not the instruction authoring bar | measured | the obligation this unit lands reaches no other project, and nothing named the gap | `devlog/roadmap.md`, row **An instruction-authoring convention joins the seeded corpus, or the gap is stated**; closed in `20261103-05` with the gap stated, because the corpus ships stubs |
| The record-certification audit reported that the task-list convention requires a closed row to name a class, `code`, `gate`, `data`, `record` or `procedure` | measured | the convention states the class at the scope gate and 8 of 101 closed rows carry one, so the requirement was invented and applying it would have added narrative to the row the same audit asked to shorten | this record: refused, with the reading named, so a later audit does not re-raise it |

## Completed

| File | Change |
|---|---|
| `.agents/skills/instruction-authoring/SKILL.md` | new: the obligation's home, with the five kinds, the two questions, the five obligations, why it is not a gate, and six smell tests |
| `docs/reference/terminology.md` | `## modality`: the five names, the bases and forces, the deprecated tokens, the scope that excludes artifact kinds |
| `.agents/registry/citations/kratzer-relational-modality.json` | the framework's paper, and what the taxonomy kept from it and dropped |
| `docs/adr/instruction_modality.md` | renamed from `norm_kinds.md`; the dated entry for five kinds by base and force, with four rejected alternatives; earlier entries intact |
| `docs/reference/agent_workflow.md` | `### Norm kinds` becomes `### Instruction modality`, describing the kinds and linking the three homes, with the ladder and the ownership claim removed |
| `docs/reference/documentation_taxonomy.md` | the policy row names the new ADR, and the index question and its anchor follow the renamed section |
| `docs/development/prompt-authoring-conventions.md` | both pointers name the new section and its anchor |
| `src/reasoning/providers/pi/config/agent/skills/principle-check-placement/SKILL.md` | the pointer names the new section and adds the glossary as the definition's home |
| `src/reasoning/providers/pi/config/agent/skills/principle-single-source-of-truth/SKILL.md` | four uses of the retired term replaced with `rule`, `judgement` or `sentence` |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-keep-a-subject-near/SKILL.md` | one use replaced |
| `docs/adr/coding_agent_loop_workflow.md`, `docs/adr/principle_skill_shape.md` | their links follow the ADR rename |
| `devlog/roadmap.md` | the unit's row, marked complete and compacted to its outcome and its homes; the seed question filed as an open row |
| `devlog/handovers/20261102-01-workflow-principle_rule_set.md` | status set to `Closed`, which this record's arrival made due |
| `devlog/handovers/20261102-04-workflow-instruction_modality.md` | this record |
