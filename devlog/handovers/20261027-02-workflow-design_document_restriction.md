---
date: 2026-10-27
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - Relaxing the design-document restriction in `/iter`

## Objective

Make the iteration's demand for a design document match the record type that owns it, so that a design record is opened when the decision has more than one live option or must outlive the iteration, and a decision made and recorded inside one iteration stays in that handover.

## Scope

Continues the interrupted iteration [`20261027-01-workflow-agents_layer_ownership.md`](20261027-01-workflow-agents_layer_ownership.md), whose scope gate is unreleased; that iteration rules the two `AGENTS.md` layers and does not own `iter.md`.

The instruction to relax is `workflow/coding-agent/prompts/iter.md` Step 3, whose skip clause is unreachable: it requires the roadmap row to already carry resolved decisions with recorded rationale, and a fresh row never does. The convention that owns the record type already states the narrower criterion, in `.agents/skills/work-log/SKILL.md`: a `design` opens when "the iteration's design phase resolves trade-offs between options". The prompt and the convention disagree and the prompt is what runs.

Out of scope: the four instruction-defect classes and their detectors, the census-budget gate, and the `AGENTS.md` layer rulings, all of which belong to the interrupted iteration or to their own rows. Also out of scope, and ruled so rather than deferred: deleting or rewriting the design records that already exist, and correcting the thirteen that carry no `status:` line, because those records predate this sidequest and a repair pass over them is a unit of its own.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Step 3 records decisions in the handover by default and opens a design document only on operator direction | both phrases found once in Step 3 | Agent [x] -- 1 and 1 |
| Step 3 states the conditions under which the agent suggests a design document, as a list | four bullets between the Step 3 and Step 4 headings | Agent [x] -- 4 |
| The unreachable skip is gone, and the step no longer mandates a record | the skip phrase occurs zero times in `iter.md` | Agent [x] -- 0 |
| The step agrees with the convention that owns the record: `work-log` defines the type, and Step 3 no longer requires one | the convention row and Step 3 read side by side | Agent [x] |
| Step 3 orders the grain, then the work, then the records, and carries any suggestion to the scope gate | the step reads grain, requirements, routing, exit; the suggestion appears in the exit condition | Agent [x] |
| Every decision this sidequest records is realized in the files | each Decisions row maps to a line of Step 3 | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Decisions are recorded in the handover's `## Decisions` table by default; a design document is opened only on operator direction | the handover is what the next iteration reads, and the agent is not the party that decides whether a separate record is owed | this handover; Step 3 of `iter.md` |
| The agent suggests a design document on four stated conditions and does not open one | a list the agent can evaluate keeps a real design question from being suppressed, while leaving the decision with the operator | this handover; Step 3 of `iter.md` |
| No new section is added to `iter.md`; Step 3's existing paragraph is replaced | the step is already the right place, and an added section would grow the layer the loop prompt reads | this handover |
| The step reads grain, then work, then records, and the suggestion is carried to the scope gate | a reader meets the record rule before the work only if it is written first, which is how the skip being replaced had read; the gate is the one moment the operator can direct | this handover; Step 3 of `iter.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The design-document rule entered `iter.md` by migration, not decision: `12dba54e` (handover `20260928-07`) copied it from the retired `iteration_policy.md` minor-loop table, whose Step 3 carried the major loop's sub-milestone condition ("resolve any deferred story that depends on this sub-milestone"); `3a2890c7` reformatted it; no ADR records it | finding | the grain of a milestone-grain instrument was applied to every iteration | this sidequest |
| The minor-loop row already held the unreachable skip before the migration, so the defect predates `iter.md` and the migration faithfully copied it | finding | correcting only the prompt leaves the retired policy's wording unexamined, and no live carrier holds it | this sidequest's acceptance criterion 1 |
| The first draft of the rule put both a criterion and a default on the agent; the operator corrected it mid-sidequest to operator direction plus a suggestion list | steering | the agent decides neither whether a record is owed nor what counts as a live option, which is the judgement the unreachable skip had also hidden | amended before the release gate, Steps 3 and AC 1-2 re-verified |
| The first ordering put the record rule ahead of the design work and left the suggestion undated, which re-read as the inverted default the sidequest exists to remove | defect | a step whose first sentence is about paperwork reads as permission to skip the work | fixed before the release gate; the ordering is now an acceptance row |
| Nineteen design records exist since 2026-10-14 and thirteen carry no `status:` line | defect | they cannot be settled by the convention that governs them | roadmap row already filed under M3.2.2 |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../roadmap.md) | the row filed under M3.2.2 is closed with its landing note |
| [`devlog/handovers/20261027-01-workflow-agents_layer_ownership.md`](20261027-01-workflow-agents_layer_ownership.md) | a Findings row naming this sidequest and its reason |
| [`workflow/coding-agent/prompts/iter.md`](../workflow/coding-agent/prompts/iter.md) | Step 3: the unreachable skip is replaced by the two-condition criterion, and an inside-iteration decision routes to the handover |
