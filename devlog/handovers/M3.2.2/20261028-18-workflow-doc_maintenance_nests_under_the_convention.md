---
date: 2026-10-28
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - the documentation pass becomes the convention's own runbook

## Objective

Put the documentation check inside the convention it diagnoses against, so a question about a document and the check that answers it are one open instead of two, and record what that move gives up so a later session does not undo it.

## Scope

The pass and the file it now belongs to: `workflow/coding-agent/skills/doc-maintenance/`, its binding block, every carrier that named its old path, and `project-documentation`'s new `## Checking` section.

Out of scope, one sentence each with the reason: `reference-staleness` stays where it is, because it is a dispatched review runbook and its coupling is to the record vocabulary rather than to this convention; `prompts/document.md` is not deleted here, because that is the next unit and only its two links are touched.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The pass lives under the convention | `ls .agents/skills/project-documentation/runbooks/doc-maintenance/SKILL.md` prints the path | Agent [x] |
| No carrier names the old path | `grep -rn 'workflow/coding-agent/skills/doc-maintenance' --include='*.md' . \| grep -v devlog` prints nothing | Agent [x] |
| The convention reaches the runbook | `project-documentation` carries `## Checking` with a link that resolves | Agent [x] |
| The moved file no longer binds to the convention it sits inside | it carries no binding block at all: `## Purpose` already names the convention, and the unstated-convention rule moved into that sentence | Agent [x] |
| A shipped prompt does not link a project file | `document.md` names the path in a code span, and the linking gate is clean | Agent [x] |
| Gates and suite | `bash scripts/lint.sh` clean across 15 gates, suite passes | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The pass nests under `project-documentation` | operator ruling 2026-10-28: the coupling is real, and the coupling is to this project's commands, gates and artifact kinds rather than to a portable procedure | this handover |
| The move is recorded as one-way, with its cost named | leaving the shipped payload means the image no longer carries the pass and a second project would copy it by hand, receiving no updates; nothing in the tree needs a second project today | this handover, `## Decisions pending` |
| A shipped prompt names a project path in a code span, never as a link | the linking gate resolves a shipped prompt's links in the image's path space, and a project file is not in it; this is the same mechanism every `## Project conventions` block uses | `document.md` |
| The moved file's binding block is rewritten to point at `../SKILL.md` | a file that binds to the convention containing it is a self-reference; the useful statement is the failure when the convention is unstated | the runbook's `## Project conventions` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Whether the pass ever has to ship again | nothing today; it bites the day a second project adopts this workflow | copy it by hand per project, or lift it back into `workflow/coding-agent/skills/` and give it a binding for the gate command |
| Whether `reference-staleness` follows | it consumes this pass's report and names it by role rather than path, so nothing breaks; but the producer is now project-local and the consumer is not | leave it, or move it when a documentation module exists |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| A shipped prompt cannot link a project-local file: the linking gate resolves in the image's path space | structure | the first concrete cost of the ruling, caught by the gate before the commit rather than after | recorded as the decision above |
| The pass's coupling was 40 of 156 lines, none of it to `project-documentation` beyond a three-line binding | evidence | the move is justified by the coupling to this repo's artifact kinds and commands, not by the one row | this handover |
| `reference-staleness` is the more portable of the two: no path, no command, six fault classes | evidence | it answers the operator's question and stays put | the pending row |

## Completed

| File | Change |
|---|---|
| `.agents/skills/project-documentation/runbooks/doc-maintenance/SKILL.md` | moved from `workflow/coding-agent/skills/doc-maintenance/`; the binding block now names `../SKILL.md` |
| [`.agents/skills/project-documentation/SKILL.md`](../../.agents/skills/project-documentation/SKILL.md) | gains `## Checking`, linking the runbook |
| [`workflow/coding-agent/prompts/document.md`](../../workflow/coding-agent/prompts/document.md) | two links become a code-span path and a plain name |
| [`workflow/coding-agent/prompts/iter.md`](../../workflow/coding-agent/prompts/iter.md) | the path it names is the new one |
| [`AGENTS.md`](../../AGENTS.md) | same repoint |
| [`docs/reference/documentation_taxonomy.md`](../../docs/reference/documentation_taxonomy.md) | two path mentions repointed |
| [`docs/development/prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) | its link repointed |
