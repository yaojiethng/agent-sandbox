---
date: 2026-10-23
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - The prompt command-surface pass

## Objective

`wrapup.md` and `backlog-triage.md` are read against the `principle-*` and `communication-principle-*` corpora and cut to the command references a step acts on, with a disposition recorded for every one.

## Scope

The two rows **`wrapup.md` takes a principles pass over its command surface** and **`backlog-triage.md` takes a principles pass over its command surface**, both under M3.3.2 and both raised by [`20261023-05`](20261023-05-workflow-maintenance_surface.md), which removed the four references that were merely stale and left the question of the ones that are merely repeated.

Out of scope: the six rows of M3.3.3's pipeline, and the mechanical check that would catch a citation naming no file. The second is worth building and is a unit of its own; it is filed as an open row rather than grown here.

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| A1 | Every command-shaped reference in both files carries one census row | census rows against the token set: 8 distinct slash tokens in `wrapup.md`, 1 in `backlog-triage.md`, plus the named conventions and documents; 38 rows | Agent [x] |
| A2 | No command is named in two forms | `grep -o '[^/]milestone-start' wrapup.md`: 0 | Agent [x] |
| A3 | The list of what `/commit` owns appears once, in the handoff section | `grep -n 'Preparing the handover'`: one line, in `## Hand the commit to /commit`; `## Scope` and `## Mandate` name it without listing what it owns | Agent [x] |
| A4 | The no-write claim appears twice in `backlog-triage.md`, definition and check | `edits no record` 1, `changes nothing` 1, `does not write records` 0 | Agent [x] |
| A5 | `## Scope` in `wrapup.md` enumerates no caller | the Scope paragraph names no slash command but the two owners it links | Agent [x] |
| A6 | Each census row names its class and a judgement that exists | 38 rows; 14 distinct judgements, all present under the pi provider's `skills/` | Agent [x] |
| A7 | Every cut is gone from the file it was cut from | nine removed phrasings grepped: 0 in both files | Agent [x] |
| A8 | Nothing links into either prompt by anchor | `grep -rn 'wrapup.md#\|backlog-triage.md#'`: 0 | Agent [x] |
| A9 | Both prompts keep what carries load | `## Called from` still names its four callers in three bullets; B1 to B10 all present in order; Step 5 still lists its four verdicts | Agent [x] |
| A10 | `wrapup.md` dispatches both record checks itself | `grep -n 'roadmap-maintenance\|handover-maintenance'`: both named in B9 | Agent [x] |
| A11 | The close's check runs after the rows it reads are written | `grep -n '^### B'` lists B9 after B8 | Agent [x] |
| A12 | The close's input contract names the record-check report | `## Input contract` has three rows | Agent [x] |
| A13 | The chart draws the close's check | `chk_close` is a declared state, three commands reach it, two edges leave it, and every story path resolves | Agent [x] |
| A14 | The protocol states the invariant the close's check runs | `iteration_protocol.md` carries **The close's own writes are checked** | Agent [x] |
| A15 | Every record the close writes is checked before the commit | read B9 against B4, B6 and B8: each write step precedes it | Agent [x] |

## Decisions

| # | Decision | Rationale | Where recorded |
|---|---|---|---|
| D1 | `## Called from` stays the single declaration of who invokes `/wrapup` | The chart's edges are read from it | design record |
| D2 | One channel per fact: a definition in `## Scope`, a check in `## Failure modes` | Four statements of one boundary is four things to keep true | design record |
| D3 | A non-goal keeps its boundary and drops the owner clause | Routing already names the owner | design record |
| D4 | Every command in slash form, matching its prompt filename | A search for one form finds every use | design record |
| D5 | A close step keeps its invariant link and drops a boundary `## Scope` states | The boundary has one home | design record |
| D6 | `wrapup.md` dispatches both record checks itself, in B9 | The close is called by three prompts and one produced a report | design record |
| D7 | Two runs over two trees: the gate's and the close's | Each has a subject the other cannot see | design record |
| D8 | `## Input contract` names the record-check report | B4 reads it | design record |
| D9 | The chart gains `chk_close` between each released gate and its successor | The close's check is a state the loop rests in | design record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `wrapup.md` names no maintenance skill in `## Project conventions` and dispatches none, yet B4 and B8 both consume "the record-check report from the gate" | Dangling dispatch, in the file this pass edits | A close run by `/plan` or `/document` publishes against a report no step on its path produced, and the close reports success | Fixed here: B9 dispatches both skills, so a caller other than `/iter` gets the report it reads. The row **A maintenance check no command reaches** narrows to `history-cleanup` |
| `wrapup.md`'s `## Input contract` names two inputs -- session scope and current branch -- and B4, B6 and B8 each need a third: the record-check report | Unsatisfied entry, one table row wide | A close reads as data entry against inputs the contract never names, so a caller cannot tell it is missing one | Fixed here: a third row added to `## Input contract` |
| The gate's record checks run before the close's write-back, so the rows the close writes are never checked by the report that validates them; last iteration's five open rows under a closed parent are the instance, found at this iteration's open by the one run that looks after a write-back | Ordering defect in the close | Every iteration's roadmap write-back is unchecked by construction, and the defect surfaces a day later as a maintenance finding | Fixed here, on the operator's ruling that the whole set is one task: B9 reruns both checks after the writes, and `iteration_protocol.md` carries the invariant. The row **The close decisions move to the release gate** stays open, its predicate unchanged |

## Completed

| File | Change |
|---|---|
| [`workflow/coding-agent/prompts/wrapup.md`](../../workflow/coding-agent/prompts/wrapup.md) | 22 references through the pass; a third input row; B9 added and the rest renumbered; the dispatched checks are its own |
| [`workflow/coding-agent/prompts/backlog-triage.md`](../../workflow/coding-agent/prompts/backlog-triage.md) | 16 references through the pass; the no-write claim from four statements to two; three forecasts cut |
| [`devlog/discussions/20261023-design-prompt_command_surface.md`](../discussions/20261023-design-prompt_command_surface.md) | the method, five classes, nine decisions, three rejections and the 38-row census |
| [`docs/reference/workflow_statechart.md`](../../docs/reference/workflow_statechart.md) | `chk_close` declared, three edges in, two out; the `/wrapup` row now names the two skills it calls; the path check restated to what holds, and story coverage named as a gap |
| [`docs/reference/iteration_protocol.md`](../../docs/reference/iteration_protocol.md) | the close invariant **The close's own writes are checked** |
| [`docs/reference/autonomous_agent_loop.md`](../../docs/reference/autonomous_agent_loop.md) | closing now states that the close reruns both checks over the rows it wrote |
| [`devlog/roadmap.md`](../roadmap.md) | both rows closed; the unreachable-check row narrowed to `history-cleanup` |
