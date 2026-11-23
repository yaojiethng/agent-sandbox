---
name: code-review
description: Run a code review in this sandbox's environment, dispatched to one runbook. Use when an iteration's code needs an independent review before it closes, when a branch's diff must be judged before it merges, or when the operator asks for a code review.
disable-model-invocation: true
---

# code-review

The shell for code reviews: it resolves a review to one runbook, supplies the seat's environment, and hands back the reports. The caller reads this file; a seat reads its brief and its runbook; the operator sees the parameter proposal.

## Project conventions

Read `testing` at `.agents/skills/testing/SKILL.md` when the review touches tests. Skip a missing or stub convention and report the skipped arm; raise only a convention the procedure cannot run without.

## The parameters

A run needs three facts no runbook can know, plus whatever the chosen runbook declares under `Accepts`.

| Fact | Where it comes from |
|---|---|
| what the artifact is for | the operator, or the objective of the handover the change serves |
| who reads it | the named consumer: a later session, the operator, a program |
| the range | the operator's, in whatever form they state it, as `git diff <base>..<head>`; when they name none, the branch point the session started at, `.git/SESSION_STATE`'s `init_sha` |

**Propose, then confirm.** Before any seat, put the parameters in one message: each value with the record it came from, the range default marked as a proposal, and a question for any value you cannot derive. The run starts on the operator's reply. A value filled from your own reading is the assumption this section exists to stop.

## When this runs

A change to code needs a judgement its author did not make: an iteration before it closes, a branch before it merges, or a dispatch packaged for a rebase. Not prose (`prose-review`) or a check over the agent's own records (`doc-maintenance`, `roadmap-maintenance`, `handover-maintenance`).

One dispatch is one pass. A second pass is the invoking task's decision: the review returns its findings, and the owner of the work decides whether to fix and dispatch again. This skill holds no round state, cap or convergence rule.

The churn survey reads [`references/churn.md`](references/churn.md); it dispatches no seat.

## Translating the runbook's requirements

Where a runbook states how to meet one, the runbook wins; otherwise:

| The runbook asks for | How it is met here |
|---|---|
| a reviewer whose attribution the report carries | the `_REVIEWER` role, resolved by the `dispatch` skill; one assignment per seat, and the caller sets the seat count. A runbook never names a model, a role or a count |
| a scope to read | the range `## The parameters` settles. The vendored runbook's "the current branch's changes" is met by it. A review reads one revision, so commit or stash first |
| a reviewer that leaves the code as it found it | the seat is given the read and inspection tools. Suggestions go in the report and the caller applies them, which is also why a review run refuses a dirty tree |
| a report to collect | one log per seat under `.scratchpad/review/<slug>/`; an empty log means the run did not happen. Keep the brief and every log in files, never a pipe |

A seat that fails on its model stops the run; report the seat and its message. A report missing its attribution, scope or log means the translation is incomplete.

## Runbooks

| Runbook | Alias | Accepts |
|---|---|---|
| thermo-nuclear-code-quality-review | thermonuclear-review | a delta: the branch's changes, read as a diff |
| code-review-bash | bash-review | a delta or a named set of shell files |
| code-review-container | container-review | a delta or a named set of files whose subject is an image build |
| novel-bug-hunter | bug-hunter | a component and its contract record |
| test-review | test-review | a delta: the tests in a range, or a named set of test files |

The runbooks live in `runbooks/` beside this file, one directory each, with a `patterns/` directory beside any runbook whose findings cite entries. A new runbook is written from [`references/authoring.md`](references/authoring.md).
