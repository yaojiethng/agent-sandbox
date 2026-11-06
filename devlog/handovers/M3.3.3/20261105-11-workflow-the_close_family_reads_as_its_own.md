---
date: 2026-11-05
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - the close family and the entry prompts read as their own

## Objective

`commit.md`, `milestone-close.md`, `milestone-start.md` and `gm.md` are run. They carried the three classes the principle now names: a restatement of what a neighbouring runbook owns, the rationale tail of a rule, and a boundary stated twice. The pass removes those and keeps every guard, precondition, exit condition and citation, and the audit of the removed lines caught one rule it was right to keep.

## Scope

Seventeen edits across four prompts. The largest class was **a runbook enumerating what its neighbour owns**: `/commit`'s Scope listed eight close steps `/wrapup` owns, `/milestone-start` named the check-in skill's axes and then said it would not restate them, and `/milestone-close` closed with a rule its own "stop" already carries.

`gm.md` took one cut, and the pass found nothing else in it: sixteen lines that already point at the skill holding the check-in.

Ruled out of scope, and filed: the eight runbooks off the close family -- `bootstrap`, `backlog-triage`, `record-correction`, `sidequest`, `package-eval-snapshot`, `rebase`, `merge` and `read-back`.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `/commit` no longer enumerates the close's steps | `rg -n 'acceptance-criteria verification, propagation replay' workflow/coding-agent/prompts/commit.md` prints nothing, and both neighbour pointers remain | Agent [x] |
| `/milestone-start` cites the check-in's axes without narrating the citation | `rg -n 'rather than restating them here' workflow/coding-agent/prompts/milestone-start.md` prints nothing | Agent [x] |
| `/milestone-close` keeps its post-close boundary after the cut | `rg -n 'nothing substantive lands after it' workflow/coding-agent/prompts/milestone-close.md` prints one line | Agent [x] |
| No rule, guard, precondition or citation was lost | `git diff` for this unit removes explanation, rationale and restatement only: every imperative in the removed hunks appears in the file after the pass, and the one that did not was restored | Agent [x] |
| The off-family runbooks are filed | `rg -n 'remaining runbooks get the pass' devlog/roadmap.md` prints the open row | Agent [x] |
| Every decision this unit recorded is realized in the files | the `## Decisions` table read against the diff | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A neighbouring runbook's step list is cut to the pointer | the list has one home, and a copy drifts the moment that home changes | `/commit`, `/milestone-start` |
| The post-close boundary keeps a clause beyond "stop" | an audit of the removed lines flagged it as an imperative, and "stop" alone does not say that a later session may not land work | `/milestone-close` |
| `gm.md` takes one cut and no more | it is already a pointer at the skill that owns the check-in, and a pass that invents work in a clean file is its own failure | this handover |
| The off-family runbooks are filed, not worked | eight prompts are their own unit with their own verification | `devlog/roadmap.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The pass cut `/milestone-close`'s "No substantive work lands after the operator's close direction" as a restatement of "stop", and the removed-line audit flagged it: the stop ends this runbook, and the rule it carried forbids later work under the same close | defect, rule | a close that reports and then lands more work below the boundary, which is the case the rule exists for | this unit, restored as a clause |
| `gm.md` is clean; the pass found no line that serves another mode or adds nothing | result | none, and it is the control the other three are read against | this handover |
| Eight runbooks have not had the pass: `bootstrap`, `backlog-triage`, `record-correction`, `sidequest`, `package-eval-snapshot`, `rebase`, `merge`, `read-back` | drift | the class is unmeasured in 45 per cent of the prompt surface | the roadmap row |

## Completed

| File | Action |
|---|---|
| [`workflow/coding-agent/prompts/commit.md`](../../workflow/coding-agent/prompts/commit.md) | five edits: the close's step list, the git-discipline rationale, the `wip:` prefix explanation, the transient-commit list, and the repeated end-state rule |
| [`workflow/coding-agent/prompts/milestone-close.md`](../../workflow/coding-agent/prompts/milestone-close.md) | five edits: the duplicated ownership sentence, the changelog rationale, the repeated release rule, the typed-commit evidence, and the post-close boundary restored as a clause |
| [`workflow/coding-agent/prompts/milestone-start.md`](../../workflow/coding-agent/prompts/milestone-start.md) | six edits: the finish-state rationale, the citation narration, the numbering clause, the permission its bullets already give, and the design-step boundary stated once |
| [`workflow/coding-agent/prompts/gm.md`](../../workflow/coding-agent/prompts/gm.md) | one edit: the instruction to read the rule elsewhere, which the sentence before it already gives |
| [`devlog/roadmap.md`](../roadmap.md) | the off-family row filed |
