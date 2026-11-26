---
date: 2026-11-26
milestone: M3.5.6 - The discussion record corpus
type: Implementation
status: Closed
---

# Handover - Two states, and tenancy decides the deletion

## Objective

Collapse the discussion record's end states into one, and make an unowned record a finding whatever the enquiry has established, so the state never gates the deletion and no closing row leaves a record behind.

## Scope

A sixth row on `M3.5.6`, opened after the close-boundary analysis. One convention rule, two gates, one statechart, four test cases, one live record renamed, and the closed row that stated the old rule corrected.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The vocabulary is `open` and `ended`, and no live record carries another token. | `bash scripts/check_record_names.sh` clean across 12 records | Agent [x] |
| An unowned record fails whatever its state. | `bash tests/test_record_lifecycle_gate.sh` 7 passed, including `test_open_and_orphaned_flagged` | Agent [x] |
| The convention states that a closing row re-points or deletes, in the same commit, and that tenancy decides. | `grep -n 'Tenancy decides the deletion' .agents/skills/work-log/SKILL.md` | Agent [x] |
| The statechart's discussion machine and its invariants match. | `bash scripts/check_statechart.sh` clean across 37 states | Agent [x] |
| The gates and the suite pass. | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `concluded` and `rejected` collapse into `ended`. | Neither is read after the file goes, and a rename and delete in one commit leaves the token in no tree, so the distinction bought nothing. | `work-log`; `record-name.mjs` |
| Tenancy decides the deletion, never the enquiry's state. | The gate reads the tree at HEAD, so an end-state requirement before deletion is unenforceable and invisible. | `work-log`; `record-lifecycle.mjs` |
| A closing row re-points or deletes in the same commit, and the commit names the reason. | The reason has to land where it survives, since the file leaves no trace of its own. | `work-log` |
| The statechart keeps both enquiry states in the tenancy region but only one in the enquiry region, and deletion now fires from either. | The two regions are orthogonal; collapsing the enquiry removes the third arrow into `retired` without touching tenancy. | `workflow_statechart.md` |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The end-state requirement before deletion could not be checked: a gate reads the tree after the commit, where the record is already gone. | gate | a rule nobody can observe is ceremony, and it read as a control | this record; the rule dropped |
| A rename and a delete in one commit leave the renamed path in no tree, so the token never reaches git history. | measurement | the vocabulary's only durable trace is the deletion commit's message | this record |
| The statechart had a transition from each end state into `retired`, so the closed-state rule was duplicated in the reference as well as in the gate. | record | one rule in two carriers, both now corrected | `workflow_statechart.md` |
| The gate's orphan rule keyed on the filename's state, which made it blind to an unowned record whose enquiry was still open. | gate | the failure the statechart found; the condition is gone | `record-lifecycle.mjs` |
| The statechart's model is `tests/model/workflow_statechart/discussion.mmd`, and the document's chart block is a rendered copy; editing the document and then running `--write` restored the stale model over it, while the gate stayed clean because the view and the source agreed. | tool | a derived view cannot reveal a stale source, so the edit has to start at the model | this record; the model carries the correction |
