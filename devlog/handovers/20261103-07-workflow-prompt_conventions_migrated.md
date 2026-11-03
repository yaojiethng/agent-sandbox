---
date: 2026-11-03
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - the prompt and skill conventions moved into the skill that reads them

## Objective

Make `docs/development/prompt-authoring-conventions.md` hold only what has no home elsewhere, by moving every rule into the `instruction-authoring` skill, which is where a writer starts. Each move was proposed as one decision with both homes quoted, and landed on the operator's verdict.

## Scope

`docs/development/prompt-authoring-conventions.md` (239 lines, 21 sections, cited by 108 files) and the homes it duplicated: `.agents/skills/instruction-authoring/` (293 lines), `scripts/lint/document-shape.mjs`, `.agents/skills/linking/`, `.agents/skills/project-documentation/runbooks/doc-maintenance/SKILL.md`, `src/reasoning/agent/skills/writing-for-agents/SKILL.md`, and `docs/reference/agent_workflow.md`, `terminology.md`, `conventions.md`.

Out of scope: the `instruction-authoring` skill's own body, except where a rule moved into it; and the drafts the document used to route to.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The document holds no rule that has a second home | `wc -l` 13; what remains is the landing page and the draft gate | Agent [x] |
| Every moved rule landed in a named home, and the diff shows it | the decision table below, one row per move | Agent [x] |
| The term the deleted section defined is still defined | `docs/reference/terminology.md` `## workflow document`, added when the loss was found | Agent [x] |
| The carrier judgement is recorded rather than lost with the sentence | `docs/adr/instruction_modality.md`, 2026-11-03 entry | Agent [x] |
| The gates and the suite pass | 20 gates clean; suite green apart from `test_doc_wrap_legacy_gate.sh`, which exceeds its 45s deadline under parallel load and passes alone (5/5) | Agent [x] |

## Decisions

| Unit | Fact | Verdict | Landed in |
|---|---|---|---|
| prep | a `.agents/skills/<name>/` path is legal from a shipped document only where `initialize` seeds it | accept | `linking` `## What to link` |
| prep | an unparseable frontmatter block fails the gate | accept | `prompt-conventions.md` `## Frontmatter` |
| D1 | the five questions and their 26 skill links | accept: keep `skill-conventions.md`'s copy | deleted |
| D2 | the principle shape table | accept: the skill's sentence and the gate own it | deleted; gate header repointed |
| D3 | prompt and skill frontmatter | accept: the skill's two reference sheets own it | deleted, the gate sentence kept |
| D3b | a router skill names the others and when to reach for each | accept: homeless until now | `signposting.md` |
| D3 | the skill naming scheme | accept: move, since it lived nowhere else | `signposting.md` |
| D4 | the information hierarchy | accept: the shipped `writing-for-agents` already carries it, branch test included | deleted, nothing moved |
| D5 | where a reference resolves | accept: `linking` and the taxonomy's reach table own it | deleted |
| D6 | draft status | accept: keep, the sole owner | kept, incident reduced to a clause |
| D7 | "the fourteen loop prompts and the six module skills" | accept: already false (16 and 9) | replaced by one exemplar |
| P1 | purpose, scope and compliance | accept, with "the bar" not propagated | landing page; 4 referrers repointed |
| P2 | identify the document type | accept | deleted; the boundary sentence moved to the skill's front door |
| P3 | the information hierarchy | accept | deleted |
| P4 | runbook versus advisor versus skill | accept as amended: the advisor contract moves, and the form *choice* lands in `forms.md` | `forms.md`, `prose-review` |
| P5 | the body-shape residue | accept as amended: general, type and form are three axes | `forms.md`; the absolute sentence deleted, not replaced |
| P6 | scope a prompt's subject | accept as amended: step 1 is the durable home | the closure rule in `SKILL.md` step 1; the rest deleted |
| P7 | naming and the four pointer sections | accept | deleted |
| P8 | the draft rule | accept | kept, shrunk |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| "A prompt is never the only source of truth for a rule" was a copy that had drifted out of `agent_workflow.md` `### Where the rules live` and into a false absolute | defect | the sentence contradicted the retired-policy doctrine, and no reader could recover the reason for it | deleted; the carrier judgement recorded in the ADR |
| P2 deleted the tree's only definition of "workflow document", which 31 files use | defect in this unit | a term in wide use with no definition | restored in `terminology.md`, found by the operator's question |
| The document's counts of loop prompts and module skills were already wrong | defect | an authoring document stated a false model | deleted |
| Its compliance section routed readers to two drafts, which its own draft rule calls unreachable | defect | a reader was sent where the gate says nothing lives | deleted |
| `agent_workflow.md:118` is prompt-scoped; quoting it as the general rule was a reading error in the review, not a defect in the file | correction | the general rule is three lines above it | none |
| `docs/development/conventions.md` now indexes two rows where it had one | expected | the draft gate is a second, smaller entry | the file itself |

## Completed

| File | Change |
|---|---|
| `docs/development/prompt-authoring-conventions.md` | 239 to 13 lines: a landing page and the draft gate |
| `.agents/skills/instruction-authoring/references/forms.md` | new: the shared body shape and the three forms |
| `.agents/skills/instruction-authoring/SKILL.md` | the closure rule in step 1, the form sheet in step 3, the carries row |
| `.agents/skills/instruction-authoring/references/prompt-conventions.md` | the frontmatter gate sentence |
| `.agents/skills/instruction-authoring/references/skill-conventions.md` | the exemplar, the trigger rule, and the owner of the shape |
| `.agents/skills/instruction-authoring/patterns/signposting.md` | the naming scheme and the router rule |
| `.agents/skills/linking/SKILL.md` | the seeding rule |
| `.agents/skills/project-documentation/runbooks/doc-maintenance/SKILL.md` | stale accumulation joins the register; the owner repointed |
| `docs/adr/instruction_modality.md` | the carrier judgement, 2026-11-03 |
| `docs/reference/terminology.md` | `## workflow document` |
| `docs/reference/agent_workflow.md` | the owner repointed, twice |
| `docs/development/conventions.md` | two rows where it had one |
| `workflow/coding-agent/skills/prose-review/SKILL.md` | the advisor form's home |
| `scripts/lint/document-shape.mjs` | the header names the skill's references, not the document |
| `devlog/roadmap.md` | the row closes |
