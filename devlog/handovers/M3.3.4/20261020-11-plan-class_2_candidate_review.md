---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Plan
status: Closed
---

# Handover - schedule the class-2 candidate review

## Objective

Give the ten candidates the duplication map flagged a route to a decision, and record the operator's pre-approval to land the accepted ones directly.

## Scope

The roadmap row **The class-2 candidate review**, plus the ordering constraint that pre-approval creates. No candidate is read in this iteration; the row schedules that reading.

Out of scope, with reason: the grill session itself, and the landing. Both belong to the row this iteration writes.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The row names all ten candidates | `grep` the row for each group id in `norm-judgements.tsv` under `candidate:` | Agent [x] |
| The row states the evidence standard | read the row: a named failure or a named carrier set | Agent [x] |
| The row names the two fold candidates and their reading | read the row: `end-a-step-on-a-check` and `define-before-you-use`, with their two skills | Agent [x] |
| The row records the direct-landing approval | read the row: landing is not a draft pass | Agent [x] |
| The row states the ledger consequence of a landing | read the row: a pointer edit changes a hash, so the iteration regenerates and regroups | Agent [x] |
| The row states its order against the filing | read the row: it runs before **The communication-surface filing** | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| One row and one grill session for all ten candidates, not ten iterations | one iteration is one task with one handover; ten sessions ask one question ten times with different subjects | the roadmap row |
| The accepted candidates land together and directly, not as drafts | the operator pre-approved landing at the grill's close | the roadmap row. [CORRECTION -- 2026-10-20] Superseded the same day: one landing per candidate, because each carries propagation edits to the ledger's own sources. See `20261020-12`. |
| Landings run before the filing | a landing converts source lines into pointers and changes their hashes, so the filing's final pass should see settled sources and kinds | the roadmap row |
| A landing is a ledger and grouping operation, not only a file write | editing a source line orphans its row in both `norm-ownership.tsv` and `norm-judgements.tsv`, and both gates fail until the row is regrouped | the roadmap row |
| The two fold candidates are read against existing skills first | a second home for a rule `principle-check-placement` or `attach-as-you-read` already holds is the defect the milestone exists to remove | the roadmap row |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Direct landing changes the ordering I proposed when drafts were the output | consequence of the pre-approval | drafts touch no ledger source, so they could run after the filing; direct landings cannot, so the review now precedes it | the roadmap row |
| A pointer edit silently orphans two ledger rows | mechanism | the review's own gates fail until it regenerates and regroups, so the row states it rather than leaving it to be rediscovered | the roadmap row |

## Completed

| File | Change |
|---|---|
| `devlog/roadmap.md` | new row **The class-2 candidate review**: ten candidates, the evidence standard, the two folds, the direct-landing approval, the ledger consequence, and its order against the filing |
| `devlog/handovers/20261020-11-plan-class_2_candidate_review.md` | this record |
