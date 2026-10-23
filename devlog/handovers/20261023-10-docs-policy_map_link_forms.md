---
date: 2026-10-23
milestone: M3.3.2 - Retire the policy form
type: Documentation
status: Closed
---

# Handover - The policy map's link forms

## Objective

State, beside the Policy Map, which form a `Document` cell takes and why, so the nine cells the linking gate read as prose are accounted for rather than silently unlinked.

## Scope

The roadmap row **A table cell that names a document is a link, or nothing resolves it**, under M3.3.2. The row's second branch is the one this iteration takes: the table states why a cell is unlinked, because `agent_workflow.md` ships into the image and the linking convention names a target a shipped document cannot reach.

The operator directed this iteration from the check-in inventory as **autopilot**; that direction is this iteration's release for both gates, so the scope proposal, acceptance criteria, pre-close summary and release gate are presented in the iteration report rather than awaited.

Out of scope: converting cells to image-path links. A cell naming the module skills, the module prompts, the provider config or a project-only root cannot be linked from a shipped document, and an absolute image path would be unopenable to the repository reader.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The Policy Map states the form each `Document` cell takes, naming the linking convention and the reach table it follows | `sed -n '/^## Policy Map/,/^### Boundary notes/p' docs/reference/agent_workflow.md \| grep -c 'Every cell names its document'` returns 1 | Agent [x] |
| No `Document` cell links a project-only root or a target read at another image path | `sed -n '/^## Policy Map/,/^### Boundary notes/p' docs/reference/agent_workflow.md \| grep -nE '\]\([^)]*(development\|adr\|\.agents/)'` finds nothing | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| State the link rule once under the table rather than converting cells to links | the document ships, and the linking convention names a target the citing text cannot reach, so a link to a project-only root or another image root would not resolve where the document is read | this handover; the roadmap row's landing note |

## Decisions pending

None.

## Findings

None.

## Completed

| File | Change |
|---|---|
| [`docs/reference/agent_workflow.md`](../../docs/reference/agent_workflow.md) | the Policy Map gained the paragraph stating the `Document` cell's two forms and the roots each serves |
