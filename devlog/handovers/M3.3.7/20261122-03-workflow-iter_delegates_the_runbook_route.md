---
date: 2026-11-22
milestone: M3.3.7 - The principle corpus admission
type: Workflow
status: Closed
---

# Handover - the design step delegates the runbook route

## Objective

Reach a principle change from the design step through the index that names its runbook, so the runbook stops claiming a caller that never reads it and no runbook name lands in the prompt.

## Scope

`workflow/coding-agent/prompts/iter.md` Step 3, and the M3.3.7 acceptance criterion *The principle corpus has one home for a change, with a named caller, and the procedures it subsumes are retired*: this iteration supplies the named caller. The retirement half of that criterion is not touched here, because the milestone close judges it. The runbook's own caller line stays as it is; see Decisions.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The design step reaches an instruction or principle change without naming a runbook. | Read Step 3. | Agent [x] |
| No runbook name is left in the prompt. | `grep -c principle-change workflow/coding-agent/prompts/iter.md` returns `0`. | Agent [x] |
| The route the step names is one an agent can follow: the index states, per artifact, which runbook opens. | Read the `Open when` column of `instruction-authoring`'s table against the artifact the step names. | Agent [x] |
| The record and lint gates hold. | `check_handover_format.sh`, `check_record_citations.sh`, `check_record_lifecycle.sh`, `check_record_names.sh`, `lint.sh`, `run_tests.sh`. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The design step delegates to the index instead of naming the runbook. | Naming `principle-change.md` in `/iter` would grow the prompt with every runbook written, and the index already maps an artifact to its runbook, so a new runbook registers there and no prompt moves. The operator chose this over completing the enumeration in place and over leaving the prompt untouched. | [`iter.md`](../../../workflow/coding-agent/prompts/iter.md) Step 3; this record. |
| The runbook's caller line is unchanged. | With the route in place the claim holds transitively, and restating the route in the runbook would make it a second source for the same rule. | [`principle-change.md`](../../../.agents/skills/instruction-authoring/runbooks/principle-change.md); this record. |
| No roadmap row is filed for the route. | The milestone acceptance criterion already states the named caller, so a row would restate a criterion the close marks. | This record; the roadmap. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `principle-change.md` names `/iter` as its caller, and `iter.md`'s design step named `task-list` and `decision-records` and nothing for an instruction, so the claim was unreachable from the step it named. | Routing | The step now names the artifact and the index names the runbook. | [`iter.md`](../../../workflow/coding-agent/prompts/iter.md); this record. |
| The same sentence had already grown once per artifact type this milestone, at `task-list` and `decision-records`. | Design | The delegation is the last line the sentence takes for a new artifact; a further runbook registers in the index only. | This record. |

## Completed

| File | One-line change summary |
|---|---|
| [`workflow/coding-agent/prompts/iter.md`](../../../workflow/coding-agent/prompts/iter.md) | Step 3 routes an instruction or principle change through the `Open when` column of the `instruction-authoring` table instead of naming a runbook. |
| [`20261122-03-workflow-iter_delegates_the_runbook_route.md`](20261122-03-workflow-iter_delegates_the_runbook_route.md) | This record. |
