---
description: Triage prompt. Sort the open roadmap backlog into the rows an autonomous run can dispatch and the rows it cannot, naming the question that parks each one. Use when the operator asks which tasks are completable without them, before an unattended run, or when a cheap model is about to be pointed at the backlog.
argument-hint: "[scope - a milestone ID, a task group, or empty for the whole open backlog - optional]"
---

> $@

# Backlog Triage - Run (Main-Agent Template)

**Scope:** classify the open roadmap rows named by the argument, or the whole open backlog when the argument is empty, into the rows an autonomous run can dispatch and the rows it cannot. Classification only: this prompt reads records and returns a table. It opens no iteration, edits no record, and dispatches nothing.

## Purpose

An autonomous run spends the operator's goodwill. Every unit it dispatches consumes a subagent context and a commit, and a unit dispatched on a row that turned out to need a decision returns a question the operator must answer before the run can continue. Triage moves that question to the front, where the operator can answer it once, before any context is spent.

The output is one table with a verdict per row. The verdict is the work: which rows run unattended, and the single question that parks each of the rest.

This prompt is not a plan, a dispatch, or a survey. It does not sequence the runnable rows, open handovers, or write records.

## When to run this way

Run this when the operator asks which work can proceed without them, before releasing an unattended run, or before pointing a large or cheap model at the backlog. The answer is the same question each time, and it is cheap to answer from the records that already exist.

Routing:

- A specific multi-unit plan the operator has already released is [`sequential-work.md`](sequential-work.md). That prompt applies the same well-specifiedness test to the units it was handed; triage is how the rows got selected.
- A situational check-in that surveys the whole project and recommends a starting task is [`gm.md`](gm.md). Triage answers the narrower question of what runs unattended, and does not survey handovers, stashes, or git state.
- The generalized dispatcher that resolves execution order and picks a dispatch shape is [`auto.md`](auto.md), reserved for M4. Triage is its precursor: it answers the per-row question that dispatcher would answer across a whole plan.

## Step 1 - Build the candidate set

Read [`devlog/roadmap.md`](../../../devlog/roadmap.md). Take the `active-milestone` frontmatter field and that milestone's section when the argument is empty; take the named milestone or task group when the argument names one. Also read [`devlog/roadmap_future.md`](../../../devlog/roadmap_future.md) for rows that name a destination in a future milestone, so a row is not classified as absent merely because its milestone is not active.

One candidate per open row. A row is open when its checkbox is unchecked. Record for each: the row text, the milestone it sits under, and any sibling text on the same line or in the same bullet that narrows it.

**Done when:** every open row in the named scope is on the candidate list, and each carries its milestone and its text.

## Step 2 - Apply the well-specifiedness test

Apply the test from [`sequential-work.md`](sequential-work.md) Step 1 to every candidate. The test is: a row is runnable only when a scope confirmation would raise no open question. The design or spec is clear, the acceptance criteria are clear, and nothing is left to decide.

Write the answer sheet per row before judging it. The sheet has four lines: the type, what is in scope, what is deferred, and the acceptance criteria with their checks. Read the sheet back. Any line that would be a question parks the row, and the line is the question.

Use the commit types from [`git_policy.md`](../../../docs/operations/git_policy.md) Active Types for the type line, so the table sorts the way the commits will. The types the operator usually asks to see split are: `feat`, `fix`, `test`, `docs`, `chore`, `refactor`, `workflow`, `build`, and `plan`.

Two rows that cannot be separated by the records alone are one row. Merge them and say so in the verdict, rather than guessing where the boundary falls.

**Done when:** every candidate has a sheet, and every sheet has been read back and judged runnable or parked.

## Step 3 - Resolve a parked row to its question

A parked row is not a verdict. Each one gets the single question that parks it, in the operator's terms, and the two or three options that would answer it. "Needs design" is not a question. "Which of the three sources is authoritative for the session identity, the compose project name, or the container label?" is.

Where the records already answer the question, the row is not parked. A decision recorded in a handover's Decisions table, an ADR, a settled discussion, or a feedback entry counts as answered; cite the record in the sheet and judge the row on the answer.

Where the row is parked on a decision the operator already made but the agent has not seen, cite the record rather than parking it. Re-reading the records is cheaper than a question.

**Done when:** every parked row has one question, its options, and the records that were checked before parking it.

## Step 4 - Check each runnable row against the run's own rules

A row can pass the well-specifiedness test and still fail as a unit. Apply the unit rule from [`iteration_policy.md`](../../../docs/operations/iteration_policy.md): one commit, one context, one verification, disjoint files.

- A row that fails one commit is over-scoped. Park it with the question of which slice comes first.
- A row that needs two contexts splits, and each half is its own candidate. Present the split as two rows.
- A row whose acceptance needs another row to land first is not runnable yet. Name the row it waits on.

Two runnable rows that own the same file are one unit. Merge them.

**Done when:** every runnable row passes the unit rule, or has been split or merged into rows that do.

## Step 5 - Present the table

Return one row per candidate. The sample row is illustrative, not a live item:

| Row | Type | Verdict | Question or check |
|---|---|---|---|
| `<roadmap row text>` | `fix` | runnable | `make test` covers it; no sibling row owns the file |

Verdict is one of four values:

- **runnable** -- passes the well-specifiedness test and the unit rule. Dispatch it unattended.
- **needs design** -- the shape is not settled. The question is what the design must decide.
- **needs operator decision** -- a choice only the operator can make. The question names the options.
- **stale** -- the work landed, or the row names something that no longer exists. Say which record shows it. A stale row is a record-bug finding, not a unit.

Order the rows: runnable first, then the parked ones grouped by question, so the operator can answer a group in one reply. Follow the table with the count of runnable rows and the number of distinct questions among the parked ones. That count is the operator's real workload and is usually the number they want.

Then recommend the next row to dispatch, if the argument or the run's shape points at one, and name which rows must land first. Stop. Do not open a handover and do not dispatch.

## Non-goals

- Sequencing the runnable rows into a run plan. [`sequential-work.md`](sequential-work.md) owns the order and the unit split of a released plan.
- Surveying the project for work that is not on the roadmap. [`gm.md`](gm.md) owns the situational survey.
- Choosing a dispatch shape, or resolving execution order across a dependency graph. [`auto.md`](auto.md) owns that, from M4.
- Editing any record. A stale row becomes a finding; the record is fixed in an iteration.
- Answering a question the operator owns. Triage surfaces it once, in a form that can be answered in a reply.

## Failure modes and invariants

- **The table is a verdict on every candidate, not a shortlist.** A row absent from the table is a row the operator believes was assessed and was not. A row the records cannot classify is present with verdict `needs design` and a question naming what is missing from the records.
- **Every parked row carries one question.** A parked row without a question is a refusal, and it sends the operator back to the records to find the question the agent should have found.
- **No verdict is inferred from a row's position.** A row at the top of a milestone is not better specified than one at the bottom. Judge from the row's own text and the records it cites.
- **A merge is stated, never silent.** When two rows merge, the table shows one row and names both source rows.
- **Triage changes nothing.** No file is edited, no record is written, no handover is opened. The table is the entire output.
