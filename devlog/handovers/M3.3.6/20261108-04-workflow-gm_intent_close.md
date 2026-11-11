---
date: 2026-11-08
milestone: M3.3.6 - The instruction corpus and its map
type: Workflow
status: Closed
---

# Handover - The check-in close matches the intent form

## Objective

Make the check-in prompt's close rule consistent: an intent run recommends one task, and only a no-intent run presents the three intents.

## Scope

Two sentences in `workflow/coding-agent/prompts/gm.md`, `## Close` and `## Output rules`. The measure and the eval case are unchanged; the eval is halted.

Out of scope: the measure's intent-aware rule, the case's assertions, and any section deletion.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| An intent run recommends one task from the open rows | `## Close` states it, and forbids also presenting the three intents | Agent [x] |
| A no-intent run keeps the three suggestions | `## Output rules` is qualified with `When no intent was provided` | Agent [x] |
| The prompt still lints | `bash scripts/lint.sh` 25 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The intent form is one recommendation, not three | the replicate's reports listed both, so a strict content grade saw three equal choices | this record |
| The recommendation is from the open rows | one baseline run recommended closing a complete row; the open-row constraint excludes that | this record |
| The measure is not changed in this unit | the eval is halted; the measure follows in a separate unit if the case continues | this record |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Does the measure accept the intent form? | a clean rerun of the case | add an intent-aware direction rule, or drop the intent from the case |
| Does the deepseek arm continue? | a two-model result | retry after the free quota resets, and fix the harness session path |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The pristine replicate did not reproduce the pilot's cost win | measurement | baseline 82.5 s / 1.286 M tokens; `no-scope` 88 s / 1.678 M; `no-non-goals` 88 s / 1.879 M | no section deletion |
| The full prompt recommended a closed row in one baseline run | prompt contract | the close did not say the task must be open | this edit |
| The reports followed both the one-task close and the three-suggestion output rule | prompt contract | a strict grader saw three choices | this edit |
| The OpenCode free quota stopped the deepseek ablations after two baselines | external quota | the deepseek arm is incomplete | this record |

## Completed

| File | One-line change summary |
|---|---|
| `workflow/coding-agent/prompts/gm.md` | the close is one task from the open rows for an intent run; the three suggestions are no-intent only |
| `devlog/handovers/M3.3.6/20261108-04-workflow-gm_intent_close.md` | this record |
