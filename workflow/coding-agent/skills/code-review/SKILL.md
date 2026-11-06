---
name: code-review
description: Run a code review in this sandbox's environment, dispatched to one runbook. Use when a unit's code needs an independent review before it closes, when a branch's diff must be judged before it merges, or when the operator asks for a code review.
disable-model-invocation: true
---

# code-review

The shell for code reviews. It translates what a runbook asks for into this environment: which skills and tools a seat has, how a role resolves to a model, where the brief and the reports live. It names which runbooks this family accepts, and it sets no format of its own. The runbook's requirements are the target; this file is a guide to meeting them here.

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `testing` - the suite's conventions, worth reading when the review touches tests.

## Purpose

Resolve a code review to one runbook, translate its requirements into this environment, and hand back the reports. What the reviewer judges is the runbook's; how the reviewer is given the material is this file's.

## The reading path

Three readers, three layers. The caller reads this file, which carries the parameters and the loop. A seat reads its brief, then one runbook. The operator reads the parameter proposal and nothing else.

| Reader | Reads | Never reads |
|---|---|---|
| caller | this file | the runbook |
| seat | the brief, its runbook | this file, the loop |
| operator | the proposal | any file |

## The parameters

A run needs two facts no runbook can know, plus whatever the chosen runbook declares under `Accepts`.

| Fact | Where it comes from |
|---|---|
| what the artifact is for | the operator, or the objective of the handover the change serves |
| who reads it | the named consumer: a later session, the operator, a program |
| the range | the operator's, in whatever form they state it, as `git diff <base>..<head>`; when they name none, the branch point the session started at, `.git/SESSION_STATE`'s `init_sha` |

**Propose, then confirm.** Before any seat, put the parameters in one message: each value with the record it came from, the range default marked as a proposal, and a question for any value you cannot derive. The run starts on the operator's reply. A value filled from your own reading is the assumption this section exists to stop.

## The loop

Every review is one loop over one range. It runs on a state file rather than on memory, because the caller's context is compacted and the file is not: one record per round, appended under `.scratchpad/review/<slug>/state.md`.

```text
round: 1
range: <base>..<head>      purpose: <one line>      consumer: <one line>
blockers:
  - R1-1
    wrong answer: <what the code does that is wrong>
    consumer cost: <who feels it, and how>
    fix: <the change>        status: applied | deferred
verdict: BLOCK | ACCEPT
```

| State | Condition | Next |
|---|---|---|
| init | the parameters confirmed by the operator | round 1 |
| round n | at least one open blocker, both fields filled | fix, then round n+1 |
| round n | no open blocker | `ACCEPT`, stop |
| round n | one blocker unchanged by its fix round, twice | stop; ask the operator |

A blocker that cannot fill both fields is a note in the report and costs no round. A round that finds no such blocker accepts, however much a runbook invites another. The seat returns the round's blockers; the caller writes the record, applies the fix, and reads the next state.

The mechanism that launches a seat is the `dispatch` skill, in the agent's own skill root beside `model-recommendations.md`: it resolves the role to a model, runs one subagent, and records what the attempt ended in.

## When this runs

A change to code needs a judgement its author did not make: a unit before it closes, a branch before it merges, a dispatch whose work is packaged for a rebase. Not for prose or documentation, which `prose-review` answers, and not for a check over the agent's own records, which `doc-maintenance`, `roadmap-maintenance` and `handover-maintenance` answer.

A run to convergence is the loop below. A maintenance run that ranks where the tree moves reads [`references/churn.md`](references/churn.md): it dispatches no seat, because the working agent runs it over its own records.

## Translating the runbook's requirements

Almost every review asks for the same few things. Where a runbook states how to satisfy one, the runbook wins; where it is silent, this is how it is done here.

| The runbook asks for | How it is met here |
|---|---|
| a reviewer whose attribution the report carries | the `_REVIEWER` role, resolved by the `dispatch` skill; one assignment per seat, and the caller sets the seat count. A runbook never names a model, a role or a count |
| a scope to read | the range `## The parameters` settles. The vendored runbook's "the current branch's changes" is met by it: the phrase names which changes, and that section names where they begin. A review reads one revision, so a tree committed or stashed first is what makes a finding attributable |
| a reviewer that leaves the code as it found it | the seat is given the read and inspection tools. Suggestions go in the report and the caller applies them, which is also why a review run refuses a dirty tree |
| a report to collect | one log per seat, written to a file under the session's scratch directory, one directory per review. The log is what a later reader checks, and an empty log means the run did not happen however clean the exit code reads |
| a run that stops | `## The loop` |
| a run that can be repeated | the brief in a file, never a pipe, and every seat's log kept beside it |

A seat that fails on its model stops the run: report the seat and its message rather than reaching for another model by hand. Where a report cannot name its attribution, its scope or its log, the translation is incomplete rather than the review.

## Runbooks

| Runbook | Alias | Accepts |
|---|---|---|
| thermo-nuclear-code-quality-review | thermonuclear-review | a delta: the branch's changes, read as a diff |
| code-review-bash | bash-review | a delta or a named set of shell files |
| code-review-container | container-review | a delta or a named set of files whose subject is an image build |
| novel-bug-hunter | bug-hunter | a component and its contract record |
| test-review | test-review | a delta: the tests in a range, or a named set of test files |

The runbooks live in `runbooks/` beside this file, one directory each, with a `patterns/` directory beside any runbook whose findings cite entries. A new runbook is written from [`references/authoring.md`](references/authoring.md). The code runbooks are read as they stand: they are upstream documents, and this shell is where their requirements become this repository's conventions.
