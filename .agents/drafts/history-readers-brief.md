# The History's Readers - Brief

**Status:** draft

**Scope:** the situations that make a branch's history need rewriting, the circumstances in which that history is read, and the properties a history serving those readers has. The three land in `.agents/skills/git-discipline/SKILL.md` as the convention's opening, so every rule it keeps can name the reader it serves.

**Origin:** the operator's refinement of the `history-cleanup` ask, 2026-11-14, after the history-as-commons ADR (`docs/adr/git_commit_history_commons.md`) decided the convention leads from the commons intent without stating who the commons is for. It serves roadmap row 755a; row 755b consumes the result.

**Delete when** row 755a closes: the table is in the convention, and the brief has no other reader.

## Premise

A rule that protects no reader is a preference, and a property no circumstance demands is an ornament. If the convention states both the readers and the properties, every rule it keeps becomes checkable against them; if it states neither, a rule can only be defended by taste.

## Start from

The rewriting impulse as it actually happened, and the commands that read history, not a taxonomy of plausible uses.

- The situations: the session logs under `/home/agentuser/.pi/agent/sessions/--home-agentuser-sandbox--/`, `devlog/AGENT_FEEDBACK.md`, and the handovers that record a cleanup (`20261112-07`, the 7-to-4 fold, the reverted solo rewrite that left retraction commits).
- The circumstances: `grep -rn 'git log\|git bisect\|git blame\|git show\|range-diff' scripts/ workflow/ tests/ docs/reference/`, plus the host flow in `docs/reference/change_model.md` and the `prepare` runbook.

## The situations that make us rewrite

Presenting a branch for review is the **trigger**, not a situation: it is the moment the branch is claimed to be presentable. The situations are what the branch holds by then.

| Situation | What the branch then holds |
|---|---|
| a fix lands far from the feature | a correction appended after the unit it corrects |
| tangled patching | one commit touching two unrelated units, or one unit split across three |
| requirements moved | successive implementations of one thing, each honest when written |
| record noise | a discussion doc, handover or write-back added mid-branch and retired before it lands |
| the pile | `wip:` checkpoints that were never folded |
| the retraction | an overstepped change reverted, so the series explains work that did not happen |

## The circumstances in which history is consumed

| Circumstance | The reader's access | The reader's question |
|---|---|---|
| the operator's accept | the chain, the handover, the chat | is this one reviewable series, in order, with nothing inverted? |
| presentation to a peer | the chain and the PR description, nothing else | does the chain explain itself with no transcript behind it? |
| review | the chain, one commit at a time | does each commit tell me one unit, and why? |
| archaeology | `git blame`, `git log -S` / `-G` | where did this line come from, and what did it replace? |
| bisect | `git bisect` | which commit broke it, and does every commit build? |
| the next session | the range, the handover chain | what is the branch's state, without the transcript? |
| the changelog | the record | what shipped, and when did it stop being true? |

## The properties a well-written history has

Each is derived from a circumstance, and where two circumstances disagree the table states the conflict rather than choosing.

| Property | Serves | Note |
|---|---|---|
| ordered, no inversion inside the series | the accept, review | |
| one unit per commit | review, the next session | |
| every commit builds | bisect | **conflicts** with one-delivery-commit-per-iteration: a squashed series is one reviewable unit and an unbisectable one |
| the subject names the change, the body gives the reason | review, archaeology | the subject is imperative; the body carries the why and never restates the diff |
| a line's origin survives a rewrite | archaeology | a rewrite that buries it trades one reader for another |
| no artifact noise | the accept, the changelog | a record created and deleted inside the branch is not history |
| self-contained and scannable | presentation to a peer | the reader's time is the budget the subject length, the one-unit commits and the absence of noise all protect |
| complete at every point | the next session | |

## Method

Read the logs for the situations and cite the record each one names; list the circumstances from the commands the tree runs; derive each property from the circumstance that demands it; state the bisect conflict as a property, not a resolution. The convention opens on the tables, and each rule it already keeps is then checked against a property (row 755b).

## Check

The three tables are in `git-discipline`, each situation carries a record, each property a circumstance, and the bisect conflict is stated. A reviewer re-runs the log grep and finds every situation and circumstance accounted for, with none invented. `bash scripts/lint.sh` passes, and no shipped document links a repository-only path.
