---
date: 2026-10-28
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - `/document` is deleted, not renamed

## Objective

Delete the documentation-session prompt, which nothing routed to and which carried two rules of its own, and close the maintenance cluster it was the last open item of.

## Scope

The prompt and its carriers: `workflow/coding-agent/prompts/document.md`, the prompt table, the loop ADR and its two reference documents, the authoring conventions, the statechart's document path, the lint ignore list, and the three roadmap rows that waited on it.

Out of scope, one sentence each with the reason: the drafting capability is not built here, because it is a feature and not a deletion; `doc-maintenance` stays where the previous unit put it, because that ruling was about the pass and this one is about the prompt.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The prompt is gone | `ls workflow/coding-agent/prompts/document.md` prints nothing | Agent [x] |
| No live carrier names the command | `grep -rn '/document' --include='*.md' . \| grep -v devlog` prints only prose false positives | Agent [x] |
| The statechart has no unreachable document path | `bash scripts/check_statechart.sh` is clean, and holds no `doc_drafting` or `doc_published` | Agent [x] |
| The loop ADR, the protocol scope and the autonomous-loop document agree | each lists `/iter` and `/plan` only | Agent [x] |
| The three waiting rows are closed | `grep -c 'Convergence round 3' devlog/roadmap.md` prints `0`, and no row names `/document` as an owner | Agent [x] |
| Gates and suite | `bash scripts/lint.sh` clean across 15 gates, `bash scripts/run_tests.sh` 1349 passing | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Delete rather than rename | a prompt is a name the operator must remember at the right moment, and `/document` was reached by nobody: no prompt, skill or statechart routed to it, and no handover records a session under it | the closed roadmap row |
| Its two rules are not moved anywhere | the type test, the authoring bar and the close all live in their own homes and the prompt only pointed at them; the criterion shapes are `iteration_protocol`'s invariants with worked examples | the closed roadmap row |
| The statechart loses the states, not just the command row | `doc_drafting` and `doc_published` are reachable only through `/document`, so keeping them would have left two states no story resolves | `workflow_statechart.md` |
| `chk_docs` now returns to `it_implementing` | its only exit was `doc_published`; `/iter`'s information-gathering pass is the remaining caller, and it resumes the unit | `workflow_statechart.md` |
| The statechart fence gains `<!-- snippet: illustrative -->` | the code-snippet gate holds a hash baseline, and editing a grandfathered fence made the block undeclared; the diagram's only truth is the document | `workflow_statechart.md`, `scripts/lint/code-snippets.baseline` |
| A test's fixed state count becomes a pattern | `test_statechart.sh` asserted "40 state(s)", a committed derived value that fails on every legitimate state change; it now asserts that a count is reported | `tests/test_statechart.sh` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Where the drafting case lands | the capability the prompt did not own: scope a slice, check ownership of meaning, draft text the operator edits | `project-documentation/references/drafting.md` as proposed, or a shipped skill beside the pass |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The prompt's unique content was two rules, and both had a stronger home | evidence | deleting it loses nothing the tree does not already hold | the closed roadmap row |
| `test_statechart.sh` pinned the state count at 40 | test | a committed derived value that fails on correct work; the third such assertion this milestone has hit | fixed to a pattern |
| Editing a grandfathered code fence invalidates its baseline entry | gate | the code-snippet gate reported PRUNABLE and UNDECLARED together, which is the gate working as designed | marked illustrative, baseline updated |
| The statechart had a whole publishing path with one entry point | docs | removing the prompt made two states unreachable; the chart was the only place that recorded the path | removed with the prompt |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/document.md` | deleted, 158 lines |
| [`AGENTS.md`](../../AGENTS.md) | the prompt table loses its row |
| [`docs/adr/coding_agent_loop_workflow.md`](../../docs/adr/coding_agent_loop_workflow.md) | the active-operator tuple loses `/document` |
| [`docs/reference/iteration_protocol.md`](../../docs/reference/iteration_protocol.md) | the scope list loses it |
| [`docs/reference/autonomous_agent_loop.md`](../../docs/reference/autonomous_agent_loop.md) | the sentence naming it |
| [`docs/development/prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) | two references: the "stub defers here" phrase and the handoff example |
| [`docs/reference/workflow_statechart.md`](../../docs/reference/workflow_statechart.md) | two states, four transitions, the command row and the story removed; `chk_docs` repointed; the fence marked illustrative |
| `scripts/lint/code-snippets.baseline` | the stale entry dropped by `--update` |
| [`tests/test_statechart.sh`](../../tests/test_statechart.sh) | the fixed count becomes a pattern |
| `.markdownlint-cli2.mjs` | the ignore entry for the deleted prompt |
| `workflow/coding-agent/prompts/commit.md` | the prompt list in its checkpoint rule |
| `workflow/coding-agent/prompts/wrapup.md` | its description and its close rule |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the maintenance cluster closed, the doc-maintenance review row closed, its three waiting rows deleted, and the milestone criterion restated |
