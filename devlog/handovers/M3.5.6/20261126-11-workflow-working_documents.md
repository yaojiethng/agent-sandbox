---
date: 2026-11-26
milestone: M3.5.6 - The discussion record corpus
type: Workflow
status: Closed
---

# Handover - Working documents are owned like records

## Objective

Extend the lifecycle to the plan-stage working documents under `.agents/drafts/`, so a task's drafts are cleaned with it and none of them sits outside any rule.

## Scope

An eleventh row on `M3.5.6`: the cleanup clause in `task-list`, the lifecycle gate walking a second folder, four working documents given an owner, and three gate tests.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `task-list` states that cleanup covers working documents. | `grep -n 'working documents as well as its records' .agents/skills/task-list/SKILL.md` | Agent [x] |
| The gate walks `.agents/drafts/` under the same tenancy rule. | `bash scripts/check_record_lifecycle.sh` reports 15 working documents | Agent [x] |
| A working document with no owner fails, and a closed row naming one fails. | `bash tests/test_record_lifecycle_gate.sh` 12 passed | Agent [x] |
| Every working document is owned, and none is deleted. | the gate is clean across 15 | Agent [x] |
| The gates and the suite pass. | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Working documents are owned by a roadmap line outside a closed row, and the name is spelled with its folder. | A bare file name is ambiguous in this repository: `fanout.md` is both a draft and a shipped prompt. The path makes the owner explicit. | `task-list`; the gate |
| All fifteen stay. The four without an owner were given one rather than deleted. | They are the working record behind live milestones: the M3.4 design run, the roadmap-mechanism run, the state-machine audit prompt and the sequential run. | the four roadmap lines |
| The folder is gated rather than swept. | The same argument as the record layer: a rule that runs at the gate cannot be forgotten the way a clean-out was. | the lifecycle gate |
| A closed row naming a working document is a finding, not a deletion. | It is the same shape as a closed row naming a record, and the repair is the same. | the gate |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Twelve of the fifteen documents were already owned transitively, by another working document or a live record, but not by a roadmap line. | record | ownership by mention-chain is invisible to a reader and to a gate | the four explicit lines |
| A bare-name rule would have owned the wrong file: `fanout.md` and `task-queue.md` each exist as both a draft and a shipped prompt. | gate | the rule needs the folder in the name, and the three tests hold that | the gate |
| The two run documents were cited only by closed handovers, so nothing in the roadmap would have found them. | record | a working record can outlive every reference to it except a handover | the two `Working record` lines |
