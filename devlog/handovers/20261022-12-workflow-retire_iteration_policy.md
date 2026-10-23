---
date: 2026-10-22
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - Retire iteration_policy

## Objective

Reduce `iteration_policy.md` to the protocol it is: the invariants the runbooks must not break, moved out of the policy folder and renamed, with its four mechanism and convention sections stated where they are enforced.

## Scope

`M3.3.2 - Retire the policy form`, slice `Retire iteration_policy`, the last of the eight. It continues the settled chain in [`20261014-design-settled-retire_the_policy_form.md`](../discussions/20261014-design-settled-retire_the_policy_form.md), after `Retire documentation_policy` (handover `20261022-11`).

The design's fate for this policy is the exception it wrote for itself: the Principles and the Iteration Invariants bind every runbook, so no single procedure can hold them, and the document survives. What changes is its form: after this slice nothing it holds is a policy, so it leaves `docs/policies/`.

The subtraction, at section grain:

| Section | Fate |
|---|---|
| `## Loop workflow prompts`, `## Sidequests`, `## The autonomous agent loop`, `## Iteration Invariants` and its unit-and-scope and gate subsections, `### Close invariants` | the protocol, stays |
| `### Canonical procedures` -- the squash block | into `wrapup` A5, which cited it as "the single source; do not restate it here" |
| `### Acceptance-criteria invariants` -- the authoring bar | into `iter` Step 5, which cited it and deferred to it |
| `### Record-state invariants` -- four bullets | into `iter` Step 6, which cited the section and ran none of it |
| `### Record-state invariants` -- `Findings is the shared surface`, and `### Close invariants` -- `Findings publish` | cut, because `iter` Step 6 and `wrapup` B6 already run them |
| `### Sub-milestone close` | cut: its one rule, operator-owned probation decisions, is already in `milestone-close` |
| `## File Tracking` -- no registry | into the `docs` skill |
| `## File Tracking` -- the scope proposal owns the file list | cut, because `iter`'s scope gate already carries that table |
| `## Principles` -- the five echoes | cut: each named another layer as its owner in the heading |
| `## Principles` -- the delta paragraph | into `iter` Step 5 with the rest of the authoring bar |

The file becomes `docs/reference/iteration_protocol.md`. `Drop the policy bundle` deletes `docs/policies/` and cannot be the row that relocates the last thing shipping from it.

The slice is two units.

| Unit | Lands | Ends when |
|---|---|---|
| 1 | the protocol file, its four mechanism and convention moves, and the gate that holds its `scope` declaration | the file is `docs/reference/iteration_protocol.md`, each moved section has its home, and `check_instruction_surfaces.sh` and its fixture follow the path |
| 2 | the citation sweep, the roadmap row and the parent | `grep -rln iteration_policy` returns only `devlog/` and the archive, and all four gates are clean |

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The protocol is a reference document with its three frontmatter fields | `head -8 docs/reference/iteration_protocol.md` shows `description`, `scope`, `reader` | Agent [x] |
| No policy file remains | `ls docs/policies/` fails, and the census query over `docs/policies/` returns nothing | Agent [x] |
| The squash block lives in `wrapup` A5 | `grep 'git reset --soft' workflow/coding-agent/prompts/wrapup.md` | Agent [x] |
| The authoring bar lives in `iter` Step 5 | `grep -c 'paired negative\|weakest sufficient' workflow/coding-agent/prompts/iter.md` is 2 | Agent [x] |
| The four record-state bullets live in `iter` | `grep` the record-write verification and the open-exchange rule | Agent [x] |
| The loop-inventory gate follows the new path | `bash scripts/check_instruction_surfaces.sh` is clean | Agent [x] |
| No live surface names the old path | `grep -rln iteration_policy docs scripts src workflow .agents AGENTS.md tests readme.md` prints only the records | Agent [x] |
| The roadmap row closes and the parent reads eight slices | `grep` the row and the parent line | Agent [x] |
| Lint, ledger, suite, handover gate and surface gate clean | the five scripts | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The file moves to `docs/reference/` and is renamed `iteration_protocol.md` | Nothing in it is a policy after the subtraction, it is the runbooks' contract, and `Drop the policy bundle` deletes the folder it sits in | this record |
| The acceptance-criteria authoring bar goes to `iter` Step 5, not to `work-log` | `work-log` states that what makes a criterion well-formed is the workflow's, not the convention's. `iter` is the only generator: `scope.md` derives none | this record |
| No skill holds the acceptance-criteria bar | A convention-skill is for a bar more than one procedure applies. One caller keeps the rule in that caller | this record |
| The close invariants stay in the protocol, though `wrapup` B2 to B4 cite them | `wrapup` points at them as the single source rather than restating them, which is the arrangement the subtraction should preserve | this record |
| The six echoed principles and the two findings rules are cut, not moved | Each names its owner in its own sentence, and two are already run by `iter` Step 6 and `wrapup` B6 | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The record-state invariants are cited by `iter` and run by no prompt: `iter` points at the section for four rules it never states | gap | the pointer carried rules the runbook needed at the moment it ran, so cutting the section without moving them would have lost four | moved into `iter` Step 6 in unit 1 |
| My first reading said `iter` and `wrapup` already ran every record-state bullet | defect | four of the five were only ever in the protocol, and the cut as proposed would have deleted them | corrected in unit 1; the reading was verified rule by rule |
| `scope.md` derives no acceptance criteria, against the assumption that two prompts generate them | gap | the shareability of the bar was assumed rather than checked, and it decides whether the bar needs a skill | no skill; stated in the decisions above |
| `wrapup` B2, B3 and B4 cite the close invariants as their single source | description | the close invariants must stay in the protocol or three runbook steps lose their text | the section stays in unit 1 |
| The folder emptied, so the three `COPY docs/policies/` lines and four manifest rows would fail a fresh build | defect | the last policy left and the bundle still shipped a path that no longer exists | `Drop the policy bundle` closed in this slice, with its three dockerfile lines and four manifest rows |
| `bootstrap` provisioned a new project by copying the policy set from `/opt/sandbox/docs/policies/`, and `agent_workflow.md` described the policy layer as live | defect | a provisioning run would copy nothing and a reader would look for a folder that is gone | both retargeted to the protocol and the convention corpus |
| `doc-advisor-policy.md` dispatches a reviewer over a policy-retirement slice, and this is the last policy | gap | the prompt's subject no longer exists, so its next dispatch has nothing to read | a roadmap row is filed in this unit |
| The two splitting ADRs still state policy-document decisions in the present tense, and `policy_declarative_framing.md` is not marked superseded | gap | a reader meets a live-sounding decision whose subject was retired | left as the record it is; `coding_agent_project_bindings.md` carries the retirement, and the framing ADR's status is an operator call |

## Completed

| File | Change |
|---|---|
| `docs/policies/iteration_policy.md` | |
| [`docs/reference/iteration_protocol.md`](../../docs/reference/iteration_protocol.md) | the protocol: the runbook declaration, sidequests, four principles, the loop, and the unit, gate and close invariants |
| `docs/policies/iteration_policy.md` | deleted; the folder goes with it |
| [`workflow/coding-agent/prompts/wrapup.md`](../../workflow/coding-agent/prompts/wrapup.md) | A5 holds the canonical squash block |
| [`workflow/coding-agent/prompts/iter.md`](../../workflow/coding-agent/prompts/iter.md) | Step 5 holds the acceptance-criteria authoring bar; Step 6 holds the four record-state rules; both policy citations retarget |
| [`.agents/skills/docs/SKILL.md`](../../.agents/skills/docs/SKILL.md) | the folder table loses the policy row |
| [`scripts/check_instruction_surfaces.sh`](../../scripts/check_instruction_surfaces.sh) | the loop-inventory path and its comments name the protocol |
| [`src/build/container-interface.json`](../../src/build/container-interface.json) | three mount rows and the image path row for `docs/policies/` removed |
| [`src/reasoning/providers/pi/provider.dockerfile`](../../src/reasoning/providers/pi/provider.dockerfile) | the `COPY docs/policies/` line |
| [`src/reasoning/providers/hermes/provider.dockerfile`](../../src/reasoning/providers/hermes/provider.dockerfile) | the `COPY docs/policies/` line |
| [`src/reasoning/providers/opencode/provider.dockerfile`](../../src/reasoning/providers/opencode/provider.dockerfile) | the `COPY docs/policies/` line |
| [`src/reasoning/providers/pi/config/agent/AGENTS.md`](../../src/reasoning/providers/pi/config/agent/AGENTS.md) | the scope table loses the policy row |
| `/home/agentuser/.pi/agent/AGENTS.md` | the same row |
| [`docs/reference/agent_workflow.md`](../../docs/reference/agent_workflow.md) | `### Policy documents` becomes `### Where the rules live`, and two citations retarget |
| [`docs/reference/autonomous_agent_loop.md`](../../docs/reference/autonomous_agent_loop.md) | the invariants' owner is the protocol |
| [`docs/development/prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) | three retargets: the convention-skill as a document type, and the two shipped-path rules |
| [`docs/development/bash-coding-conventions.md`](../../docs/development/bash-coding-conventions.md) | the example's folder list |
| [`docs/adr/coding_agent_loop_workflow.md`](../../docs/adr/coding_agent_loop_workflow.md) | the 2026-10-22 note: the invariants' owner is the protocol |
| [`.agents/skills/work-log/SKILL.md`](../../.agents/skills/work-log/SKILL.md) | the discussion-name rule names `docs/`, not the deleted folder |
| [`workflow/coding-agent/prompts/bootstrap.md`](../../workflow/coding-agent/prompts/bootstrap.md) | six retargets: the protocol replaces the policy set in the record inventory, the source paths, the gap table and the materialize step |
| [`workflow/coding-agent/skills/doc-maintenance/SKILL.md`](../../workflow/coding-agent/skills/doc-maintenance/SKILL.md) | the shipped set is `docs/reference/` |
| [`tests/test_instruction_surfaces.sh`](../../tests/test_instruction_surfaces.sh) | the fixture writes the protocol at its new path |
| [`tests/test_linking.sh`](../../tests/test_linking.sh) | the fixture's bundled document is a reference document |
| [`scripts/lint/norm-ownership.tsv`](../../scripts/lint/norm-ownership.tsv) | regenerated: 99 rows, 16 gated, 6 reviewed, 46 judgement, 31 description, 12 sourced |
| `scripts/lint/norm-judgements.tsv` | rebuilt from the curated groups |
| [`devlog/roadmap.md`](../roadmap.md) | the slice and `Drop the policy bundle` close, and the parent reads eight slices |
