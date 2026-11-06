---
date: 2026-11-05
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - the sibling prompts get the same pass `/iter` got

## Objective

`/plan`, `/scope` and `/wrapup` are how-tos read by an agent about to run one step, and each carried the three classes `/iter`'s pass removed: explanation of the system it runs in, the rationale tail of a rule, and a statement the document already makes. The pass leaves every guard, precondition, exit condition and citation, and the three prompts read as their sequences.

## Scope

The row **The sibling prompts get the same pass `/iter` got**, and the three prompts it names. Fifteen edits: four in `plan.md`, five in `scope.md`, six in `wrapup.md`.

Two cuts are worth naming because each was the document contradicting itself rather than merely padding:

- `wrapup.md`'s **Mandate** restated the commit rules that `/commit` owns -- the duplication the prompt's own failure modes call the defect this split removes -- so it now states the unit's shape and points at `/commit`.
- `scope.md`'s **Hand off** said the brief "can go two ways" over three bullets. It reads "one of three ways".

Also cut: `scope.md`'s `## When to use` repeated the frontmatter's own trigger sentence; `plan.md` explained why the grain is inferred rather than passed; `wrapup.md`'s `**What stays here.**` listed every close step the sections above already list.

Ruled out of scope: `commit.md`, `milestone-close.md`, `milestone-start.md` and `gm.md`, which the row does not name.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `plan.md` states the grain without justifying the interface | `rg -n 'wrong interface' workflow/coding-agent/prompts/plan.md` prints nothing, and "The grain is inferred and stated" remains | Agent [x] |
| `scope.md` carries no second trigger sentence and no count that contradicts its list | `rg -n '^Use when the operator hands over' workflow/coding-agent/prompts/scope.md` prints nothing, and `rg -n 'one of three ways'` prints one line | Agent [x] |
| `wrapup.md` no longer restates the commit rules | `rg -n 'sole reviewable surface' workflow/coding-agent/prompts/wrapup.md` prints nothing, and the `/commit` pointer remains | Agent [x] |
| No rule, guard, precondition or citation was lost | `git diff` for this unit removes explanation, rationale and restatement only: every imperative in the removed hunks appears in the file after the pass | Agent [x] |
| The roadmap row is rewritten to what landed | the row reads `- [x]` and names this handover | Agent [x] |
| Every decision this unit recorded is realized in the files | the `## Decisions` table read against the diff | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `wrapup.md`'s Mandate keeps the unit's shape and points at `/commit` for the rules | the commit rules have one home, and a second statement is what the prompt's own failure modes forbid | the prompt |
| `scope.md`'s `## When to use` keeps only the two routes | its first line repeated the frontmatter sentence an invoker has already read | the prompt |
| `wrapup.md`'s `**What stays here.**` keeps the evidence clause alone | the step list above is the list; the bullet's value is that `/commit` stages what these steps produced | the prompt |
| The prompts the row does not name are left alone | `commit.md` and `milestone-close.md` are close-family runbooks with their own readers, and a pass over them is its own row | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `scope.md` said the brief "can go two ways" over three bullets, so its own count disagreed with its list | defect, text | a reader plans for two outcomes and meets a third at the point of choice | this unit |
| `wrapup.md`'s Mandate restated the commit rules `/commit` owns, while the same file's failure modes name that restatement as the defect the split removes | defect, rule | the runbook instructed the duplication it forbids, so a later reader keeps the copy and drops the pointer | this unit |
| `commit.md`, `milestone-close.md`, `milestone-start.md` and `gm.md` have not had the pass | drift | the same class is unmeasured in four runbooks, and only `/iter`'s and these three are known clean | not filed; the row named three prompts, and a row over the rest needs the operator's word |

## Completed

| File | Action |
|---|---|
| [`workflow/coding-agent/prompts/plan.md`](../../workflow/coding-agent/prompts/plan.md) | four edits: the interface justification, the durable-record rationale, the skill explanation, and the completion criterion merged with its stop |
| [`workflow/coding-agent/prompts/scope.md`](../../workflow/coding-agent/prompts/scope.md) | five edits: the duplicated trigger, the rationale tail, a restatement, the count corrected to three, and the vague cost clause |
| [`workflow/coding-agent/prompts/wrapup.md`](../../workflow/coding-agent/prompts/wrapup.md) | six edits: the Mandate's restated commit rules, the redundant protocol pointer, the task-list rationale, the B7 rationale, the B9 rationale, and the step list in `What stays here` |
| [`devlog/roadmap.md`](../roadmap.md) | the row closes, naming what landed |
