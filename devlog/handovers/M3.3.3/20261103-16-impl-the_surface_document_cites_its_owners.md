---
date: 2026-11-03
milestone: M3.3.3 - The skill maintenance pipeline
type: Implementation
status: Closed
---

# Handover - the surface document cites its owners

## Objective

Apply the prompt-authoring treatment to `instruction-surface-conventions.md` where a section states a rule another file already owns, and leave the declarations in place.

## Scope

In scope: four sections of the document, and the review runbook that gains the ruling vocabulary.

Out of scope: the layer-filing test, which the reach-and-scope row absorbs, and the subject table, which becomes generated data in that same row.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The copy step names the manifest | `grep -n 'provision' docs/development/instruction-surface-conventions.md` | Agent [x] |
| `## The gates` states one rule per header | `sed -n '/## The gates/,$p' docs/development/instruction-surface-conventions.md` is a table | Agent [x] |
| The corpus and its stub form are cited | `grep -n 'initialize' docs/development/instruction-surface-conventions.md` | Agent [x] |
| The five rulings live in the procedure that produces them | `grep -n 'keep.*move.*split' workflow/coding-agent/skills/prose-review/runbooks/instruction-cleanup/SKILL.md` | Agent [x] |
| `bash scripts/lint.sh` is clean | twenty gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The ruling vocabulary moves to `instruction-cleanup` | A ruling is what that review produces, and the surface document was only the place the labels happened to be written; a vocabulary belongs to the procedure that emits it | `instruction-cleanup` `## Returns` |
| The layer-filing test and the subject table leave this pass | Both are the reach-and-scope axis, which the roadmap row now carries | `devlog/roadmap.md` |
| `## The gates` keeps a table and drops seven restatements | Each script's header is the owner the document itself names, and seven prose copies drift independently | this handover |

## Decisions pending

None.

## Findings

- The document's own argument, that "a rule about where sections belong is maintenance material", is the test this pass applied to its own sections.

## Completed

| File | Change |
|---|---|
| `docs/development/instruction-surface-conventions.md` | the copy step cites the manifest, the corpus cites `initialize`, the rulings cite the runbook, and `## The gates` is a table |
| `workflow/coding-agent/skills/prose-review/runbooks/instruction-cleanup/SKILL.md` | the five rulings are stated where they are produced |
| `devlog/roadmap.md` | the reach-and-scope row names the subject table |
