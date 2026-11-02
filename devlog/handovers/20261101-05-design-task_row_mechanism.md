---
date: 2026-11-01
milestone: M3.5 - Task List Mechanism
type: Design
status: Active
---

# Handover - the task row states its mechanism and its evidence

## Objective

Settle how a task row is written, so that a row cannot carry an unevidenced claim or omit the mechanism class the operator has already decided.

## Scope

Continues the open iteration [`20261101-04-impl-instruction_surface_reach.md`](20261101-04-impl-instruction_surface_reach.md) (interrupted at E1, step 2 of 5) on operator direction, because the re-cut of that work's rows cannot be written under the current entry rule. The amended artifact is the `task-list` convention, which M3.5 owns; the rows this sidequest raises land there.

The convention already carries the rule in one clause - "task granularity: identify the file and nature of change" - and the roadmap shows how far it reaches: of 178 open rows, 63 name a nature of change and 15 carry a decidable end, leaving 106 with neither (measured 2026-11-01). So the gap is not a missing rule. It is a rule with an open vocabulary, no evidence requirement, and no enforcement point.

Three failure classes are in scope, because one procedure has to answer all three:

1. **A false premise.** A row states a present-tense diagnosis that was true of a summary and never of the tree, and no reader can re-run it.
2. **An omitted mechanism.** A row states intent and leaves the class open, so an implementation that satisfies every word and contradicts the decision passes review.
3. **The wrong grain.** A row spans two units or carries two ends, so it cannot close on one outcome and it hides a unit inside another row's end sentence.

Ruled out of scope: retrofitting the 178 open rows. The procedure binds a row when it is written or edited, and the existing rows acquire the shape as they are touched. Ruled out also: re-cutting the M3.3.3 rows themselves, which is the interrupted iteration's close, not this unit's.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The convention states three slots - premise, mechanism, end - with a closed vocabulary for the mechanism and the failure each slot prevents | read the amended section; each slot names its failure class | pending |
| The two rows that carried false claims are rejected by the tests | a worked table in this handover, each row failing a named test | pending |
| The tests are applied to a live row and produce a re-cut | the M3.3.3 unit row re-cut as the worked example, without committing that re-cut | pending |
| The mechanism slot is enforced where a row is accepted, not only where it is written | the scope gate names the slot, and the convention says so | pending |
| An Active handover with completed work cannot carry no acceptance criteria | a fixture against the handover format gate, or the ruling that this is out of scope | pending |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The mechanism class is scope, not implementation detail | the operator has already excluded classes that satisfy the words; delegating the class delegates a settled decision | this handover |
| Evidence is a command, not a date | a dated claim still cannot be re-run; a command either reproduces the claim or shows it gone | this handover |
| The check binds a row when written or edited, not the backlog | a mass retrofit is a different unit and would make the procedure's own first act a violation of its grain rule | this handover |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Whether the handover format gate grows the criteria check, or that stays a review rule | acceptance criterion five | amend the existing gate with a fixture; or rule it out and keep the rule in the convention |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Three handovers carry `status: Active` from 2026-10-29 and 2026-10-31 alongside the one this sidequest interrupts | defect | the interrupted iteration was identified by recency and content, not by uniqueness; closing them is their own iterations' work | operator, raised in chat |
| The existing convention rule is followed by a third of open rows and its end clause by under a tenth | measurement | the rule is not weak, it is unenforced; the procedure needs an acceptance point, not another sentence | this handover, Scope |

## Completed

| File | One-line change |
|---|---|
| `devlog/handovers/20261101-04-impl-instruction_surface_reach.md` | Findings gains the row naming this sidequest |
| `devlog/handovers/20261101-05-design-task_row_mechanism.md` | created, with the scope and the criteria |
