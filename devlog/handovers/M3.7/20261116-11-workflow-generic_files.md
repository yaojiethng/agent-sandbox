---
date: 2026-11-16
milestone: M3.7 - Git boundary and repository state
type: Workflow
status: Closed
---

# Handover - The change pipeline over generic files

## Objective

Answer whether the change pipeline's git operations can be stated over generic files, and land the generic bundle: the record set as the caller's input, with no local path or citation format in the audit, and the project's citation gate applied at each commit by the audit's existing gate loop.

## Scope

This iteration continues the generic-files subtask of the bundle parent `The change-pipeline bundle is workflow mechanism`, from handover `20261116-10`. It settles the boundary between the git operations and the record arms, lands that boundary in the reference, the ADR and the four bundle files, changes the audit to remove the local citation check and the local default paths, and moves that citation check to `scripts/check_record_citations.sh`, a tip-level project gate that `scripts/lint.sh` runs. The audit's per-commit gate loop applies it at each commit. It does not change the main loop's convention reads; the bundle links no convention.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The ADR carries a current entry naming the generic-files abstraction, the declared record set, the removed citation check and the project gate that takes it. | `sed -n '/## 2026-11-16 -- The git operations/,/^## /p' docs/adr/change_pipeline.md` names the abstraction, the removal and the gate. | Pass |
| The reference states the abstraction, the record set and the citation owner in a section of its own. | `grep -n "generic files" docs/reference/change_pipeline.md` finds the section. | Pass |
| The four bundle files state the record set as the caller's input and name no project convention. | `grep -nE "work-log\|task-list\|decision-records\|^## Project conventions$"` over the four files prints nothing. | Pass |
| `history-cleanup` names the seven content checks, states property 5 over the declared record set, and names the project's citation gate. | `grep -nE "seven checks\|record set\|citation" workflow/coding-agent/skills/git-discipline/runbooks/history-cleanup/SKILL.md` finds all three. | Pass |
| The audit has no citation check, no `devlog/` or `roadmap` path and empty record defaults, and reports seven checks. | `grep -nE "devlog\|roadmap\|citation"` in `audit.sh` prints nothing; `grep -n "across 7 checks"` finds the count. | Pass |
| The citation check is a tip-level project gate, and the audit's per-commit gate loop applies it at each commit. | `bash tests/test_record_citations.sh` passes; `scripts/lint.sh` includes the gate; the audit's per-commit gate test passes. | Pass |
| The audit's citation test is gone and the remaining content tests pass, including the no-record-set skips. | `bash tests/test_history_cleanup_audit.sh` passes. | Pass |
| A guard test keeps the bundle and the audit from regaining a local path or convention dependency. | `bash tests/test_change_pipeline_generic_files.sh` passes on the tree and fails on a temporary `work-log` or `devlog` mention. | Pass |
| The bundle parent is `[x]` and its summary names the generic-files answer and this handover. | `grep -n "The change-pipeline bundle is workflow mechanism" devlog/roadmap.md` names the answer and `20261116-11`. | Pass |
| The gates pass: `node scripts/skill_map.mjs`, `bash scripts/check_references.sh`, `bash scripts/lint.sh`, `TEST_PARALLEL=1 bash scripts/run_tests.sh`. | Each exits 0. | Pass |
| Every decision this iteration recorded is realized in the files. | The ADR entry, the reference section, the four bundle files and the audit state the recorded boundary. | Pass |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The git operations are defined over generic files; the record set is a declared input. | A change is a path/blob set; series properties 1-4 and 6 are content-agnostic, and property 5 is generic over a declared record root and path list. | ADR entry; the reference |
| The audit carries no citation check; `scripts/check_record_citations.sh` owns it as a tip-level project gate, and the bundle links no convention. | The citation path and syntax are local; a shipped audit cannot carry either. The project gate owns the format. | ADR entry; the reference; `history-cleanup` |
| The range check is the audit's per-commit gate loop; the citation check is one of the project's per-commit checks, not a second range loop. | The audit already checks out every commit and runs the project gate. Putting the citation check in `lint.sh` makes that loop apply it at each commit; a separate range-aware citation script would duplicate the loop. | ADR entry; the audit; `lint.sh` |
| The record arm keeps a default form table, labelled a default. | The form is the prompt's working tool; a caller with another record convention names it, and the bundle does not link it. | ADR entry; `record-correction` |
| The audit's record defaults are empty; the caller passes `--records=` and `--record-paths=`. | A default `devlog/` path is a local assumption in a bundled script. | ADR entry; the audit |
| The parent roadmap row is `[x]`; the three bundle iterations and the generic-files question are complete. | `roadmap-maintenance` 1.4: a closed item carries no open child; the child closed here, so the parent completes. | This record; the roadmap row |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The bundle parent was `[x]` while the generic-files child was open; `roadmap-maintenance` 1.4 names a closed item carrying open work. | record | Corrected to `[ ]` while the child was open; the child closed, so the parent is `[x]`. | This iteration; roadmap row corrected |
| The audit's check 2 reads `devlog/roadmap.md`/`roadmap_future.md` and Markdown link syntax; a bundled skill must not carry a local path or format. | code | Remove check 2 from the audit and move the code to `scripts/check_record_citations.sh`; the bundle links no convention. | ADR entry; the audit; the project gate |
| A tip-only gate alone misses a citation that is broken at its commit and fixed later in the series; the audit's per-commit gate loop is what makes it per-commit. | code | Move the citation check into `scripts/lint.sh` and let the audit's existing loop apply it; no second range loop. | ADR entry; `lint.sh`; the audit |
| The audit's `devlog/handovers` and `devlog/...` defaults are local assumptions. | code | Empty them; the caller passes the record set. | ADR entry; the audit |
| The four bundle files carry `## Project conventions` sections that read `work-log`, `task-list` and `decision-records`; these are the outgoing links the question targets. | record | The git operations must be stated generically; the record arms keep only default forms. | ADR entry; the four files |

## Completed

| File | One-line change summary |
|---|---|
| `docs/adr/change_pipeline.md` | New current entry: the git operations read paths and blobs; the record set is declared; the citation check moved to the project gate and the audit's loop. |
| `docs/reference/change_pipeline.md` | New `## The generic files` section: the abstraction, the record set and the citation owner. |
| `workflow/coding-agent/skills/git-discipline/SKILL.md` | The fold uses the caller's record set, not a convention. |
| `workflow/coding-agent/skills/git-discipline/runbooks/history-cleanup/SKILL.md` | `## The record set`; property 5 over the declared set; seven checks; the citation gate named as the project's. |
| `workflow/coding-agent/skills/recovery/SKILL.md` | The claim and the record write use the caller's record set. |
| `workflow/coding-agent/prompts/record-correction.md` | The forms are default forms; the commit fold stays generic. |
| `workflow/coding-agent/skills/git-discipline/runbooks/history-cleanup/scripts/audit.sh` | Check 2 removed; record defaults empty; seven checks; the per-commit gate loop remains. |
| `tests/test_history_cleanup_audit.sh` | Citation test removed; record sets passed explicitly; check numbers updated; 13 tests. |
| `scripts/check_record_citations.sh` | New tip-level project gate for the roadmap citations. |
| `tests/test_record_citations.sh` | New behavioural test for the citation gate: missing, existing, fragment, absent roadmap. |
| `scripts/lint.sh` | Adds `check_record_citations.sh`; 29 gates. |
| `.agents/skills/task-list/SKILL.md` | Names the citation gate and the audit's per-commit loop. |
| `tests/test_change_pipeline_generic_files.sh` | New guard: the bundle names no convention; the audit carries no local path or citation finding. |
| `devlog/roadmap.md` | The generic-files row answered and closed; the bundle parent and its four sub-rows compacted to one outcome summary. |
| `devlog/handovers/M3.7/20261116-11-workflow-generic_files.md` | This record. |
