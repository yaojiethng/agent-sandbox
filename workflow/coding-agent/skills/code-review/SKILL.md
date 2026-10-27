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

The mechanism that launches a seat is the `dispatch` skill, in the agent's own skill root beside `model-recommendations.md`: it resolves the role to a model, runs one subagent, and records what the attempt ended in.

## When this runs

A change to code needs a judgement its author did not make: a unit before it closes, a branch before it merges, a dispatch whose work is packaged for a rebase. Not for prose or documentation, which `prose-review` answers, and not for a check over the agent's own records, which `doc-maintenance`, `roadmap-maintenance` and `handover-maintenance` answer.

## Translating the runbook's requirements

Almost every review asks for the same few things. Where a runbook states how to satisfy one, the runbook wins; where it is silent, this is how it is done here.

| The runbook asks for | How it is met here |
|---|---|
| a reviewer whose attribution the report carries | the `_REVIEWER` role, resolved by the `dispatch` skill; one assignment per seat, and the caller sets the seat count. A runbook never names a model, a role or a count |
| a scope to read | a commit range or a set of named paths, handed over in the brief. A review reads one revision, so a tree committed or stashed first is what makes a finding attributable |
| a reviewer that leaves the code as it found it | the seat is given the read and inspection tools. Suggestions go in the report and the caller applies them, which is also why a review run refuses a dirty tree |
| a report to collect | one log per seat, written to a file under the session's scratch directory, one directory per review. The log is what a later reader checks, and an empty log means the run did not happen however clean the exit code reads |
| a run that can be repeated | the brief in a file, never a pipe, and every seat's log kept beside it |

A seat that fails on its model stops the run: report the seat and its message rather than reaching for another model by hand. Where a report cannot name its attribution, its scope or its log, the translation is incomplete rather than the review.

## Runbooks

| Runbook | Alias | Accepts |
|---|---|---|
| thermo-nuclear-code-quality-review | thermonuclear-review | a delta: the branch's changes, read as a diff |
| code-review-bash | bash-review | a delta or a named set of shell files |
| code-review-container | container-review | a delta or a named set of files whose subject is an image build |

The slots a runbook fills are [`review_runbook_template.md`](/opt/sandbox/docs/reference/review_runbook_template.md). The code runbooks are read as they stand: they are upstream documents, and this shell is where their requirements become this repository's conventions.

## Not yet accepted

A payload that exists but has not been screened is not a runbook: it names no scope, so there is nothing to dispatch. Each one reaches the table above only by passing `/instruction-cleanup`.

| Payload | Route |
|---|---|
| `.agents/audits/kelsey-code-reviewer.skill.md` | its container half is `code-review-container` and its shell half is the pattern set; what remains unowned is its feedback-style block |
| `.agents/audits/dhh-code-audit.skill.md` | `/instruction-cleanup` |
