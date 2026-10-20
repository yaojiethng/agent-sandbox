---
date: 2026-10-14
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - move the iteration file list to the scope gate

## Objective

Make the scope proposal the sole owner of the iteration's file list, and move a misplaced design check: the part that asks whether a file is in scope goes to the scope gate, and the part that asks whether a recorded decision is realized in the files becomes an acceptance criterion.

## Scope

The follow-up to `Retire handover_policy` (handover `20261014-09`): the record's `## Hot files` section leaves the record, and the scope proposal owns the file list.

Three carriers hold the section today - the template, the `work-log` convention's role table, and the format gate's required-section list - and four procedures reference it.

The design-to-source integrity check is in scope, because removing the section removes its anchor. It sits in `handover-maintenance` Track A, whose own table says "run at the scope gate, before implementation". `handover-maintenance` runs only from `check-in`'s chain audit and `wrapup` B8's correction-form report, so the check sits in an auditor and no prompt dispatches it.

Out of scope: whether the `Completed` table and the delivery commit's changed-path set must agree; it becomes its own roadmap row.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The scope proposal owns the file list: `iter` requires the file table at the scope gate, and the record carries no file list | read `iter`; grep the record | Operator [x] |
| `## Hot files` leaves the record: gone from the template, the role table and `REQUIRED_SECTIONS`, and not added to the forbidden list | grep each; run the format gate over the closed records | Operator [x] |
| A file the design names must appear in the scope proposal's table, or the scope is amended | read `iter` | Operator [x] |
| A recorded decision realized in the files is an acceptance criterion, not a separate step: `iter` Step 5 states the trigger, and `wrapup` B1 verifies the row with the others | read both | Operator [x] |
| The design check leaves `handover-maintenance`: its step is gone, the remaining steps are renumbered, and the dangling-reference step reads the completed section alone | read | Operator [x] |
| The remaining references repoint: `wrapup` B9, the two File Tracking sections, the retiring audit skill, and the gate's fixture | grep | Operator [x] |
| One acceptance-criteria table shape, stated by the `work-log` convention and used by both `/iter` presentations and by `/document` | grep for the retired shapes | Operator [x] |
| `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are clean | run both | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The scope proposal owns the iteration's file list; the record carries none | the list is scoping information, and the gate is where it is decided | this handover |
| A file the design names is checked at the scope gate | the gate holds the table, so the check is a comparison the gate can make | this handover |
| A recorded decision realized in the files is an acceptance criterion, with the trigger "the `## Decisions` table is not empty, or the iteration created an ADR entry" | it is a criterion, and the countable trigger stops it being optional | this handover; `iter` Step 5 |
| The design check leaves the auditor | it named the scope gate as its run point, and no prompt dispatched it | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The design-to-source integrity check stated "run at the scope gate, before implementation", and no prompt dispatched `handover-maintenance`: it runs only from `check-in` and `wrapup` B8. The check never ran in an iteration. Removed by this iteration. | contradiction | current iteration |
| Track A's other two checks name the scope gate and the pre-close in the same table, and nothing dispatches them either. | contradiction | next iteration; Triaged to: new roadmap row **The two remaining handover content checks have no dispatcher** |
| This handover opened with `status: Open`. `iter:69` requires `Active` at creation, and the template's default is `Open`, so a copy leaves it wrong. Corrected to `Active` by the sidequest. Same defect as handover `20261014-09`'s close step. | contradiction | next iteration; Triaged to: new roadmap row **The handover opens as `Active`** |
| Sidequest `20261014-11` interrupts this iteration: the operator asked where the model-selection quirk is recorded. | steering | current iteration |

## Completed

| File | Change |
|---|---|
| `.agents/skills/work-log/assets/handover.md` | `## Hot files` removed; the scope guidance names the scope proposal as the file list's owner |
| `.agents/skills/work-log/SKILL.md` | the role table loses the hot-files row; states the acceptance-criteria table's three columns |
| `scripts/lint/handover-format.mjs` | `REQUIRED_SECTIONS` drops the section; it is not forbidden |
| `workflow/coding-agent/prompts/iter.md` | carries the file table, the trigger for the criterion that every recorded decision is realized in the files, and one acceptance-criteria table shape |
| `workflow/coding-agent/prompts/document.md` | its two acceptance-criteria presentations become the one shape |
| `workflow/coding-agent/skills/handover-maintenance/SKILL.md` | the design check removed; steps renumbered; dangling references read the completed section alone |
| `workflow/coding-agent/prompts/wrapup.md` | B9 drops the hot-files update |
| `docs/policies/iteration_policy.md` | the File Tracking sentence repointed |
| `workflow/coding-agent/audits/architecture-doc-reviewer.skill.md` | the handover bullet reads the completed section for a closed iteration, and the scope table mid-iteration |
| `tests/test_handover_format_gate.sh` | the conforming fixture drops the section |
| `devlog/roadmap.md` | the write-back: two rows raised, one closed |
