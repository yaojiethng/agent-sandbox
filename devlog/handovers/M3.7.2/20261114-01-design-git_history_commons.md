---
date: 2026-11-14
milestone: M3.7.2 - The change model and its refinements
type: Design
status: Closed
---

# Handover - The git history commons ADR and the record cleanup

## Objective

Record the git history commons decision in an ADR, move the decision-record
template to the shape it needs, land the approved subject-length rule, retire the
evidence report and the spent commit-body eval case, and leave the convention's
reframe as a subtask.

## Scope

Works the row *The convention leads from history as a commons and owns the
primitives*, under M3.7.2's *The branch-preparation surface is one host flow*.
The convention's reframe is not in this iteration: the operator rejected its
text after review and directed the reframe subtask; the approved subject-length
rule lands here. In scope: the ADR, the `decision-records` shape, the
subject-length rule, the evidence report's retirement and the eval case's
retirement. Out of scope: the convention's reframe (the commons framing, the
section shape and the working-tree rule); the body wording; the 2026-08-10
feedback entry, which stays open and is re-scoped to the reframe subtask; the
reference files; B2, B4 and B5; the eval reader check.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The ADR holds the four fields, the 50/72 reason and the dated measurement. | `grep -n 'Decision\|Evidence\|targeting 50\|39%' docs/adr/git_commit_history_commons.md`. | Agent [x] |
| `decision-records` carries the one shape, in the asset and the field list. | `grep -n 'Evidence' .agents/skills/decision-records/SKILL.md .agents/skills/decision-records/assets/adr.md`; no `Rationale` in the template. | Agent [x] |
| The subject rule states 72 at most, targeting 50. | `grep -n 'targeting 50' .agents/skills/git-discipline/SKILL.md`. | Agent [x] |
| The convention's only change is the subject rule and its paragraph. | `git diff HEAD -- .agents/skills/git-discipline/SKILL.md` names one file and one hunk, the row and the paragraph. | Agent [x] |
| The evidence report is retired, and no live file links it. | `test -e` false; `grep -rn` outside `devlog/handovers/` returns nothing. | Agent [x] |
| The eval case is retired, and no live file links it. | `test -e` false; `grep -rn` outside `devlog/handovers/` returns nothing. | Agent [x] |
| The 2026-08-10 feedback entry stays open and names the reframe subtask. | `grep -n 'scoped: M3.7.2 -- the reframe subtask' devlog/AGENT_FEEDBACK.md`. | Agent [x] |
| The roadmap carries the parent open with the length and reframe subtasks and the ADR link. | `grep -n 'The commit subject budget\|The convention is reframed\|git_commit_history_commons' devlog/roadmap.md`. | Agent [x] |
| Every decision this iteration records is realized in the files. | Read the Decisions table against the diff. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The git history commons decision is recorded in `docs/adr/git_commit_history_commons.md`; the convention's reframe is not part of this iteration. | The operator accepted the ADR, rejected the rewrite's text, and approved the subject-length rule as the single convention edit; the reframe is its own iteration. | this record; the roadmap's reframe subtask |
| The ADR entry shape becomes Decision with its reason inline, Evidence, Rejected alternatives, Edge cases; the `decision-records` asset and field list move to it. | The decision and the material it rests on sit in one entry, so no companion record is needed, and one shape avoids two forms. | `.agents/skills/decision-records/assets/adr.md`, `.agents/skills/decision-records/SKILL.md` |
| The evidence report and the spent commit-body eval case are retired. | The ADR holds the measurement and adjudications, so the report has no remaining consumer; the eval case has a non-separating sub-case, a dead source and a pre-rewrite fixture. | `devlog/discussions/20261112-report-open-git_discipline_evidence.md`, `tests/eval/commit-body-budget/case.json` |
| The subject rule lands at 72 at most targeting 50; the reframe subtask carries the commons framing and the working-tree rule. | The operator approved the length edit as the single convention change and deferred the reframe. | `.agents/skills/git-discipline/SKILL.md`; the roadmap's reframe subtask |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The eval case `tests/eval/commit-body-budget/case.json` names a 2026-10-05 feedback entry as its source; `AGENT_FEEDBACK.md` no longer holds it. | record | the case's provenance is stale | this iteration, retired |
| The same case's `delivery-commit-body` sub-case records that its assertion passed in both configurations, and the eval skill's step 7 says a case that passes in every arm retires. | record | one live case and one spent case in one file | this iteration, retired |
| The roadmap-maintenance check 3.6 on closed rows still stands; the M3.7.2 closed rows carry narrative and numbers that go stale. | record | none this iteration | the milestone close's compaction |
| The operator rejected the convention rewrite after review: the ADR is accepted and the text edits are deferred to two subtasks. | record | the iteration lands the ADR and the cleanup only | the roadmap's two subtasks |

## Completed

| File | One-line change summary |
|---|---|
| `.agents/skills/git-discipline/SKILL.md` | the subject row: 72 at most, targeting 50 |
| `docs/adr/git_commit_history_commons.md` | new ADR: the decision, the dated evidence, the rejections and the edge cases |
| `.agents/skills/decision-records/assets/adr.md` | the entry shape becomes Decision, Evidence, Rejected alternatives, Edge cases |
| `.agents/skills/decision-records/SKILL.md` | the field list and the authority/evidence sentence move to the new shape |
| `devlog/discussions/20261112-report-open-git_discipline_evidence.md` | retired; its measurement and adjudications are in the ADR |
| `tests/eval/commit-body-budget/case.json` | retired; one sub-case non-separating, its source gone, its fixture pre-rewrite |
| `devlog/AGENT_FEEDBACK.md` | the 2026-08-10 entry stays open, re-scoped to the reframe subtask |
| `devlog/roadmap.md` | the parent row stays open with the length and reframe subtasks and the ADR link |
| (maintenance) | `roadmap-maintenance` run over `devlog/roadmap.md`: no completed sub-milestone shown active; the check-3.6 finding stays with the milestone close |
