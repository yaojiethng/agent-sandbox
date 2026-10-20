---
date: 2026-10-14
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - retire the handover policy

## Objective

Retire `docs/policies/handover_policy.md` by subtraction: its mechanism joins the procedures that run it, its convention joins the `work-log` convention-skill, and its remainder is stated where it is enforced.

## Scope

The first slice of the roadmap row **Retire the policy form**; it sets the pattern the other seven slices follow. The parent row and the slice row **Retire `handover_policy`** are in [`devlog/roadmap.md`](../../roadmap.md).

The split is settled by the cross-cutting test: a handover element is protocol when a fixed workflow procedure's behaviour depends on it, and convention otherwise. The resolution, element by element:

| Element | Owner | Destination |
|---|---|---|
| the record's shape: the frontmatter block and the eight sections | convention | `.agents/skills/work-log/assets/handover.md`, the template |
| the controlled vocabularies (`type` with its commit mapping, `status`), the filename pattern and ordering, the section roles, the null markers, the format window | convention | `.agents/skills/work-log/SKILL.md` |
| the `milestone` field's format | convention | `.agents/skills/task-list/SKILL.md` |
| the part each procedure reads or writes | protocol | stated by that procedure; no artifact states the contract whole |
| the lifecycle transitions, the correction procedure, the content checks | mechanism | `iter`, `wrapup`, `record-correction`, `handover-maintenance` |
| never edit a closed record autonomously; Purpose; Brevity | remainder (rule) | stated where it is enforced |

The template carries the shape, so no second artifact states the contract: `iter` states the keys it writes, `wrapup` and `milestone-close` the `status` they set, `check-in` the `status` it reads, and `handover-maintenance` the keys and roles it validates, restating no vocabulary. The corpus keeps shipping the template as a stub; a project fills it.

The convention extraction from `handover-maintenance` is in this slice, because a workflow skill holding project structure is the same defect the slice removes. `handover-maintenance` keeps its checks and names a section by role; the handoff maps the role to the project's name.

Out of scope: the naming sweep that replaces the word "handover" with the workflow's general term across the shipped procedures (251 occurrences over 20 files) - written back as its own roadmap row; the `Drop the policy bundle` step, which lands after the last policy leaves; and the other seven policies.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `docs/policies/handover_policy.md` is retired: the file is gone and no live file references it | `test ! -f docs/policies/handover_policy.md`, then grep the live set for `handover_policy` | Operator [x] |
| The convention lands in `.agents/skills/work-log/SKILL.md`: the body section set, the null markers, the storage path, the filename pattern and its ordering, and the format window | read the file | Operator [x] |
| The `milestone` field's format lands in `.agents/skills/task-list/SKILL.md` | read the file | Operator [x] |
| The contract is distributed: no artifact states it whole, and each procedure states the part it reads or writes | grep for a central statement | Operator [x] |
| The work-unit record's template lands at `.agents/skills/work-log/assets/handover.md`, carrying the frontmatter block and the eight sections | read the file | Operator [x] |
| `handover-maintenance` names no project structure: no `devlog/handovers/` path, no section name, no gate-script path, no date window, no policy reference; a section is named by role and mapped through the handoff | grep the file for each | Operator [x] |
| `check-in` carries a general command with a default window of ten, which the operator may replace with a count or a period | read the file | Operator [x] |
| The mechanism lives in `iter`, `wrapup`, `record-correction` and `handover-maintenance`, and the remainder rules are stated where enforced | read the four files | Operator [x] |
| The naming sweep is its own roadmap row, and the silent near-match of a partial model id is recorded | read both | Operator [x] |
| The handover format gate passes over the tree, and its source comment names the new home of the vocabulary | `bash scripts/check_handover_format.sh` | Agent [ ] |
| `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are clean | run both | Agent [ ] |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/policies/handover_policy.md`](../../docs/policies/handover_policy.md) | the subject; retires |
| [`workflow/coding-agent/skills/handover-maintenance/SKILL.md`](../../../workflow/coding-agent/skills/handover-maintenance/SKILL.md) | receives the content checks and the correction form |
| [`workflow/coding-agent/prompts/iter.md`](../../../workflow/coding-agent/prompts/iter.md) | the handover's creation and lifecycle |
| [`workflow/coding-agent/prompts/wrapup.md`](../../../workflow/coding-agent/prompts/wrapup.md) | the handover's close |
| [`workflow/coding-agent/prompts/record-correction.md`](../../../workflow/coding-agent/prompts/record-correction.md) | the correction procedure |
| [`.agents/skills/work-log/SKILL.md`](../../../.agents/skills/work-log/SKILL.md) | receives the convention: paths, naming, types, format, null markers, the window |
| [`scripts/lint/handover-format.mjs`](../../../scripts/lint/handover-format.mjs) | its vocabulary is sourced from the policy |
| [`scripts/check_handover_format.sh`](../../../scripts/check_handover_format.sh) | the gate wrapper |
| [`workflow/coding-agent/skills/check-in/SKILL.md`](../../../workflow/coding-agent/skills/check-in/SKILL.md) | its latest-handover command drops the sequencing mechanism |
| [`.agents/skills/task-list/SKILL.md`](../../../.agents/skills/task-list/SKILL.md) | receives the `milestone` field's format |
| [`docs/adr/coding_agent_project_bindings.md`](../../../docs/adr/coding_agent_project_bindings.md) | records the cross-cutting test |
| [`AGENTS.md`](../../../AGENTS.md) | carries a policy pointer |
| [`devlog/roadmap.md`](../../roadmap.md) | the write-back |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The split test is cross-cutting, not rule-versus-structure: an element is protocol when a fixed workflow procedure's behaviour depends on it, and convention otherwise | the handover `type` is structure and still protocol - it selects the procedure family and the commit vocabulary - so rule-versus-structure fails on it | this handover; the ADR |
| The frontmatter is protocol and the body is convention, with the `milestone` field carrying a protocol role and a convention format | a fixed procedure writes, reads or branches on the frontmatter; nothing outside the handover subsystem reads the body | this handover; the ADR |
| The convention extraction from `handover-maintenance` is in this slice | a workflow skill holding project structure is the defect the slice removes, so folding it out would leave the pattern half-set | this handover; the roadmap row |
| The naming sweep is its own roadmap row | it is a mechanical change over 251 occurrences in 20 files, with its own outcome | this handover; the roadmap |
| The decision is D: no artifact states the contract whole, and the record's shape is its template | the alternatives each invent a second artifact or put the interface inside the audit skill | this handover; the ADR |
| The `check-in` window defaults to ten and the operator may replace it | a fixed count is executable where "a few" is not, and a named window is an instruction the agent follows | this handover; the step |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The shipped workflow procedures name the iteration record with the project's word "handover", 251 times across 20 files. Under the portability rule the workflow names the concept generally and the `work-log` convention supplies the word. | contradiction | next iteration; Triaged to: new roadmap row **The workflow names the work-unit record generally** |

## Completed

No file changes this iteration.
