---
status: settled
date: 2026-10-23
---

# Design - The prompt command-surface pass

**Status:** settled

## Context

Last iteration removed four citations of a draft from two shipped prompts and left the references that are not stale but repeated. The question this record answers is what makes a reference redundant, so the pass is a judgement applied per reference rather than a tidy-up by feel.

The two prompts are read against the corpora the pi provider ships: the `principle-*` set and the `communication-principle-*` set, both under `src/reasoning/providers/pi/config/agent/skills/`.

## Method

One pass per file. Every command-shaped reference -- a backticked command, a prompt filename, a convention, a document -- takes three questions, in this order:

1. **Does a step act on it?** A reference a reader needs at the step they are running is kept, even if it repeats something stated earlier.
2. **Does it state a fact the file states again?** A fact stated twice is one statement and one copy; the copy goes, and the surviving statement is the one nearer the step that needs it.
3. **Can the reader open it?** A reference to a file the reader cannot reach from the shipped prompt is named, not linked, per `communication-principle-link-what-the-reader-can-open`.

A citation that carries a fact the citing file also states is not a citation: the fact stays where it is applied and the pointer goes, per `communication-principle-show-dont-describe`.

## The redundancy classes

The two files were read whole before the pass, and the repeated surface falls into five classes. The class decides which judgement applies, so the census below records a class per row rather than a taste.

| Class | What it is | The judgement |
|---|---|---|
| Second channel | a fact the file states in two or more places | `communication-principle-cut-what-carries-nothing` |
| Route where a statement is needed | a pointer to a file for a fact the reader must act on here | `communication-principle-show-dont-describe` |
| Two names for one thing | one command spelled two ways, so a search finds one | `communication-principle-align-the-mental-model` |
| Restatement that is a check | a rule stated in the body and again in the failure modes | kept: the second statement is the check |
| Filler | a sentence that would be true of any prompt | `communication-principle-cut-what-carries-nothing` |

## Decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | `## Called from` is kept as the single declaration of who invokes `/wrapup`, and `## Scope` stops enumerating the callers | The dispatch edges in `docs/reference/workflow_statechart.md` were read from that table, so it is the declaration site; a second enumeration in Scope is the copy |
| D2 | One channel per fact: a definition once in `## Scope`, a check once in `## Failure modes`, and neither restated in `## Purpose` or `## Non-goals` | Four statements of "triage changes nothing" is four things to keep true, and only two of them do work |
| D3 | A non-goal keeps its boundary and drops the owner clause where the routing list already names the owner | The boundary is the non-goal's job; the owner is routing's |
| D4 | Every command is named in one form: slash-prefixed, matching its prompt filename | A reader searching for `/milestone-start` does not find `milestone-start`, and the statechart's command table uses the slash form |
| D5 | A close step's citation of an invariant keeps the link and drops any restatement of the boundary stated in `## Scope` | The invariant is the authority; the boundary is stated once, at the top |

## Rejected

| # | Option | Why not |
|---|---|---|
| R1 | Cut `## Called from` as a duplicate of the statechart | Backwards: the chart's edges are read from that table. Removing it makes the chart unmaintainable |
| R2 | Add the mechanical check that a cited command resolves to a file, in this unit | A lint gate with its own tests is a unit of its own; filing it separately keeps this iteration to prose |
| R3 | Rewrite the prompts whole, from the corpora | The pass is per reference. A rewrite loses the load-bearing sentences with the redundant ones, and the census can no longer say what changed and why |

## Decisions taken during the pass

The pass met a live defect in the file it was cutting: `wrapup.md` consumed a record-check report that no step on every caller's path dispatched, and the run it consumed read the tree before the close wrote its rows. Three decisions settle it.

| # | Decision | Rationale |
|---|---|---|
| D6 | `wrapup.md` dispatches both record checks itself, in a new B9 after the steps that write records | The report has to cover what the close wrote, and the close is invoked by three prompts, only one of which produced a report. A runbook that consumes evidence dispatches the producer, per `principle-check-placement` |
| D7 | The gate keeps its run, and the close adds a second: two runs over two different trees | The gate's run presents the tree as the iteration leaves it and feeds the findings queue; the close's run reads rows that run could not see. Naming the second run B9 rather than moving the first keeps both subjects stated |
| D8 | `## Input contract` gains the record-check report as a third input | B4's `late` rule reads it to tell a finding the gate raised from one it missed, so the close owes that input in its contract, per `principle-own-the-scope-you-declare` |
| D9 | The chart gains a `chk_close` state between each released gate and its successor | The close's run is a state the loop rests in, not a footnote: three commands reach it and two leave it, and a story can now route it |

## Dispositions

One row per reference, written as the pass runs: the reference, its class, its disposition, and the judgement that decided it.

| # | File | Reference | Class | Disposition | Judgement |
|---|---|---|---|---|---|
| 1 | wrapup.md | `/iter`, `/plan` and `/document` in `## Scope` | second channel | cut | `principle-single-source-of-truth` |
| 2 | wrapup.md | the `/commit` ownership list in `## Scope` | second channel | cut, pointer kept | `communication-principle-cut-what-carries-nothing` |
| 3 | wrapup.md | three negative clauses on `/milestone-close` and `/milestone-start` | second channel | cut to one bound with pointers | `principle-own-the-scope-you-declare` |
| 4 | wrapup.md | `milestone-start` in `## Called from` | two names | slash form | `communication-principle-align-the-mental-model` |
| 5 | wrapup.md | the fold rule, stated twice in `## Mandate` | second channel | cut to one statement plus its citation | `communication-principle-cut-what-carries-nothing` |
| 6 | wrapup.md | `/commit` named in `## Mandate` | route where a statement is needed | kept as the handoff pointer | `principle-single-source-of-truth` |
| 7 | wrapup.md | `## Input contract` omitting the record-check report | second channel (a missing input) | row added | `principle-own-the-scope-you-declare` |
| 8 | wrapup.md | "one release" stated twice in the Part B intro | second channel | cut to one | `communication-principle-cut-what-carries-nothing` |
| 9 | wrapup.md | the note on how steps cite their invariant | filler | cut, replaced by a pointer sentence | `communication-principle-write-for-the-reader` |
| 10 | wrapup.md | the milestone-grain boundary restated in B4 | second channel | cut, kept in `## Scope` | `communication-principle-keep-a-subject-near` |
| 11 | wrapup.md | the task-list marking invariant restated in B4 | second channel | one citation | `principle-single-source-of-truth` |
| 12 | wrapup.md | "The step is mandatory; its value may be None." | second channel | cut | `communication-principle-cut-what-carries-nothing` |
| 13 | wrapup.md | the `late` rule in B4, B6 and B8 | second channel | stated in B4, cited from B6 and B8 | `communication-principle-keep-a-subject-near` |
| 14 | wrapup.md | no step dispatching either record check | route where a statement is needed | new B9 dispatches both | `principle-check-placement` |
| 15 | wrapup.md | the check running before the write-back it validates | second channel (evidence that cannot exist yet) | B9 placed after B4, B6 and B8 | `principle-check-placement` |
| 16 | wrapup.md | the "why the split" bullet in the handoff | filler (a rebuttal of an earlier version) | cut | `communication-principle-write-for-the-reader` |
| 17 | wrapup.md | the handoff four moves: the next prompt, what it owns, what stays, where this stops | route where a statement is needed | kept whole | `communication-principle-hand-off-by-naming-the-boundary` |
| 18 | wrapup.md | "advisory context, not a task list" in B10 | second channel | cut | `principle-single-source-of-truth` |
| 19 | wrapup.md | the `/commit` ownership list repeated in a failure mode | second channel | trimmed to the owner name | `communication-principle-cut-what-carries-nothing` |
| 20 | wrapup.md | "The write-back lands as its own commit" in `## Failure modes` | restatement that is a check | kept | `communication-principle-cut-what-carries-nothing` |
| 21 | wrapup.md | the `## Failure modes` row for a missed B9 finding | new | added | `principle-say-what-done-looks-like` |
| 22 | wrapup.md | the caller list in the frontmatter description | route where a statement is needed | kept: the signpost an agent matches | `principle-skill-signposting` |
| 23 | backlog-triage.md | "not a plan, a dispatch, or a survey" in `## Purpose` | second channel | cut | `communication-principle-cut-what-carries-nothing` |
| 24 | backlog-triage.md | "the answer is the same question each time" | filler | cut | `communication-principle-cut-what-carries-nothing` |
| 25 | backlog-triage.md | "M4 owns the dispatcher that will" in the routing list | forecast | cut | `communication-principle-dont-forecast-undone-work` |
| 26 | backlog-triage.md | "triage is its precursor ... would answer" | forecast | cut | `communication-principle-dont-forecast-undone-work` |
| 27 | backlog-triage.md | the M4 `/auto` milestone in the routing list | route where a statement is needed | kept as the one mention | `principle-single-source-of-truth` |
| 28 | backlog-triage.md | `gm.md` in the routing list | route where a statement is needed | kept as the one mention | `principle-single-source-of-truth` |
| 29 | backlog-triage.md | the `gm.md` owner clause under `## Non-goals` | second channel | owner dropped, boundary kept | `communication-principle-cut-what-carries-nothing` |
| 30 | backlog-triage.md | the `/auto` owner clause under `## Non-goals` | second channel | owner dropped, boundary kept | `communication-principle-cut-what-carries-nothing` |
| 31 | backlog-triage.md | "the M4 dispatcher will" under `## Non-goals` | forecast | cut, the gap kept | `communication-principle-dont-forecast-undone-work` |
| 32 | backlog-triage.md | "Editing any record. A stale row becomes a finding" | second channel | cut; `## Scope` and Step 5 carry it | `communication-principle-cut-what-carries-nothing` |
| 33 | backlog-triage.md | "Answering a question the operator owns. Triage surfaces it once" | second channel | cut; Step 3 and the failure modes carry it | `communication-principle-cut-what-carries-nothing` |
| 34 | backlog-triage.md | "Triage changes nothing" in the failure modes | restatement that is a check | kept | `communication-principle-cut-what-carries-nothing` |
| 35 | backlog-triage.md | the no-write boundary in `## Scope` | route where a statement is needed | kept as the one definition | `principle-own-the-scope-you-declare` |
| 36 | backlog-triage.md | the commit-type list at `git-discipline/references/commit-types.md` | route where a statement is needed | kept: the reader needs the list at Step 2 | `communication-principle-show-dont-describe` |
| 37 | backlog-triage.md | the unit rule at `iteration_protocol.md` | route where a statement is needed | kept: cited, not restated | `principle-single-source-of-truth` |
| 38 | backlog-triage.md | the four-verdict vocabulary at Step 5 | none: a definition the table uses | kept | `principle-define-terminology-before-use` |
