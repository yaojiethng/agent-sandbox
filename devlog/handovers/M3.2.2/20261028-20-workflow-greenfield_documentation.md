---
date: 2026-10-28
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - greenfield documentation gets a page, and the map says where it happens

## Objective

Give the documentation convention the one case it did not cover, a document whose subject exists in the code and nowhere in the document set, and keep the statechart honest now that documentation is written again with no prompt of its own.

## Scope

The convention and the map that has to agree with it: a new reference under `project-documentation`, one pointer from its `## Drafting` section, the statechart's documentation-check gloss and its gaps list.

Out of scope, one sentence each with the reason: `reference-staleness` is unchanged, because it is the diagnosis case and this reference points at it rather than growing a second answer; the statechart gains no state, because a draft is not a command and the chart models commands.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The reference exists and is reached | `project-documentation` `## Drafting` links `references/greenfield.md`, and the link resolves | Agent [x] |
| It states the three scope checks before prose | step 1 carries Ownership, Truth and Vocabulary, and no prose follows them until all three are answered | Agent [x] |
| It hands the diagnosis case to the review that owns it | its closing paragraph runs the `reference-staleness` review instead | Agent [x] |
| The chart names no project-local file | `grep -c 'doc-maintenance' docs/reference/workflow_statechart.md` prints `0` | Agent [x] |
| The chart says where drafting happens | its `## Gaps` carries the greenfield gap, naming `it_implementing` | Agent [x] |
| Gates and suite | `bash scripts/lint.sh` clean across 15 gates, suite passes | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Greenfield documentation is a reference, not a prompt or a runbook | it is read while writing, in whatever context is already open; a prompt would be another name to remember, which is what `/document` was | the reference's opening |
| The scope check is ownership, truth and vocabulary | the analogues of the code-scoping step, and the difference is the subject: files and callers there, documents and words here | step 1 of the reference |
| The reference returns a draft and conflicts rather than landing them | the operator edits the draft; a draft nobody edited is not yet a document | step 5 of the reference |
| The statechart gains a gap, not a state | the chart models commands, and a draft is not one; a state with no command would be the same defect as a story no edge resolves | `workflow_statechart.md`, `## Gaps` |
| The `chk_docs` gloss stops naming `doc-maintenance` | the chart ships to the image and the pass is now project-local, so naming it there is a reach defect, the same one the linking gate caught for `/document` | `workflow_statechart.md` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Whether greenfield documentation ever becomes dispatchable | nothing today: it runs in the open context, and a seat would need a brief for a job the operator is already describing | keep it a reference, or add a runbook once a second caller needs it |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Deleting `/document` left the map with no place where documents are written | docs | the chart was accurate about commands and silent about a capability the tree still has, which is the class its `## Gaps` section exists to record | the new gap bullet |
| The chart named a skill that is now project-local | docs | a shipped document naming a file only this project holds is a reach defect, and the previous unit had already hit it through the linking gate | the gloss rewritten to "the documentation pass" |

## Completed

| File | Change |
|---|---|
| [`.agents/skills/project-documentation/references/greenfield.md`](../../.agents/skills/project-documentation/references/greenfield.md) | new: the three scope checks, placement, the confirmed skeleton, the hand-back, and the diagnosis handoff |
| [`.agents/skills/project-documentation/SKILL.md`](../../.agents/skills/project-documentation/SKILL.md) | `## Drafting` gains the pointer |
| [`docs/reference/workflow_statechart.md`](../../docs/reference/workflow_statechart.md) | the `chk_docs` gloss and its state row stop naming a project-local skill; `## Gaps` records where greenfield documentation happens |
