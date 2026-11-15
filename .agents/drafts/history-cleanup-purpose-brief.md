# The `history-cleanup` Purpose - Brief

**Status:** draft

**Scope:** what the `history-cleanup` primitive is for. It states the trigger that starts a cleanup, the situations it converts, and the mapping from each property the convention requires to the check that enforces it, with the gaps named. The primitive cites the convention's reader table rather than restating it.

**Origin:** the operator's question, 2026-11-14, on whether the primitive's purpose can be framed from the cases that read history; refined against the convention's reader table in [`.agents/drafts/history-readers-brief.md`](history-readers-brief.md), which writes that table (row 755a). It serves roadmap row 765.

**Delete when** row 765 closes: the primitive states its purpose and the mapping, and the brief has no other reader.

**Depends on** the history-readers brief: run that first, because this brief cites its tables and a cleanup that invents its own reader set re-creates the second source this milestone removes.

## Premise

Every rule in `history-cleanup` and every check in its audit is justified by a property some reader's circumstance demands; a check no property claims is dead weight, and a property no check enforces is the primitive's gap. The mapping is checkable both ways.

## Start from

- `workflow/coding-agent/skills/history-cleanup/SKILL.md` -- the current procedure, which already cites `git log -G`, `git for-each-ref --contains`, `--show-signature`, `git notes list` and `range-diff`.
- `workflow/coding-agent/skills/history-cleanup/scripts/audit.sh` and `scripts/inversions.mjs` -- the four checks and the inversion detector.
- `workflow/coding-agent/skills/git-discipline/references/prepare.md`, `workflow/coding-agent/prompts/commit.md`, `docs/reference/change_model.md` -- the three other points that read or shape a branch's series.
- `tests/test_history_cleanup_audit.sh`, `tests/test_history_cleanup_detector.sh` -- what the checks are held to today.

## The trigger

A branch is about to be consumed, and its series arose from one of the situations the convention names. The cleanup is the conversion of working state into the contribution the reader receives. Presentation schedules it; the situations justify it.

## The situations as input

| Situation | The artifact the cleanup converts |
|---|---|
| a fix lands far from the feature | an appended correction, folded into the unit it corrects |
| tangled patching | a commit spanning units, split; a unit spread across commits, joined |
| requirements moved | successive implementations, folded to the last |
| record noise | records created and retired inside the branch, removed from the series |
| the pile | `wip:` checkpoints, folded |
| the retraction | a reverted overstep, folded so the series explains only what landed |

## The mapping

One row per property in the convention's table, the check that enforces it, and the gap where none does. The audit's four checks and the primitive's rewrite rules are the left side; the convention's properties are the right.

| Property | Enforced by | Gap |
|---|---|---|
| ordered, no inversion | `scripts/inversions.mjs`, audit check 4 | |
| one unit per commit | audit check 4 (`git log --oneline -- path` counts more than one) | |
| every commit builds | none -- the series is squashed to one delivery commit | **the conflict to state**: which reader the squashed series serves, and which it loses |
| the subject names the change, the body the reason | `scripts/check_commit_message.sh` | |
| a line's origin survives | the rewrite is a rebase, not a filter | not gated |
| no artifact noise | audit's record-path exclusion | check 4 excludes the handover root only (row 767) |
| self-contained and scannable | none | not gated at the branch |
| complete at every point | none | not gated |

Filling the table is the iteration's work; the rows above are the starting read, not the answer. Two entries are already known: the bisect conflict, and the record-path gap that row 767 owns separately.

## Method

Read the primitive and the audit for what they actually check; map each check to a property; then map each property back to a check. Where the mapping is empty on one side, state it in the table rather than reconciling it. Where a property conflicts with the one-delivery-commit rule, state the trade and leave the ruling to the operator.

## Check

The mapping table in the primitive, every row carrying either an enforcing check or a named gap, and the bisect conflict stated. The primitive's trigger and the six situations are stated once. A reviewer re-runs `bash tests/test_history_cleanup_audit.sh` and `bash scripts/lint.sh` and reads the table against them.
