---
date: 2026-10-03
milestone: T1 - Workflow + Policy Organization
type: Workflow
status: Closed
---

# Handover - The handover window and the five records it reaches

## Objective

Set the handover format window at 2026-10-01 and bring the five records inside it onto the current format, so the gate reports on every handover the tree has written since the format landed.

## Scope

The gate's cutover was `20261003`, which exempted every record written before the format landed. Measured: only twelve handovers in the tree carry a YAML `date:` at all, the twelve from `20261002-20` onward, so the window reaches the dated records and nothing older. Moving it to `20261001` puts all twelve inside, and the gate then reports five findings across five files.

| In | Out |
|---|---|
| The cutover in `scripts/lint/handover-format.mjs` and `scripts/check_handover_format.sh`, moved to `20261001` | A scanner fallback for the old bold-header form; `20261002-19` is unified instead |
| `handover_policy.md` `## Format` states the window and what it exempts | Records dated before `20261001`, which no machine check reaches |
| `20261002-19` unified onto the current format | The three `## Changes` table headers that differ from the policy wording |
| `20261002-20`, `20261002-21`, `20261002-22` `type` values set to enum members | Every other finding from the survey, which are closed-record defects outside the window |

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The window is 2026-10-01 in the gate | `grep -n 'CUTOVER' scripts/check_handover_format.sh` names `20261001` | Agent [x] |
| The tree passes at the new cutover | `bash scripts/check_handover_format.sh` reports 0 findings | Agent [x] |
| The window is stated in policy | `handover_policy.md` `## Format` names the date and the exemption | Agent [x] |
| Each amended record carries its amendment block | `grep -n 'AMENDMENT -- 2026-10-03'` over the five files; five hits | Agent [x] |
| The gate's own tests still hold | `bash tests/test_handover_format_gate.sh` reports all cases passing | Agent [x] |
| The records pass the gates | `bash scripts/lint.sh` reports clean across 6 gates | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/lint/handover-format.mjs`](../../scripts/lint/handover-format.mjs) | the default cutover moves |
| [`scripts/check_handover_format.sh`](../../scripts/check_handover_format.sh) | the shell default moves with it |
| [`docs/operations/handover_policy.md`](../../docs/operations/handover_policy.md) | the window and its exemption are stated |
| [`devlog/handovers/archive/20261002-19-workflow-prompt_draft_gate.md`](../../devlog/handovers/archive/20261002-19-workflow-prompt_draft_gate.md) | unified onto the current format |
| [`devlog/handovers/archive/20261002-20-workflow-roadmap_record_link_and_wrap_gates.md`](../../devlog/handovers/archive/20261002-20-workflow-roadmap_record_link_and_wrap_gates.md) | `type` set to an enum member |
| [`devlog/handovers/archive/20261002-21-workflow-maintenance_skill_completion_and_record_corrections.md`](../../devlog/handovers/archive/20261002-21-workflow-maintenance_skill_completion_and_record_corrections.md) | `type` set to an enum member |
| [`devlog/handovers/archive/20261002-22-workflow-markdown_gate_unresolved_rule_warning.md`](../../devlog/handovers/archive/20261002-22-workflow-markdown_gate_unresolved_rule_warning.md) | `type` set to an enum member |
| [`devlog/handovers/archive/20261002-25-workflow-loop_state_model_and_close_seam.md`](../../devlog/handovers/archive/20261002-25-workflow-loop_state_model_and_close_seam.md) | the forbidden section removed, `## Completed` added |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Set the window at `20261001` rather than `20261003` | the operator's cutoff; it is the earliest date a record in the tree carries YAML for, so it reaches everything the gate can read | this handover |
| Unify `20261002-19` rather than teach the scanner the old date form | a fallback keeps a second date path alive for no record, once the one record in the window is conforming | this handover |
| Amend the four other records rather than exempt them | each is dated inside the window, and the operator's rule amends a record when the window reaches it | `handover_policy.md` |
| The 2026-10-03 survey's remaining findings are not tasks | a finding on a record outside the window is not a defect and carries no work; the operator's rule drops them, and no open roadmap row names any of them, so there is nothing to close | this handover |
| Drop the survey's record-tidying findings without a roadmap row | writing a row to close work that the operator has ruled out of scope creates a record of work nobody will do | this handover |
| Put the single-edit rule in `roadmap_policy.md` rather than in an open roadmap row | a standing bucket never closes, and it drifts; the rule is about how work is filed, which is where the filing rules live. The four rows it replaced become one closed row | `roadmap_policy.md` `### Filing rules` |
| Drop the superseded decision to leave `20261002-25`'s `## Deferred` section as history | that decision named a cutover of `20261003`; this window supersedes it | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| Only twelve handovers in the tree carry a YAML `date:`, all from `20261002-20` onward. The window cannot reach a record with no frontmatter: the scanner reads the block, finds none, and skips the file. So the cutover governs twelve records and the four hundred older ones are unreachable by any window. | gap | the window is stated with that reach, so a reader does not infer coverage the gate does not have |
| `20261002-25`'s `## Deferred` section carried `None.` and the `20261003-02` decision left it as history on the strength of a `20261003` cutover. This window supersedes that decision. | superseded | the section is removed and the amendment names the supersession |
| The 2026-10-03 `gm` survey reported 3 cosmetic and 40 surface findings across the roadmap and the handover chain. The 4 cosmetic ones were applied in `2f2e833`. Of the surface ones, this iteration and its two siblings closed the completion-context, the write-back pairing and the in-window format findings; the rest are outside the window, or are record tidying with no check behind it: the 26 M3.2.3 rows filed under `Not in scope`, the summary-table rows, the positional row references, the closed-row narrative sweep, the invalid `Status` values on nine handovers, and the four records citing superseded material. None of them names an open roadmap row. | disposition | dropped by the window rule and by the operator's direction; nothing was written to the roadmap to close |
| `20261001-02` is dated inside the window and carries no frontmatter, so it is the one record in the window the gate cannot reach. It was also the last handover no roadmap row named; the row naming it lands here. | gap | paired; the format half stays unreachable until the record is next amended, which the policy states |

## Completed

| File | Change |
|---|---|
| `scripts/lint/handover-format.mjs` | the default cutover moved to `20261001` |
| `scripts/check_handover_format.sh` | the shell default moved to `20261001` |
| `docs/operations/handover_policy.md` | `## Format` states the window, its reach, and the exemption below it |
| `docs/operations/roadmap_policy.md` | `### Filing rules` gains the single-edit record-defect rule |
| `devlog/handovers/archive/20261002-19-workflow-prompt_draft_gate.md` | YAML frontmatter, `## Scope`, `## Hot files`, `## Decisions pending`, and `## Changes` renamed `## Completed` |
| `devlog/handovers/archive/20261002-20-...`, `20261002-21-...`, `20261002-22-...` | `type` set to `Implementation`, `Documentation` and `Implementation` |
| `devlog/handovers/archive/20261002-25-...` | `## Deferred` removed, `## Hot files` and `## Completed` split |
| `devlog/roadmap.md` | the handover format window row, and a closed row for the one-off housekeeping edits, which absorbs the four pairing and completion rows and the closed unpaired-handover row |
