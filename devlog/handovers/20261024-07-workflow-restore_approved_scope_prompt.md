---
date: 2026-10-24
milestone: T1 - Workflow + Policy Organization
type: Workflow
status: Closed
---

# Handover - The approved `/scope` prompt is restored

## Objective

Put back the `/scope` prompt the operator released, with the two hand-off lines a review correctly rejected removed.

## Scope

The prompt, its staged copy, and this record. It corrects [`20261024-01-workflow-scope_prompt_rewrite.md`](20261024-01-workflow-scope_prompt_rewrite.md), which recorded the review-expanded form as the landed unit; that record is closed and is not rewritten.

Two items raised with this change are ruled out and handed elsewhere. The rule that a reviewer is dispatched read-only and never edits is a governance change to the provider layer, proposed to the operator separately. The provenance of the review brief's rule-preservation instruction was investigated and traced to a policy-retirement review, where the base rule set was invariant; the reused form dropped that bound. A tighter wording of the clause is proposed to the operator separately.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The prompt is the released four-question form | `wc -l workflow/coding-agent/prompts/scope.md` prints 77, the released draft plus its final newline | Agent [x] |
| No unshipped path and no draft command is named | `grep -n 'task-queue\|prompt-authoring-conventions' workflow/coding-agent/prompts/scope.md` prints nothing | Agent [x] |
| The hand-off names only runbooks that ship | `sed -n '/^## Hand off/,/^## Non-goals/p' workflow/coding-agent/prompts/scope.md` names `iter.md` and `plan.md` | Agent [x] |
| The staged copy is the tree's file | `diff -q workflow/coding-agent/prompts/scope.md /opt/workflow/agent/modules/coding-agent/prompts/scope.md` prints nothing | Agent [x] |
| The record passes its gate | `bash scripts/check_handover_format.sh devlog/handovers/20261024-07-workflow-restore_approved_scope_prompt.md` | Agent [x] |
| The gates stay clean | `bash scripts/lint.sh` across 12 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Restore the released draft instead of re-trimming the review's version | the operator released the 77-line draft and never read the 95-line one; the review's restorations were made against a source the operator had already deliberately cut | the prompt |
| Drop the hand-off's citation of `docs/development/prompt-authoring-conventions.md` | that tree is not delivered to the container, so the reader cannot open it | the prompt, `## Hand off` |
| Drop `task-queue` from the next-runbook suggestion | it exists only under `.agents/drafts/` and has no command row; the two shipped runbooks are `iter.md` and `plan.md`, both already named | the prompt, `## Hand off` |
| Keep the statechart row and its exit edge | they describe a brief released to a run, which is still true when the operator takes the suggestion; no carrier asserts the removed citation | [`workflow_statechart.md`](../../docs/reference/workflow_statechart.md) `## Commands` |
| Keep the tree's word "brief" | already decided in `20261024-01`; no carrier changed | the prompt |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The review-expanded prompt landed as `ac3dcd91` without the operator reading it, and the operator's recollection of the approved text was the earlier draft | defect | an agent's application of a review was treated as the operator's approval | fixed here |
| The review brief instructed "rule preservation bounds every cut; losing a rule is a defect, not an edit" against the pre-rewrite source, so every cut the operator directed read as rule loss unless it was listed in the brief | mechanism | the review restored rules the operator had cut, and the agent applied the restorations | traced: the sentence was written for a policy retirement where the base rule set was invariant; the reused form in `runbook/review.md` dropped that bound. A tighter wording is proposed to the operator |
| The main agent dispatched the review on its own initiative, with no operator gate between the report and the edit | mechanism | a review can rewrite a released artifact without the operator seeing the draft it produced | a governance proposal to the operator, made with this record |

## Completed

| File | Change |
|---|---|
| [`workflow/coding-agent/prompts/scope.md`](../../workflow/coding-agent/prompts/scope.md) | restored to the released four-question form; the hand-off names `iter.md` and `plan.md` only |
| `/opt/workflow/agent/modules/coding-agent/prompts/scope.md` | the staged copy, identical to the tree's file |
| [`devlog/handovers/20261024-07-workflow-restore_approved_scope_prompt.md`](20261024-07-workflow-restore_approved_scope_prompt.md) | this record |
