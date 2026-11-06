---
date: 2026-11-05
milestone: M3.3.3 - The skill maintenance pipeline
type: Implementation
status: Closed
---

# Handover - a closed row names no record, and an ended record no row names is a failure

## Objective

Two rules the discussion-record determination implies are enforced instead of stated. A closed roadmap row carries no discussion link, because the row is what owns the record and a closed row owns nothing. A record whose state is `concluded` or `rejected` while no open row names it is a deletion that has not run. One gate holds both, reading the record's state from its name and its tenancy from `devlog/roadmap.md`.

## Scope

The M3.3.3 row **A closed row strips its discussion links**, widened by the operator to the record side: the closed record that is marked for deletion is an error in its own right, not only a link the row keeps.

The row was filed by the previous iteration as a contradiction: `/milestone-close`'s compaction step kept the design-document links and the `roadmap-maintenance` 2.3 survival table checked that the link survived, while the record a link names is deleted when its row closes. Both carriers now state the opposite, and the pair is one rule with one gate.

The gate reads two files, so it needs no map of which row produced which record, and no row identity beyond the checkbox: `- [ ]` is open, `- [x]` is closed, at any indent. The state is the third field of the record's name, which the name gate already holds to the vocabulary.

Ruled out of scope, on the operator's route: bringing the corpus to conformance in this unit. The gates exempt a file dated before the cutover, so the tree is green now, and the cleanup is filed under T5 - Archival as **The record cutover corpus is cleaned**, whose end state is the deletion of the cutover constant itself.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A closed row naming a record fails the gate | `bash tests/test_record_lifecycle_gate.sh` reports the closed-row case passing, and the finding names the repair | Agent [x] |
| A concluded or rejected record no open row names fails the gate | the same suite reports the two state cases passing | Agent [x] |
| A record that has not concluded is not a deletion | the same suite reports the orphaned `open` record passing | Agent [x] |
| The cutover exempts an older file, and one constant holds it | the same suite reports both cutover cases passing, and `rg -n 'RECORD_CUTOVER' scripts/lint/record-cutover.mjs` prints the single literal | Agent [x] |
| The gate runs in the umbrella | `rg -c 'check_record_lifecycle.sh' scripts/lint.sh` prints 2, a gate row and the header comment, and `bash scripts/lint.sh` reports 21 gates | Agent [x] |
| `milestone-close` drops the link and names the re-point | `rg -n 'drop the design document link' workflow/coding-agent/prompts/milestone-close.md` prints the step | Agent [x] |
| The survival table marks the link removed | the 2.3 row reads `Removed`, and its expected column names the re-point | Agent [x] |
| `work-log` names the two checks and states no rule of its own | `rg -n 'check_record_lifecycle.sh' .agents/skills/work-log/SKILL.md` prints the paragraph, and it carries no date and no rule the gates state | Agent [x] |
| The statechart's checks paragraph names the gate | `rg -n 'check_record_lifecycle.sh' docs/reference/workflow_statechart.md` prints the deletion guard | Agent [x] |
| The cleanup is filed under T5 with a checkable end state | `rg -n 'cutover corpus is cleaned' devlog/roadmap.md` prints the row under `#### T5 - Archival`, and its end state is the constant's deletion | Agent [x] |
| Every decision this unit recorded is realized in the files | the `## Decisions` table read against the tree | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| One gate holds both rules | Both read the same two inputs -- the record's state and the rows that name it -- and both answer whether the record is where the rule says; two gates would each parse the roadmap and each need the cutover | this handover, and `work-log` |
| The gate is cutover-exempt, as the name gate is | the operator's route: the corpus predates the rules, so a green tree must mean the rules hold for work started under them rather than that a backlog was declared conformant | `scripts/lint/record-cutover.mjs`, and the T5 row |
| The cutover is one constant in its own module | the name gate held its default twice before this unit, in the wrapper and in the scanner, and two defaults drift silently; a second gate makes the third copy certain | `scripts/lint/record-cutover.mjs` |
| The cleanup is filed under T5 rather than under the milestone that filed the rule | its subject is a corpus of stale records, which is what T5 - Archival holds, and its end state is the removal of a cutover that exists only while the corpus is stale | the T5 row |
| The record's state is read from its name, not its `**Status:**` line | the name gate already holds the name to the vocabulary, so the name is checked once and the two gates cannot disagree about a record's state | `scripts/lint/record-lifecycle.mjs` |
| The gates report rather than delete | a gate that removes files would need the record's content to be absorbed first, which is a judgement about durability, not a check | the T5 row, which does the removal |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `20261023-report-retirement_rule_loss_audit.md` carries `retirement` where the state field goes, so no gate can read its state and the name gate never flagged it: the file predates the cutover | defect, record | a record whose state is unreadable is invisible to every rule that reads state, and the corpus row would leave it behind | the T5 row |
| The corpus holds records the rule has already retired: most of the folder is named by no open row, and a handful of closed rows still carry their link | drift | two documents assert a record's life and the tree contradicts both, so the next session reads a corpus that says the opposite of the convention | the T5 row |
| `roadmap-maintenance` 2.3 asked for a design link in a closed row while the record behind it is deleted when its row closes, so the two rules cancelled | defect, rule | the close would preserve a link to a file the record rule removes, and a reader would take the surviving link as evidence the record lives | this unit |
| The name gate's cutover was written in two places, its wrapper and its scanner, and the wrapper silently overrode the scanner | defect, config | changing the scanner's default changed nothing, and the reports would disagree once one was edited | this unit |

## Completed

| File | Action |
|---|---|
| [`scripts/check_record_lifecycle.sh`](../../scripts/check_record_lifecycle.sh) | new gate: the entrypoint, its scope, and the two seam variables |
| [`scripts/lint/record-lifecycle.mjs`](../../scripts/lint/record-lifecycle.mjs) | new scanner: state from the name, tenancy from the roadmap, both rules, the cutover exemption |
| [`scripts/lint/record-cutover.mjs`](../../scripts/lint/record-cutover.mjs) | new module holding the cutover once, with the deletion of the constant named as the cleanup's end state |
| [`scripts/lint/record-name.mjs`](../../scripts/lint/record-name.mjs) | the name gate imports the shared cutover instead of holding its own default |
| [`scripts/lint.sh`](../../scripts/lint.sh) | the gate joins the umbrella, and the header comment names it |
| [`tests/test_record_lifecycle_gate.sh`](../../tests/test_record_lifecycle_gate.sh) | nine cases: owned and orphaned at three states, a closed row's link, a second record in a closed row, the cutover from both sides, and a missing roadmap |
| [`workflow/coding-agent/prompts/milestone-close.md`](../../workflow/coding-agent/prompts/milestone-close.md) | step 1 drops the design link and names the re-point that must precede the close |
| [`workflow/coding-agent/skills/roadmap-maintenance/SKILL.md`](../../workflow/coding-agent/skills/roadmap-maintenance/SKILL.md) | 2.3 marks the link removed, and names the second finding a link over a missing record raises |
| [`.agents/skills/work-log/SKILL.md`](../../.agents/skills/work-log/SKILL.md) | the exploration record names both gates and leaves each to state its own rule |
| [`docs/reference/workflow_statechart.md`](../../docs/reference/workflow_statechart.md) | the discussion record's checks paragraph names the deletion guard |
| [`devlog/roadmap.md`](../roadmap.md) | the row is rewritten and closed; the corpus row moves to T5 as the cutover cleanup |
