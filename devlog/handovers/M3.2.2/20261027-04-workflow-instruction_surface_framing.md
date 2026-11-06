---
date: 2026-10-27
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - The instruction-surface framing, written once

## Objective

Write the settled statement of the instruction-surface problem into one operator-owned file, so the next session reads the framing rather than reconstructing it from a compacted conversation.

## Scope

A sidequest raised at the close of `20261027-01`, on operator direction. It writes down a problem statement the operator settled across two corrections: the failure is not non-compliant instructions but a corpus that is expensive to be right by, through repairs that land as additions and through instructions a reader has to interpret before acting. Out of scope: the remedies, the measure and its threshold, and the instrument work those belong to, which the roadmap holds.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The framing is stated once, in the operator's vocabulary, with no plan inside it | the file's `## What this does not settle` names the plan, the measure and the threshold as elsewhere's | Agent [x] |
| It cannot be polluted silently | the file carries no amendments section, an ownership line, and a lifecycle that ends in deletion | Agent [x] |
| The operator's own wording survives, marked as excerpts with the normalization stated | `## The operator's words` holds three quotes with each elision marked | Agent [x] |
| It stays off the always-loaded surface and is reachable from the maintenance surface | neither `AGENTS.md` names it; `instruction-surface-conventions.md` `## Two surfaces` links it, and the link resolves | Agent [x] |
| No gate regresses | `bash scripts/lint.sh` and `bash scripts/check_instruction_surfaces.sh` are clean | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Not an ADR | the `decision-records` convention edits an ADR in place when its principle changes, which makes it a rewrite surface by design | this record |
| No hash pin over the body | the agent writes the file from the conversation and would re-pin it in the same edit, so a hash asserts nothing about authorship | this record |
| No amendments section | an append surface inside a file about additive drift is the defect the file describes | this record |
| Ownership is a stated line, enforced by the operator rejecting edits and deleting the file when the framing stops holding | the repository carries this shape already at `.agents/model-recommendations.md` | this record |

## Decisions pending

None.

## Findings

| # | Finding | Type | Impact | Triaged to |
|---|---|---|---|---|
| 1 | The repository has no folder for operator-owned text; `.agents/model-recommendations.md` is the only instance, and the `docs` convention's folder tree does not cover `.agents/` | gap | a second instance now sits beside it; the folder earns a convention entry when a third appears | the roadmap row for the instruction-surface instruments |
| 2 | A second handover dated today and indexed `03` sits untracked in `devlog/handovers/`, opened for the instruction-defect-classes row and never committed | record defect | its index now collides with this one; the operator decides whether it is adopted or deleted | this record |

## Completed

| File | Change |
|---|---|
| [`.agents/instruction-surface-framing.md`](../../.agents/instruction-surface-framing.md) | new: the regime, the two mechanisms, how the cost propagates, what follows for remedies, what it does not settle, and the operator's words as excerpts |
| [`instruction-surface-conventions.md`](../../docs/development/instruction-surface-conventions.md) | `## Two surfaces` links the framing as the problem statement both surfaces are reduced for |
