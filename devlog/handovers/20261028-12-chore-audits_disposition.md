---
date: 2026-10-28
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Housekeeping
status: Closed
---

# Handover - the two folders' disposition

## Objective

Discharge the disposition list `surface-area-report.md` has carried since 2026-09-11, so `.agents/audits/` dissolves and `.agents/drafts/` gains the contract its contents need. The list's other items landed over the milestone; what remains is the folder the list lives in, one dropped payload, and one review payload that predates the runbook contract.

## Scope

| File | Why in scope |
|---|---|
| [`.agents/audits/surface-area-report.md`](../../.agents/audits/surface-area-report.md) | deleted with the folder: its list is discharged and its entry-point map duplicates the statechart and the workflow model |
| [`.agents/audits/dhh-code-audit.skill.md`](../../.agents/audits/dhh-code-audit.skill.md) | the list's one remaining `Drop` |
| [`workflow/coding-agent/skills/code-review/runbooks/kelsey-code-reviewer/SKILL.md`](../../workflow/coding-agent/skills/code-review/runbooks/kelsey-code-reviewer/SKILL.md) | deleted on operator direction: it predates the runbook contract and names no scope |
| [`workflow/coding-agent/skills/code-review/SKILL.md`](../../workflow/coding-agent/skills/code-review/SKILL.md) | `## Not yet accepted` is removed with both its rows |
| [`docs/development/conventions.md`](../../docs/development/conventions.md) | the policy table names `.agents/audits/*.skill.md` and a `src/reasoning/agent/drafts/` path the 2026-10-16 move deleted |
| [`docs/development/prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) | `## Draft status and the switch-over gate` is the folder's contract, and it covers the draft but not the run brief or the drain |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the row closes, the report citations leave, three owning rows are filed, and two kelsey carriers are corrected |

Out of scope: `.agents/drafts/instruction-cleanup-goal-only.md`, whose fate waits on the eval verdict, and the open briefs' own work. The `command-surface-matrix` skill is reviewed for promotion in its own unit.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `.agents/audits` does not exist | `test ! -d .agents/audits` | Agent [x] |
| The disposition list is gone from the tree and from the milestone lines | `test ! -e .agents/audits/surface-area-report.md`, and the two roadmap lines state the criterion without a link | Agent [x] |
| The shell carries no not-yet-accepted path | `grep -n 'Not yet accepted' workflow/coding-agent/skills/code-review/SKILL.md` returns nothing, and both payloads it named are gone | Agent [x] |
| No live document names a payload that is not on disk | `grep -rn` for `.agents/audits` and `kelsey` over `docs/`, `workflow/`, `.agents/`, `AGENTS.md` returns provenance comments and closed-row history only | Agent [x] |
| The drafts contract covers both kinds and the drain | read `## Draft status and the switch-over gate`; it states the draft, the run brief, the owning row and the drain | Agent [x] |
| Every file left in the folder is named by a roadmap row or recorded here as waiting on one | the folder's listing against `grep` of the roadmap, recorded in this handover | Agent [x] |
| The roadmap records the ruling | `git diff <iteration-base> -- devlog/roadmap.md` | Agent [x] |
| Every decision this iteration recorded is realized in the files | the decisions table | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The report is deleted rather than archived | its list is discharged and its entry-point map repeats `workflow_statechart.md` and `agent_workflow.md`; a record kept because closed records cite it is a copy no reader opens | this record, operator direction |
| The milestone lines that cite the report state the criterion without the link | a deleted file cannot be linked from a live record, and the criterion stands on its own | `devlog/roadmap.md` |
| `kelsey-code-reviewer` is deleted | it predates the runbook contract and names no scope, its shell and image rules already live in the `code-review-bash` and container patterns, and a persona instance is not worth a payload | this record, operator direction |
| `## Not yet accepted` is deleted with its table | it is a second acceptance path beside the runbook contract, and neither payload it routes is worth keeping | `code-review/SKILL.md` |
| The drafts folder already has a contract, and the gap is the brief, not the draft | `## Draft status and the switch-over gate` states draft placement and the switch-over, which is the half the report asked for | `prompt-authoring-conventions.md` |
| The contract gains the run brief, the owning row and the drain | the folder is live workflow output that `/scope` writes to, so a run brief is neither a draft awaiting review nor a record, and it is deleted when its row closes | `prompt-authoring-conventions.md` |
| A brief that is still live and has no owning row gains one | the contract cannot be met by deleting work nobody has done | `devlog/roadmap.md`, three rows |
| `command-surface-matrix/` is not misfiled | the contract places a skill that is not yet operator-reviewed in `drafts/`, and its own `## Promotion` states the move that releases it; the drain therefore leaves it and files the promotion row | `devlog/roadmap.md` |
| The policy table names the surfaces that exist | it lists `.agents/audits/*.skill.md`, and a `src/reasoning/agent/drafts/` path deleted on 2026-10-16 | `conventions.md` |
| The goal-only draft stays until the eval verdict | its arm is not judged yet, and deleting the source before the verdict loses the text the verdict is about | this record, operator direction |

## Decisions pending

None.

## Findings

| Finding | Type | Triaged to |
|---|---|---|
| `close-the-model-bypass-run.md` is live, with an unbuilt gate it specifies, and no roadmap row owns it | defect | `devlog/roadmap.md`, filed under M3.3.6 |
| `dispatch-harness-defects-handoff.md` carries six dispatch defects, four of them high or medium severity, and no roadmap row owns it | defect | `devlog/roadmap.md`, filed under M3.6.5 |
| The same brief cites `.agents/drafts/seat-contract-run.md`, which does not exist in the tree | defect | the row filed above, which carries the repair |
| `docs/development/conventions.md` also lists `src/reasoning/agent/drafts/*.skill.md`, deleted by the 2026-10-16 move, so the table is stale twice | carrier | `docs/development/conventions.md`, corrected with the audits row |
| The consolidation row and the persona row both cite the kelsey payload as a file to read | carrier | `devlog/roadmap.md`, corrected with the deletion |
| `tests/eval/instruction-cleanup/SOURCES.md` and two merge-provenance comments name deleted audit paths | provenance | kept: a provenance row records where content came from, and a deletion does not retract it |
| `command-surface-matrix/` is a ready skill under an unreviewed draft status, so it occupies the drafts folder until a review releases it | deferred | `devlog/roadmap.md`, the promotion row |
| The closed consolidation row still carries an expanded checklist of eleven completed children, which `roadmap-maintenance` 2.1 reports as uncompacted | deferred | `/milestone-close`, whose compaction step owns it |

## Completed

| Item | Note |
|---|---|
| the handover opened | this record, type `Housekeeping`, from the operator's directive |
| roadmap maintenance verified | the prior handover's row reads `[x]` and M3.2.2 reads `In progress`, so no edit was needed before this handover |
| the folder's contents enumerated | `git ls-files .agents/`, nineteen drafts plus one skill directory, two audit files |
| each file's owning row traced | `grep` per filename across `devlog/`, `docs/`, `workflow/`, `tests/`; after the write-back every file in the folder is named by a row except `instruction-cleanup-goal-only.md`, whose fate the eval verdict owns |
| the audits folder dissolved | both files deleted, the directory removed; `code-review/SKILL.md` lost its `## Not yet accepted` section and the `kelsey-code-reviewer` runbook with it |
| the drafts contract amended | `## Draft status and the switch-over gate` gains the run brief, the owning row and the drain |
| the policy table corrected | `docs/development/conventions.md` names the two skill roots that exist |
| the roadmap written | the consolidation row closed; the objective and the acceptance criterion lost their report link; the kelsey clauses in the consolidation and persona rows corrected; three rows filed |
| the gates run | markdown, doc shape, handover format, instruction surfaces, lint (15 gates), suite: 1349 passed across 98 files |
