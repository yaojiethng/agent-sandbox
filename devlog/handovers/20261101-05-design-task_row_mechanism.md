---
date: 2026-11-01
milestone: M3.5 - Task List Mechanism
type: Design
status: Closed
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
| The convention states three slots - premise, mechanism, end - with a closed vocabulary for the mechanism and the failure each slot prevents | read the amended section; each slot names its failure class | accepted |
| The two rows that carried false claims are rejected by the tests | [`worked table`](../discussions/20261101-study-draft-task_row_form.md#worked-examples), each row failing a named test | accepted |
| The tests are applied to a live row and produce a re-cut | the closure row landed under M3.3.3 as the worked example, with the two cells that declare no reach named in it | accepted |
| The mechanism slot is enforced where a row is accepted, not only where it is written | the convention names the scope gate as the point, and a row that names no class is refused there | accepted |
| An Active handover with completed work cannot carry no acceptance criteria | the handover format gate refuses it, two fixtures pin it, and the rule dates from 2026-11-01 so no closed record is rewritten | accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The mechanism class is scope, not implementation detail | the operator has already excluded classes that satisfy the words; delegating the class delegates a settled decision | this handover |
| Evidence is a command, not a date | a dated claim still cannot be re-run; a command either reproduces the claim or shows it gone | this handover |
| The check binds a row when written or edited, not the backlog | a mass retrofit is a different unit and would make the procedure's own first act a violation of its grain rule | this handover |
| The handover rule dates from 2026-11-01 and rewrites no closed record | the check found one real instance in the live history (`20261025-01`), and retrofitting a criterion into a closed record would invent a criterion the iteration never had | this handover |
| The two sub-milestone metrics moved out of their rows into the acceptance criteria | "the files that may state a destination number one" and "no new expresser" span every row of the group, so no single row could decide them | this handover |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Whether the handover format gate grows the criteria check, or that stays a review rule | acceptance criterion five | amend the existing gate with a fixture; or rule it out and keep the rule in the convention |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Three handovers carry `status: Active` from 2026-10-29 and 2026-10-31 alongside the one this sidequest interrupts | defect | the interrupted iteration was identified by recency and content, not by uniqueness; closing them is their own iterations' work | operator, raised in chat |
| The existing convention rule is followed by a third of open rows and its end clause by under a tenth | measurement | the rule is not weak, it is unenforced; the procedure needs an acceptance point, not another sentence | this handover, Scope |
| The new handover check found one live record with completed work and no criteria: `20261025-01`, which the roadmap already names as the clean case of a record defect | measurement | the check bites on real history; the rule's date keeps the closed record as written | roadmap, M3.5 row |
| Two of the eight manifest cells declare no `reachable` at all, so their files skip the reach check silently | measurement | it is now a roadmap row under M3.3.3 with an end, rather than a sentence in a handover | roadmap, M3.3.3 |

## Completed

| File | One-line change |
|---|---|
| `.agents/skills/task-list/SKILL.md` | the task-granularity rule names the mechanism class, the exclusion, the evidence citation and the scope gate |
| `scripts/lint/handover-format.mjs` | completed work with no acceptance criterion is a finding, dated 2026-11-01 |
| `tests/test_handover_format_gate.sh` | two cases: the rule biting, and a record written before it passing |
| `devlog/roadmap.md` | the M3.3.3 rows carry their mechanism class and one end each; a closure row is added; the two metrics moved to the sub-milestone criteria; two M3.5 rows raised |
| `devlog/discussions/20261101-study-draft-task_row_form.md` | the corpus, the three hypotheses, the six methods and the acceptance numbers, for M3.5 |
| `devlog/handovers/20261101-04-impl-instruction_surface_reach.md` | Findings gains the row naming this sidequest |
