---
date: 2026-11-11
milestone: M3.3.5 - The eval pipeline
type: Documentation
status: Closed
---

# Handover - The grading standard is agreed, not prescribed

## Objective

Stop the eval procedure prescribing a grading method, and make the grading standard and the sample count things the agent and the operator align on for each eval.

## Scope

Two places in the eval skill currently prescribe what should be per-eval agreements: the protocol's grader item fixes the double grade and the single decisive pass, and `methods.md` fixes a repeat pass as the way to measure the judgement. The run steps restate the fixed method. Meanwhile the sample count and the A/A baseline, which are already in the protocol and in `methods.md`, read as steps to execute rather than as numbers agreed before the run.

The edit asks instead of prescribing. The protocol's grader item names what the grading standard settles -- how each output is judged, how independent the judgement is from the arm it scores, and how a disagreement between passes is settled -- and leaves the procedure to the operator's alignment for that eval. The decision-rule item gained the same framing while the section was open, since the rule is the operator's and the defect is the same one. The A/A calibration and the run count keep their content and gain the framing that n and the band are agreed before the run.

Out of scope: a carrier for the agreement in the run record (the automated grader is deferred at `devlog/roadmap_future.md`, and until then the standard is an agreement, not a measured field); a typed `decision.rule`, whose row is deleted here; and the harness mechanics, which do not change -- `assemble_grade` still hides the labels, so blindness stays an invariant the harness enforces rather than an option.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The protocol asks for the grading standard and enumerates no procedure. | item 6 read against the criterion; `grep -c "graded twice" .agents/skills/evals/SKILL.md` -> 0 | Agent [x] |
| The run step no longer restates the fixed method. | `grep -n "agreed standard" .agents/skills/evals/SKILL.md`; step 5 read | Agent [x] |
| `methods.md` stops prescribing the repeat pass and keeps blindness. | `grep -c "Grade the same reports twice" .agents/skills/evals/references/methods.md` -> 0; `grep -n "sanitized labels" ...` -> 1 | Agent [x] |
| n and the band read as agreed before the run. | the two sentences read in place; `grep -n "agreed"` shows them | Agent [x] |
| The decision rule reads as the operator's, not a format. | item 8 read; `grep -c "decision rule is typed" devlog/roadmap.md` -> 0 | Agent [x] |
| The deferred entry carries the condition. | `grep -n "gains a shape" devlog/roadmap_future.md` | Agent [x] |
| Every decision recorded is realized in the files. | Decisions table read against the diff | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The grading standard is an agreement per eval, not a prescribed method. | Grading is operator-directed until the automated grader lands, so a fixed double grade would have a designer measure noise the operator never asked for. | this table; `SKILL.md` item 6 |
| The protocol names what the standard settles and no options. | An enumerated menu is a prescription in another form; the arrangement is unique to the eval and the operator's alignment is where it is chosen. | this table; `SKILL.md` item 6 |
| Blindness stays a harness invariant. | `assemble_grade` shuffles the raw files and keeps the label outside the grade directory; that is a mechanism, not a judgement, so nothing about it is optional. | this table; `methods.md` |
| The typed-rule row is deleted, and its condition moves onto the deferred automated-grader entry. | The close is the operator's reading, so an interpreted rule is the design working. A rule gains a shape only when an automated reader evaluates it. | the roadmap diff; `roadmap_future.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The protocol's grader item and `methods.md` prescribe a double grade, and no consumer measures agreement. | record | A designer following the protocol measures a noise the operator never agreed to, and the number lands nowhere a reader checks. | fixed here: the item asks, the method states a choice |
| The run count and the A/A band are already declared, but read as steps rather than as agreed numbers. | record | A run whose n was chosen after seeing the data is uncontested by the text. | fixed here: the agreed-before-the-run framing |
| `SKILL.md`'s run step 5 restates the fixed grading method. | record | The prescription survives in the run phase after the protocol stops asserting it. | fixed here: step 5 defers to the agreed standard |
| The typed-rule row presumed a format for a per-eval agreement. | record | Filing it kept a prescription the operator does not want. | deleted; the condition is carried on `roadmap_future.md` |

## Completed

| File | One-line change summary |
|---|---|
| `.agents/skills/evals/SKILL.md` | Items 5, 6 and 8 ask rather than prescribe; run step 5 defers to the agreed standard. |
| `.agents/skills/evals/references/methods.md` | A/A calibration gains the agreed-count sentence; the grader section states blindness as the invariant and the reliability arrangement as the method's choice. |
| `devlog/roadmap.md` | The grading-standard row is closed with its landing note; the typed-rule row is deleted. |
| `devlog/roadmap_future.md` | The deferred grader entry carries the condition for a rule an automated reader evaluates. |
| `devlog/roadmap.md` | Roadmap maintenance check before the handover opened: M3.3.5 reads `In progress`, the closed rows carry their landing notes, and the two rows under this work were open as expected. |
