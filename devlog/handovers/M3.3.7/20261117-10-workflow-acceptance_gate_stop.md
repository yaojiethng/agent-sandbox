---
date: 2026-11-17
milestone: M3.3.7 - The principle corpus admission
type: Workflow
status: Closed
---

# Handover - The acceptance gate stops the loop and owns its own marking

## Objective

Give the acceptance gate the same stop the scope gate has, and give the marking of the acceptance table a home that runs before the gate rather than after it.

## Scope

One continuation line: this sidequest interrupts [`20261117-08-impl-produce_on_demand.md`](20261117-08-impl-produce_on_demand.md), which stays `Active` and resumes after this close.

The operator raised the regression, and the diagnosis is in [`devlog/AGENT_FEEDBACK.md`](../../AGENT_FEEDBACK.md), `[O] 2026-11-17`. Two changes explain it. `05a915df` deleted `/iter`'s `## The acceptance gate` section and the line "`/iter` stops at the acceptance gate", so the stop survives as a clause. `f6146d1a` moved the acceptance marking out of `/commit`, and the line landed nowhere.

Three edits and one record, on the operator's approval of the presented list. The precedence line against the autopilot directive is ruled out, and the gate's name stays as the files spell it.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `/iter` Step 7 ends with a bolded standalone stop, in the scope gate's form. | `grep -n "Stop here and present no commit"` prints one line, and it is Step 7's last before the Release gate heading. | Agent [x]. One line, at the boundary. |
| The close starts at the release, and `Status: Closed` is its first act. | `grep -n "^## The close"` prints one heading, `grep -c "^### B"` prints 7, and `grep -n "Set the handover"` places the flip at B1. | Agent [x]. Seven steps, none before the release. |
| The marking line is restored to the prompt whose gate reads it. | `grep -c "Mark each acceptance criterion accepted or pushed"` prints 1 and it is `iter.md` Step 7 section 1; `grep -c "AC verification and the status flip"` prints 0. | Agent [x]. |
| No prompt forward-references another. | `grep -rc "Part [ABC]"` over the prompts, the protocol and the skills prints 0, and `grep -n "wrapup" iter.md` shows only the directive rule, the release gate's handoff and Steps 8-9. | Agent [x]. |
| The feedback entry records the regression with the two commits that caused it. | `grep -c "\[O\] 2026-11-17" devlog/AGENT_FEEDBACK.md` prints 1. | Agent [x]. |
| `/iter` carries no prose about itself. | `grep -cE "does not restate"` prints 0, `grep -cE "rather than delegating"` prints 0, and no `## File Tracking` or `## Policy` heading remains. | Agent [x]. Nothing announces the document to itself. |
| Every rule survives the removal pass, with each difference named. | Modal counts against the branch point: must 7 to 7, unless 1 to 1, stop 5 to 5, only 8 to 8, never 0 to 1, and "do not" 6 to 3, where the three are the field-line rule rephrased as "never", the output rule rephrased as "produce no", and "do not restate it" cut whole. | Agent [x]. Each removed guard is accounted for. |
| Every decision this iteration records is realised in the files. | Read each `## Decisions` row against the tree. | Agent [x]. |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The stop is a bolded imperative at the boundary, in the scope gate's form. | A stop expressed as a clause loses to an operating mode that says not to park reversible work; the form is what carries the obligation. | This record; `/iter` Step 7. |
| Each caller owns its preparation, so a prompt is self-contained until it hands off. | The boundary is the handoff, not a step inside a shared runbook: `/iter` carries its marking and write-back, `/plan` hands over a work table, and `/wrapup` starts at the release. | This record; `/iter` Step 7 and `/wrapup`. |
| The acceptance marking, the Completed table and the out-of-scope folding are `/iter` Step 7's, and `Status: Closed` opens `/wrapup`. | The marking is preparation the gate reads and the closure is the release's result, and a prompt that delegates the first makes a forward reference to the second. | This record; `iter.md` step 7 section 1 and `wrapup` B1. |
| `/wrapup` keeps a roadmap write-back step, in two cases. | `/iter` writes its rows before its gate, and `/plan` hands over a work table for the close to file, so the step reads the first and files the second. | This record; `wrapup` B4. |
| `/iter` took a writing pass under `cut-metadiscourse`, `cut-what-serves-nothing` and `writing-for-agents`. | Its prose about itself, the close's step list and the duplicated gate presentation served no action, and the two sections that restated pointers had no reader. | This record; `iter.md`. |
| The record checks stay in `/iter` Step 7 and do not move to the close. | They already run before the gate, and moving them widens this change for no defect it fixes. Part B's own check names only what Part B writes. | This record; `/iter` Step 7 section 6. |
| The precedence line against the autopilot directive is skipped. | The operator's ruling. The bolded stop removes the ambiguity the collision needed, and the feedback entry is the evidence that would earn the line if it recurs. | This record; the feedback entry. |
| The corpus keeps `release gate` in its files and the operator's word `acceptance gate` in reports. | The operator ruled the rename out of scope, and one term per reader is a file-wide change the rename would have to carry. | This record; the finding above. |

## Decisions pending

None. The gate released the scope, the criteria and the four rulings this iteration proposed.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `wrapup.md` stated both moments for one body of work: its Part B preamble ran after the signal while B2, B3, B4 and B5 described work that had to precede it, and B9 assumed writes B4 said were already on disk. | contradiction | A step whose moment is ambiguous is a step no caller runs, which is how the marking went missing. | Resolved by the split. |
| The corpus calls the second gate the release gate, and the operator calls it the acceptance gate. The ADR uses both. | drift | Reports and prompts do not use the word the operator looks for, so a skipped gate is invisible in the conversation. | Ruled in this record's Decisions: the corpus keeps its two names, and reports use the operator's. |
| The operator raised the regression, not a check: no gate reads whether the acceptance table was marked before the commit. | gap | The same skip is undetectable by the tree until the operator notices. | The feedback entry's mitigation, which is shape rather than a new check. |
| The forward reference the first cut introduced reached five carriers, and removing it reached three more: `/plan`'s close sentence and the two `handover-maintenance` files that name a close step by number. | propagation | A prompt that delegates one step makes its caller read a document it is not yet running. | Resolved; the grep for a part label prints 0. |
| The removal pass cut "Only when scope is clear do you continue", which carried the condition that design waits for a settled scope, and the modal audit is what caught it. | propagation | A cut that takes a guard with it leaves the prompt permitting what it forbade, and nothing reports it. | Restored; the guard reads "continue into design only once the scope is clear". |
| The four earlier handovers in this milestone mark the table `[x] Accepted`, and the `work-log` convention defines `Agent [x]` and `Agent [ ]`. | drift | A marking the convention does not define reads as a verdict the workflow never produced. | This record; the earlier records are untouched, since a closed handover is corrected only for content. |

## Completed

| File | One-line change summary |
|---|---|---|
| `workflow/coding-agent/prompts/iter.md` | Step 7 carries the marking and the scope fold and ends with the bolded stop; the prompt took a writing pass and lost its prose about itself, the close's step list and two restated sections. |
| `workflow/coding-agent/prompts/wrapup.md` | The close starts at the release: the status flip, publication, decisions, the roadmap rows a caller hands over, the records, its own check and the report. |
| `workflow/coding-agent/prompts/sidequest.md` | Hands off to the close in one sentence. |
| `docs/reference/iteration_protocol.md` | The criteria invariant names `iter` Step 7 before the gate and the close's first step after it. |
| `devlog/AGENT_FEEDBACK.md` | The regression entry, with the two commits and the mitigation. |
| `devlog/roadmap.md` | The row stating the defect and its landing. |
| `workflow/coding-agent/prompts/plan.md` | Its close names what the runbook files rather than a write-back the caller owns. |
| `devlog/handovers/M3.3.7/20261117-10-workflow-acceptance_gate_stop.md` | This record. |
