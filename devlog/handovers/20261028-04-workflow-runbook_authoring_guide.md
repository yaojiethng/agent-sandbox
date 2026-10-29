---
date: 2026-10-28
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - The runbook authoring guide

## Objective

Make the runbook authoring guide a reference under the shell: write the centre first, state what a runbook accepts and returns, and leave the rest to the review.

## Scope

Opens the M3.2.2 row **The runbook authoring guide states its questions as prose**, raised 2026-10-28 while landing `novel-bug-hunter` (commit `7b5b8c04`, no handover).

In scope: the authoring guide, its place under `code-review/references/`, the shell's one-line pointer, and the audit and trim of the two in-repo runbooks the old format shaped (`code-review-bash` and `code-review-container`). Out of scope: the vendored runbooks (`thermo-nuclear-code-quality-review`, `kelsey-code-reviewer`), which do not use the slots and carry provenance claims a restructure would falsify.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The guide is a reference under `code-review/references/`, linked from the shell in one line | read the shell and the guide | Agent [x] |
| The guide tells the author to write the centre first and state what the runbook accepts and returns; everything else is the review's own | read the guide | Agent [x] |
| `Focus` is gone from both in-repo runbooks, and no live text names it | `grep -rn Focus workflow/coding-agent/skills/code-review/` | Agent [x] |
| The bash boundary list carries no dead bullet | read `code-review-bash/SKILL.md` | Agent [x] |
| The roadmap row is closed with its landing note | grep the row | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The guide is a disclosed reference under the shell, not a top-level doc and not shell prose | it is authoring guidance, read only when a runbook is written; the shell stays an index | this handover |
| Two statements are required: what the runbook accepts and what it returns | the shell dispatches on the first and reads the second back; everything else is the review's own | this handover |
| The author writes the centre before those statements | the old slot order flattened a runbook's subject when the form led, which is what happened to `novel-bug-hunter` | this handover |
| `Focus` is removed from both in-repo runbooks | the text appeared only in the template; no shell, dispatch or terminology text ever passes a focus, so the section was unused scaffolding | this handover |
| The bash formatter bullet is removed | no formatter runs in this repository, so the boundary excluded nothing | this handover |
| The narrowed-run verdict clause is removed with `Focus` | no run is narrowed, so the clause described an unreachable case | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `Focus` was a template slot with no caller: the shell, the dispatch reference and the terminology never pass a focus, so both in-repo runbooks carried a section nothing used | defect | removed from both runbooks, and the guide no longer offers it | fixed in this iteration |
| The bash runbook's `Does not judge` excluded "anything a formatter settles", and no formatter runs here | defect | the bullet is removed | fixed in this iteration |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/skills/code-review/references/authoring.md` | new: the authoring guide |
| `docs/reference/review_runbook_template.md` | deleted; the guide replaces it |
| `workflow/coding-agent/skills/code-review/SKILL.md` | one line points at the guide |
| `workflow/coding-agent/skills/prose-review/SKILL.md` | the pointer to the deleted template is removed |
| `workflow/coding-agent/skills/code-review/runbooks/code-review-bash/SKILL.md` | `Focus` removed; formatter and narrowed-run clauses removed |
| `workflow/coding-agent/skills/code-review/runbooks/code-review-container/SKILL.md` | `Focus` removed; narrowed-run clause removed |
| `devlog/roadmap.md` | the row is marked and closed |
| `devlog/handovers/20261028-04-workflow-runbook_authoring_guide.md` | this handover |
