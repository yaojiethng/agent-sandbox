---
date: 2026-11-20
milestone: M3.3.7 - The principle corpus admission
type: Plan
status: Closed
---

# Handover - The M3.3.6 and M3.3.7 task lists are deconflicted

## Objective

Leave one owner for every open row across M3.3.6 and M3.3.7, so a reader of either sub-milestone finds the work that sub-milestone does and nothing the other one has already done.

## Problem

M3.3.6 owns the map, the budget and the record layer. M3.3.7 owns how a principle enters or changes. The principle work has since landed under M3.3.7, the record layer among it, while M3.3.6's objective still claims a record the corpus can check. The instruction surface has also moved under M3.3.6's open rows: the behavioural sweep the map's list calls unmeasured has been run, and the correction count one row rests on does not survive a re-measure.

Raised by the operator on 2026-11-20, with three directions:

- the principle inventory is not the feature or workflow map, so its ownership is the question rather than a fact of the file;
- the `unit` sweeps are one row with subitems, not separate rows;
- the behavioural `principle-*` family was swept, but as part of the inventory pass, which is a different treatment from the one its row describes.

## Scope

Two sub-milestones' open rows, their objectives and their `Sequencing:` lines, and the summary table's status cells where a change lands. The rows themselves are re-homed, merged, closed or re-evidenced rather than rewritten as work.

Out of scope: doing any row's work, the closed rows' narrative, and any sub-milestone outside these two.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every open row has one owner | each row appears in exactly one sub-milestone; a reader finds it by its subject | Agent [x] |
| No open row asserts state the tree contradicts | each row's claim is checked against the tree at the close, and a contradiction either closes the row or rewrites its evidence | Agent [x] |
| The `unit` sweeps are one row with subitems | `grep -c 'unit'` finds one row header carrying both senses | Agent [x] |
| Each objective names only the work its rows hold | the two objectives and `Sequencing:` lines are read against the open lists | Agent [x] |
| The plan is confirmed before any row changes | the operator confirms the boundary rule and the write-back target | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The session grain is milestone scope | the subject is two sub-milestones' lists and the boundary between them, not one task's decisions | this handover |
| The boundary is the subject of the row: a principle or the principle corpus is M3.3.7's, and the map, the statecharts, the budget, the census and the layer/taxonomy work are M3.3.6's | Operator ruling. It resolves the overlap in the two objectives, since M3.3.6's record-layer promise is principle work and M3.3.7's scope sentence already claims it | this handover |
| A stale M3.3.6 row is moved or dropped, never closed with a pointer | Operator ruling: a `[x]` naming a landing that happened in the other sub-milestone makes the list read as work M3.3.6 did, which is the defect the session removes | this handover |
| The four instruction-defect row is dropped | Operator ruling, after the counter-question. The taxonomy was a diagnostic device, the diagnosis landed as the five `## Instruction Surface` rules, and the classes carry no other carrier: no script, no gate, no skill, and not even the census record that prompted them. Its one external label is a correction count that name-matching cannot measure | this handover |
| The `unit` rows merge into one row with two subitems | Operator direction: one word with two halves, where two top-level rows each named half | this handover |
| The census row's counts are dated rather than re-measured | The numbers are that record's measure of a surface that has moved twice since, and a gate may not hold them until the corpus is measured again | this handover |
| The session is recorded under M3.3.7, not M3.3.6 | the work is M3.3.7's: the operator wants a clean list before that milestone closes, and the summary table keeps M3.3.6 as its own subject | this handover |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| How a stale row whose evidence is falsified is treated: dropped whole, or kept with its falsified class removed | the four instruction-defect row's write-back | drop it, or rewrite it to the three classes the measurement supports |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| M3.3.6's objective claims "a record the corpus can check" while the neighbour field, its gate and the inventory lever all landed under M3.3.7 | Evidence | The two objectives overlap on the record layer, so the same work reads as open in one list and closed in the other | the boundary decision |
| M3.3.6 carries three rows whose subject is a principle: the behavioural sweep, a principle stating a pointer's wording, and the references to the organizational judgement | Evidence | Principle work sits in the map sub-milestone | re-home or close |
| The behavioural `principle-*` sweep is marked unmeasured while the inventory lever reports 28 principles and 0 findings | Evidence | A reader budgets work the tree shows landed | close with its landing named |
| The four instruction-defect row rests on "154 correction turns across 550 sessions", and a re-measure of this repository finds 148 name matches over 11,102 operator turns, most of them the operator reasoning rather than a correction | Evidence | The row's baseline is a different instrument's count, so its detector cannot be validated against it | re-evidencing or rewrite |
| The census row's baseline, "assembled context 26,892 to 46,173 chars", predates the surface changes of M3.3.6 and M3.3.7 | Evidence | A gate built on it would hold a stale baseline | re-measure before the gate |
| The instruction-defect taxonomy carries no carrier but the roadmap row and four handovers. | Evidence | A diagnosis that leaves no rule behind is a discussion rather than a standing task; the surface's five rules are what it produced. Raised by the operator's counter-question. | Row dropped; the diagnosis stays with its record. |
| M3.3.7 keeps seven open rows after the pass, one of them a parent with two subitems. | Record | The list a reader now meets is the milestone's own work, and the close is the operator's call. | The close decision. |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../../roadmap.md) | The four rows leave M3.3.6, three landing in M3.3.7; the `unit` pair becomes one row with two subitems; M3.3.6's objective and `Sequencing:` line drop the record layer; the census counts are dated. |
| [`20261120-04-plan-milestone_deconfliction.md`](20261120-04-plan-milestone_deconfliction.md) | The session record: goal, problem, gathered evidence, and the pending boundary decision. |
