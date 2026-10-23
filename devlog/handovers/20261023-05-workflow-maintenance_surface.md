---
date: 2026-10-23
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - The workflow statechart

## Objective

Draw the workflow surface as one statechart a reader can follow from a slash command to the state it leaves the agent in, and derive from that chart the checks that find a maintenance state nothing dispatches and a record written with no check on its path.

## Scope

Works the row **Declare the maintenance surface: which prompts invoke which maintenance skill**, a child of **Retire the policy form** under M3.3.2, by the instrument the operator chose after rejecting the first shape: the chart answers "when is the roadmap ever checked", and the checks read off it replace the gate the row originally asked for.

Two operator rulings frame the iteration. The declaration plus a both-ways gate was stopped: a separate index enforcing the prompts' references to skills is an index of imports, and the call site is already the declaration. The chart was named as the replacement, with a working document in the output mount to be distilled into a creation-and-maintenance skill later.

The working document is `/home/agentuser/workspace/output/workflow-statechart-notes.md`. It is not a deliverable record and does not land in the tree; the chart does.

Out of scope: the container lifecycle, the gate implementations, the `/task-queue` worktree fan-out, and the autonomous `-work` family, which the ADR reserves and no prompt carries. The two child rows stay open: **The two remaining handover content checks have no dispatcher** and **The close decisions move to the release gate**. The first is the error class this chart exists to name, which makes it visible rather than closes it.

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| A1 | The chart carries both grains and every command the tree offers | the `## Commands` table against `ls workflow/coding-agent/prompts/`: 17 of 17 | Agent [x] |
| A2 | Every maintenance skill appears as a check state with its dispatching command | the no-dispatcher check over the chart: three of four carry a command edge, and the exception is a finding | Agent [x] |
| A3 | Every dispatch edge names something that exists, and a draft is not a command | the dangling-dispatch check: no dispatch edge resolves to a draft, and the two stale citations are filed as their own row | Agent [x] |
| A4 | Every state is reachable and no non-record state is a dead end | the reachability and dead-end checks: no state lacks an inbound edge, no state outside the records region lacks an outbound one | Agent [x] |
| A5 | Every record kind's write path carries a check or is recorded as unchecked | the unchecked-record-write check: the unit's writes are covered, and the planning writes are not, which is a finding | Agent [x] |
| A6 | Every declared story path resolves id by id | ten paths, each pairing an edge: ten of ten | Agent [x] |
| A7 | The checks are stated with the query and the defect each finds | the document's `## Checks` table: ten rows | Agent [x] |
| A8 | The concept document links to the chart and no longer inlines a diagram | `autonomous_agent_loop.md`: zero code fences; `## The loop` carries the link | Agent [x] |
| A9 | No document still names the old anchor as the diagram's home | `grep autonomous_agent_loop.md#the-loop`: one archived handover only | Agent [x] |
| A10 | The working document holds the process and what distils into the skill | the file exists in the output mount, eleven sections | Agent [x] |
| A11 | The row closes and the findings are filed | the row reads `[x]`; the chart's two defects are a roadmap row; the skill is an open row under M3.3.3 | Agent [x] |
| A12 | Gates clean | `lint.sh`, `run_tests.sh`, `check_handover_format.sh` | Agent [x] |
| A13 | Neither shipped prompt names a draft, and `backlog-triage` states the test it applies | `grep -rn sequential-work workflow/coding-agent/prompts/`: no match; `wrapup.md` names `/milestone-start` alone as the non-invoker | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The declaration-plus-gate design is dropped, and the chart is the instrument | a prompt's reference to a skill is a static path, so the call site is the declaration; a JSON restatement plus a gate holds the copy true and not the property, and its membership rule is a judgement with no independent oracle | the working document, sections 2 and 7 |
| The state is the agent's situation at rest, the command is the event, and what it leaves behind is the effect | the operator's question is what a command can get an agent to do, which is a reachability property of states, not a property of prompts | working document, section 5 |
| The chart names its gaps rather than drawing an invented node | the autonomous family has no prompt in the tree, so an edge to it would be a dangling dispatch of exactly the kind the chart is built to find | working document, section 4 |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Where the chart lands | the file list, the reach rule that decides who may open it, and the checks' home | (a) `docs/reference/workflow_statechart.md`, one document carrying the diagram, the command table and the checks. (b) A diagram under `docs/` with its checks in a reference document. (c) One diagram per loop family, with the operator-driven family first. |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The iteration opened on a declaration plus a gate for five dispatch facts, which the operator stopped as an index of imports | Steering received, changing the iteration's scope | Three artefacts, two registrations and a forever-maintained copy, for a property a grep already answers | Recorded; the design is dropped, and the working document keeps the argument |
| `workflow/coding-agent/prompts/wrapup.md:31` and `backlog-triage.md` cite `sequential-work` and `parallel-work` as prompts, and both are drafts under `.agents/drafts/` with no file under `workflow/coding-agent/prompts/` | Dangling dispatch | A reader following the close's own `## Called from` table looks for two commands that do not exist | Fixed here: the chart refuses the node, and the three citations are removed, because each was a dependency on a draft that a shipped prompt does not need |
| The ADR's reserved term names `document` as one of the five maintenance operations, and `document` is a prompt with no skill behind it | Stale term in a live ADR | The chart cannot draw a maintenance state that has no skill, so the set has four | Filed here; the ADR is under development |
| `/plan` writes a roadmap row, a discussion record and an ADR with no check state on the path, and `history-cleanup` is reached from the `git-discipline` convention rather than from a command | The error class the chart was built to find | Maintenance work runs with no skill to check it, and one maintenance skill has no dispatcher at all | Filed as the roadmap row **A maintenance check no command reaches**, under M3.3.2 |
| The chart's ids replace the concept document's colon form (`it:open`) with an underscore (`it_open`), and the ADR carried the colon names | Naming propagation | A story path must be citable in one spelling, and two spellings make a path ambiguous | Corrected: the ADR's three gate names now match the chart's ids, and the colon form survives only in one archived handover |
| The chart is the app's total workflow map, and a user story is a declared path through it | Steering received, raising the chart's purpose beyond the maintenance question | Story paths become a first-class use: state ids must be stable and citable, and a path must be checkable against the edges | Recorded here; the chart document gains a story-path section, and a ninth check reads a declared path |
| The diagram is written in Mermaid 12.1.0, with a render capability planned and Pele named as the intended target | Stack decision | The chart's syntax must be the state-diagram subset that 12.1.0 renders; the Pele compatibility page is unreachable from this container, so the target's constraints are an open gap rather than a design input | Recorded here, and in the working document's stack section |
| The operator asked why two drafts were named in shipped prompts at all, and whether that is an unnecessary dependency | Steering received, opening a second question under the fix | A shipped prompt naming a draft is a claim nobody keeps true, and each such name is surface that has to be maintained | Filed as two roadmap rows under M3.3.2: a principles pass over `wrapup.md` and over `backlog-triage.md`, each judged against the `principle-*` and `communication-principle-*` corpora |

## Completed

| File | Change |
|---|---|
| [`docs/reference/workflow_statechart.md`](../../docs/reference/workflow_statechart.md) | new: the chart in Mermaid 12.1.0, 47 states and 70 edges over eight regions, the state table, the 17 commands, ten stories, ten checks, three declared gaps; a draft prompt is drawn nowhere |
| [`docs/reference/autonomous_agent_loop.md`](../../docs/reference/autonomous_agent_loop.md) | its inline ASCII diagram becomes the link to the chart; `## Skills` stops stating the dispatch set and points at the chart for it |
| [`docs/adr/coding_agent_loop_workflow.md`](../../docs/adr/coding_agent_loop_workflow.md) | both carriers retargeted to the chart, and its three gate names take the chart's ids |
| [`devlog/roadmap.md`](../roadmap.md) | the row closes on the chart; **A maintenance check no command reaches** and the statechart skill are filed, and the `-work` citation row is filed and closed on its fix, with the two principles-pass rows filed beside it |
| [`workflow/coding-agent/prompts/wrapup.md`](../../workflow/coding-agent/prompts/wrapup.md) | its Scope line and `## Called from` table stop naming two unshipped prompts |
| [`workflow/coding-agent/prompts/backlog-triage.md`](../../workflow/coding-agent/prompts/backlog-triage.md) | three citations removed; it now owns the well-specifiedness test it applies, and names M4 as the owner of plan sequencing |
| `$HOME/workspace/output/workflow-statechart-notes.md` | the working document: the rejected shape, the method, the drawing rules, the story-as-path reframing, the stack, and what distils into the skill |
| this record | `Status: Closed`, criteria, findings, completed |
