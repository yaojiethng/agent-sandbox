---
date: 2026-11-17
milestone: M3.3.7 - The principle corpus admission
type: Workflow
status: Closed
---

# Handover - Drop the minimal-corrections principle

## Objective

Drop `principle-minimal-corrections` and the `[CORRECTION]` tag rule for claim records, recording the drop in the corrections ADR, so the corpus stops carrying a rule whose content is already spread across the fold, the check placement and the record conventions.

## Scope

Roadmap row "`minimal-corrections` is deleted or folded into the approval card". In scope: the card's deletion, the tag rule's removal from the `record-correction` procedure and its reports, the provider `AGENTS.md` sentence, the `principle-check-placement` link, the corrections ADR entry, the taxonomy and changelog pointers, the roadmap row and the milestone acceptance line, and the corpus gate's count.

Out of scope, one sentence each: the 20 field values, the load-level terms, the just-in-time umbrella and the link normalisation are separate M3.3.7 rows; the `[AMENDMENT]` form stays, because it marks a non-content change and the operator named only the `[CORRECTION]` tag.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The card directory and its tracked path are gone, and the corpus gate is clean at 25. | `test ! -e .../principle-minimal-corrections`; `git ls-files` lists no `principle-minimal-corrections`; `bash scripts/check_principle_frontmatter.sh` reports 25/0. | Agent [x] |
| No live instruction surface applies or promises a `[CORRECTION]` tag; the remaining hits are historical records and the ADR's drop entry. | `grep -rn "\[CORRECTION" .agents docs workflow src scripts tests`; read each hit. | Agent [x] |
| The correction procedure and its reports state the in-place form. | Read `record-correction`, `wrapup` B8, `chain` Step 6, `documentation_taxonomy` and the changelog reference; no tag procedure remains. | Agent [x] |
| The ADR carries the 2026-11-17 drop entry and the narrowed R2; the old tag entries stay as history. | Read `closed_record_corrections.md`; the entry names the card and the tag. | Agent [x] |
| `AGENTS.md` no longer names the card, and `check-placement` keeps the repair-commit insight without the link. | Read both; `grep` finds no path. | Agent [x] |
| The roadmap row is `[x]` with its Landed note and handover link, and the milestone acceptance line states the drop. | Read `devlog/roadmap.md`. | Agent [x] |
| The document gate, the lint umbrella and the suite are clean. | `bash scripts/check_document_shape.sh`; `bash scripts/lint.sh`; `bash scripts/run_tests.sh` at `TEST_PARALLEL=2`; the default run's per-file deadline is the existing M3.1.2 row. | Agent [x] |
| Every decision this iteration recorded is realized in the files. | `git diff` each Decision against the tree. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The card and the `[CORRECTION]` tag rule are dropped. | The card's rows repeat the fold (`git-discipline`), the check's placement (`principle-check-placement`), the rule's strength (`principle-match-precision-to-stakes`), the record (`work-log`) and the artifact count (`single-source-of-truth`, `propagation-discipline`). The tag is the only unique row, and the operator drops it to cut the admin churn it causes. | This record; `closed_record_corrections.md`. |
| The correction reference stays a model of the class and the procedure; it gains no content rule. | The class table answers which procedure, and the procedure answers what changes. A content rule beside it has no reader that the drop leaves without one. | This record; `references/correction.md` unchanged. |
| The corrections ADR stays, with a new entry that drops the tag and the card and narrows R2 to the state-record form. | R1, R3, R4, R5 and R6 still stand and are carried by `task-list`, `git-discipline` and `record-correction`; the file is their design record, not a rule the drop retires. | This record; `closed_record_corrections.md`. |
| `principle-check-placement` keeps the repair-commit insight and drops the card link. | The insight is the card's own; the link is the carrier the drop owns. | This record; `check-placement`. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The card's six rows are carried elsewhere: the repair commit by the `git-discipline` fold, the rule and the gate by `principle-check-placement` and `principle-match-precision-to-stakes`, the handover entry by `work-log`, the amendment by the fold, and the artifact count by `single-source-of-truth` and `propagation-discipline`. The `[CORRECTION]` tag is the only row with no other home. | record | The drop is safe once the tag goes; no judgement is left without a carrier. | This record; the blast-radius table. |
| Dropping the tag does not drop the ADR whole. R1 state consistency, R3 the successor entry, R4 propagation, R5 operator direction and R6 the fold still stand; R2 narrows to the state-record marker. | record | The ADR stays as their design record; the 2026-09-27, 2026-10-18 and 2026-10-19 tag entries become historical. | This record; `closed_record_corrections.md`. |
| The frontmatter gate prints 26 principles and the deletion makes 25; neither the gate nor a test hardcodes the count, so no edit follows. | record | None; the count is derived from the directory walk. | This record; checked at the close. |
| The default suite run timed out `test_doc_wrap_legacy_gate.sh` at its 45s deadline; the file passes alone in 24s and the suite is 1640/1640 at `TEST_PARALLEL=2`. | test | The default run is not reproducible green on this host; the code is unaffected. | The existing M3.1.2 row, "The suite's parallel runner trips per-file deadlines on long tests". |

## Completed

| File | One-line change summary |
|---|---|
| `src/reasoning/agent-runtime/pi/config/agent/skills/principle-minimal-corrections/SKILL.md` | Deleted with its directory. |
| `src/reasoning/agent-runtime/pi/config/agent/AGENTS.md` | Removed the no-second-artifact sentence; the approval sentence stays. |
| `src/reasoning/agent-runtime/pi/config/agent/skills/principle-check-placement/SKILL.md` | Dropped the card link; kept the repair-commit insight. |
| `workflow/coding-agent/prompts/record-correction.md` | Dropped the tag procedure, the tag column and the marker stop; reworded the pointer. |
| `workflow/coding-agent/prompts/wrapup.md` | B8 settles the ADR in place; the `[AMENDMENT]` block stays. |
| `workflow/coding-agent/skills/handover-maintenance/runbooks/chain.md` | Step 6 and its failure mode state the in-place form. |
| `docs/reference/documentation_taxonomy.md` | The correction rule now splits claim and state records. |
| `.agents/skills/task-list/references/changelog.md` | Dropped "the shared principle" from the pointer. |
| `docs/adr/closed_record_corrections.md` | New 2026-11-17 drop entry; R2 narrowed; `Current` updated. |
| `src/reasoning/agent/drafts/bugfix.skill.md` | The `[CORRECTION]` block becomes the handover record. |
| `devlog/roadmap.md` | Row 379 rewritten to the drop; the milestone acceptance line updated; roadmap-maintenance check: 0 findings, M3.3.7 stays `In progress`. |
| `devlog/handovers/M3.3.7/20261117-01-workflow-minimal_corrections_deletion.md` | This record. |
