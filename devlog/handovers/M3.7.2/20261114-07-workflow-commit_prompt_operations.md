---
date: 2026-11-14
milestone: M3.7.2 - The change model and its refinements
type: Workflow
status: Closed
---

# Handover - The commit prompt is three operations

## Objective

Leave `/commit` owning the three operations it performs and nothing else, so the admission rules live in the protocol and the close in `/wrapup`.

## Scope

Continues the parent row *The convention leads from history as a commons and owns the primitives* in M3.7.2, from [`20261114-06`](20261114-06-workflow-fold_slice_stack.md).

One row: *The commit prompt is three operations*. Reading the two prompts against the protocol: `/commit`'s Mandate states four rules, all of them the protocol's invariants; its Part A carries the boundary decision and the operator confirmation, which are the scope gate's; its failure modes are the same rules again; and `/wrapup`'s handoff paragraph hands *"marking each AC accepted or pushed and setting `Status: Closed`"* back to `/commit`, so the close's own steps are split across two prompts.

The work: reduce `/commit` to the three operations, the checkpoint and the self-check; give `/wrapup` B1 the AC marking and the status flip it already verifies; leave the protocol's invariants where they are.

Out of scope: `/wrapup`'s close steps other than B1 and the handoff paragraph. The milestone-close prompt is untouched.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `/commit` states the three operations: commit, amend, squash. | read `## The three operations` | Agent [x] |
| A targeted correction folds by autosquash: `git commit --fixup=<sha>` and `git rebase --autosquash`. | `grep -c 'autosquash' workflow/coding-agent/prompts/commit.md` returns 3 | Agent [x] |
| `/commit` carries no admission rule of its own: no open-handover rule, no one-commit-per-iteration rule, no AC marking, no status flip, no write-back step. | `grep -Ec 'open handover\|one delivery commit per iteration\|Status: Closed\|write-back'` returns 0 | Agent [x] |
| `/wrapup` B1 marks each AC accepted or pushed and sets `Status: Closed`. | read B1 | Agent [x] |
| `/wrapup`'s handoff paragraph no longer assigns AC marking or the status flip to `/commit`. | `grep -c 'marking each AC' workflow/coding-agent/prompts/wrapup.md` returns 1, in B1 | Agent [x] |
| The protocol still states both invariants; nothing was moved there. | `grep -ci 'one iteration, one delivery commit' docs/reference/iteration_protocol.md` returns 1 | Agent [x] |
| The instruction gates pass. | `bash scripts/lint.sh` | Agent [x] |
| The roadmap row closes with its outcome. | `git diff HEAD -- devlog/roadmap.md` at pre-close | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `/commit` becomes three operations, a checkpoint and a self-check. | Those are what it does; everything else it stated was someone else's rule or the close's step. | the prompt |
| The autosquash method replaces prose about folding a correction. | `--fixup=<sha>` encodes the target and `--autosquash` collapses it, so the fold is an argument rather than a judgement. | the prompt |
| The AC marking and the status flip move to `/wrapup` B1. | The close already reads and verifies the ACs; marking them in the commit step split one act across two prompts. | the prompt |
| The failure-mode and stop-and-ask sections are deleted rather than moved. | Each entry restates an invariant the protocol or the scope gate already holds; a prompt that lists them is a second source. | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `/wrapup`'s handoff paragraph assigns the AC marking and the status flip to `/commit`, while B1 verifies the ACs. | record | one act split across two prompts | this iteration |
| `/commit`'s Part A decides the iteration boundary and asks the operator, which the scope gate already released. | record | the prompt re-opens a closed gate | this iteration |

## Completed

| File | One-line change summary |
|---|---|
| (maintenance) | `roadmap-maintenance`: 0 findings; the fold row compacted last iteration, and no closed row carries open work. |
