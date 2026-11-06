---
date: 2026-11-03
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - the draft gate moves to the skill, and the conventions document retires

## Objective

Retire `docs/development/prompt-authoring-conventions.md` by placing its last unique rule - an unreleased prompt lives in `.agents/drafts/`, and release is the move - where a writer already reads, so no live file names the document.

## Scope

The document (13 lines after `20261103-07`), `instruction-authoring`'s front door, `/scope`'s hand-off options, and every live referrer: `docs/development/conventions.md`, `docs/adr/skill_layer_resolution.md`, `docs/adr/principle_skill_shape.md`, `docs/adr/documentation_quadrants.md`, `docs/adr/diff_packaging.md`, `.agents/skills/project-documentation/references/greenfield.md`, `devlog/roadmap.md`, `scripts/check_document_shape.sh`.

The operator proposed the placement and then asked whether the release paragraph should become a runbook. It does not, yet: by the skill's own `patterns/nested-patterns.md` `## The size floor`, a sibling earns its file by the length of the form it carries or by a situation a reader can name, and this is one situation with one caller. It becomes `runbook/promotion.md` when a second prompt promotes rather than parks, or when the procedure outgrows the step.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No live carrier names the document | `grep -rn prompt-authoring-conventions scripts/ tests/ src/ workflow/ .agents/ docs/ devlog/roadmap.md` returns only `docs/adr/` entries and roadmap rows, which are dated records | Agent [x] |
| The draft rule has a home | `instruction-authoring` `SKILL.md` step 6 | Agent [x] |
| The write-back the rule served is reachable | `scope.md` `## Hand off`, the parked-prompt option | Agent [x] |
| The document's own index row is gone, and the gate's header names its new owner | `docs/development/conventions.md`; `scripts/check_document_shape.sh` header and failure message | Agent [x] |
| The gates and the suite pass | 20 gates clean; `test_document_shape` 11/11; references clean | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Landing a draft costs nothing; the review gates the release, not the parking | The state exists so a workshopped prompt can wait. Requiring a review to park one makes the folder useless for its own case | `SKILL.md` step 6 |
| Release takes a review when an agent wrote the artifact, and offers one when the operator did | The recorded incident is a worker-authored prompt switched into live use unread; a review the operator must pay for on their own text is a tax with no defect behind it | `SKILL.md` step 6 |
| An author the releasing session cannot attribute takes the review | A promotion with no attribution is the case the rule exists for, so it fails safe | `SKILL.md` step 6 |
| The release procedure stays a step, not a runbook | One caller, one situation, ten lines; `nested-patterns.md` `## The size floor` decides it | this record |
| Home A over a new `drafts` convention-skill (B) | A new skill for five sentences spends the index budget this milestone is shrinking; B becomes right when `/handoff` or a third gate promotes | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `documentation_quadrants.md` dated the retirement 2026-11-02, a day early | defect | a decision record stated a false date | corrected in place |
| `diff_packaging.md` cited a section of the document that no longer existed (`## A workflow document owns one step, and owns it whole`) | defect | a stale citation in a live record | repointed to `principle-single-source-of-truth` |
| `principle_skill_shape.md` still cites the document's `## The five questions` and `## The principle claims` in its dated entries | record | point-in-time entries, and no link, so the gate is silent | left as written; the entries record the state at their decision date |
| `roadmap.md` open rows 304 and 306 name the document | record | they describe work raised while it existed | left as written; a row's own text is its history |
| 107 files cite the retired path, all but these in handovers, discussions and `archive/` | record | historical, not live | none |

## Completed

| File | Change |
|---|---|
| `docs/development/prompt-authoring-conventions.md` | deleted |
| `.agents/skills/instruction-authoring/SKILL.md` | step 6: the draft state and the release rule |
| `workflow/coding-agent/prompts/scope.md` | the parked-prompt option beside the saved brief |
| `docs/development/conventions.md` | the draft-gate row removed |
| `docs/adr/skill_layer_resolution.md` | the link repointed to `skill-conventions.md` |
| `docs/adr/principle_skill_shape.md` | the shape's location named as the skill's reference |
| `docs/adr/documentation_quadrants.md` | the retirement date corrected |
| `docs/adr/diff_packaging.md` | the stale section citation repointed |
| `.agents/skills/project-documentation/references/greenfield.md` | the authoring pointer repointed |
| `scripts/check_document_shape.sh` | header and failure message name the skill's references |
| `devlog/roadmap.md` | the retirement row closes |
