---
date: 2026-11-14
milestone: M3.7.2 - The change model and its refinements
type: Workflow
status: Closed
---

# Handover - The message budgets are substantiated

## Objective

State what each commit-message budget buys and on what basis, and keep, change or drop each number against it.

## Scope

Continues the parent row *The convention leads from history as a commons and owns the primitives* in M3.7.2, from the records [`20261114-01`](20261114-01-workflow-git_discipline_commons.md), [`20261114-02`](20261114-02-design-git_discipline_reframe.md) and [`20261114-03`](20261114-03-impl-commit_message_check.md).

One row: *The message budgets are substantiated against review cost*. The row's premise -- that the 50/72 and 280 budgets came from Tim Pope's 2008 note whose basis was terminal width -- is itself the first thing to check, because the note gives 50 for the subject and 72 for the body wrap, not 72 for the subject.

The body's unit is a second defect inside the same table cell: the convention says *one sentence*, the ADR says *one paragraph*. It is corrected here, because a criterion about the budget cannot be satisfied while its unit is contradicted.

Out of scope: any change to the enforced numbers, and so any change to `scripts/check_commit_message.sh`. The row's bar is that each number is substantiated or amended, and the measurement supports all three.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The ADR states each number's provenance and what it buys: 50 from Pope's subject advice, 72 reused from Pope's body wrap as the display ceiling, 280 the project's own paragraph bound. | Read the entry; all three present. | Agent [x] |
| The ADR names the review-cost sources' subject, the diff, and states that none derives a message-length number. | Read the entry; the boundary sentence present. | Agent [x] |
| The numbers are unchanged, so the check needs no change: all 9 cases pass. | `bash tests/test_commit_message_check.sh` | Agent [x] |
| The body's unit reads *one paragraph* in the convention and the ADR, and *one sentence* is gone. | `grep -c 'one sentence' .agents/skills/git-discipline/SKILL.md` returns 0 | Agent [x] |
| The convention's subject row and the ADR agree: 72 at most, targeting 50. | grep both files for the two numbers in the same sentence | Agent [x] |
| The roadmap row closes with its outcome, and the measurement leaves the row for the ADR. | `git diff HEAD -- devlog/roadmap.md` at pre-close | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The basis is provenance plus the corpus distribution, not review cost. | The review-cost sources bound how much diff a reviewer reads; a message is read once, in a glance, and no source maps a review rate to characters of prose. | the ADR entry |
| 50 keeps, as the centre rather than a ceiling. | The corpus median subject is 48, so the target names where the distribution already sits; 39% miss it and that is the miss the target exists to pull. | the ADR entry |
| 72 keeps, and its arithmetic is stated honestly. | The `--oneline` prefix is 8 characters here, so a 72-character subject makes an 81-column line; the ceiling fits a seven-character sha, and a one-column overrun is accepted rather than tightening a number the world shares. | the ADR entry |
| 280 keeps. | Four 72-column lines are 288, and the p90 body is 263, so 280 leaves nine bodies in ten intact. | the ADR entry |
| The body's unit is one paragraph. | A paragraph is the reading unit the number bounds; *one sentence* is a second unit the check cannot hold and the corpus contradicts. | the ADR entry and the convention's table |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The 50/72 provenance is wrong: Pope's note gives 50 for the subject and 72 for the body wrap, so 72 was reused as a subject ceiling rather than inherited as one. | record | the row's premise | the ADR entry |
| The body's unit is contradicted: the convention says *one sentence*, the ADR says *one paragraph*. | record | a criterion cannot be satisfied against two units | this iteration |
| `roadmap-maintenance` 3.13: the budgets row carries the measurement's percentages, which go stale. | record | a number in a row is true once | this iteration's close, by compacting the row |
| The operator asked whether the review sources' diff bound becomes a size suggestion for one unit of work, gated or advisory. | design | the unit has no definition beyond "a coherent change" | `devlog/roadmap_future.md`, deferred |

## Completed

| File | One-line change summary |
|---|---|
| `docs/adr/git_commit_history_commons.md` | a second entry: each number's basis, the measurement, and the review-cost boundary |
| `.agents/skills/git-discipline/SKILL.md` | the body's unit reads one paragraph |
| `devlog/roadmap.md` | the row closes, compacted to its outcome |
| `devlog/roadmap_future.md` | a deferred size suggestion for one unit of work, from the operator's aside |
| (maintenance) | `roadmap-maintenance`: 1 finding (3.13 above), 11 checks with none, 4 skips (no compaction in flight, changelog not edited this run). |
