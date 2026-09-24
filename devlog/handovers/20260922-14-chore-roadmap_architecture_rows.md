# Agent Handover

**Date:** 2026-09-22
**Milestone:** M3 -- T8 - Documentation (new rows; T4 - Library Migrations row replacement)
**Type:** Housekeeping
**Status:** Closed

## Objective

File the two evidence-kept architecture-concern rows under roadmap T8 and replace the T4 nushell-evaluation row with the bash architecture review.

## Scope

- Roadmap T8 - Documentation gains two rows: the roadmap decision-row format drift (with the test-harness 11-file duplication instance) and the bash-as-implementation-language boundary framing record.
- Roadmap T4 - Library Migrations row `Nushell rewrite evaluation` becomes `Bash "architecture" review (systems / language level)`; nushell is demoted to a nested candidate, not the subject.
- Operator-directed mid-session roadmap add. The operator instruction sets aside the `roadmap_policy.md` timing rule (roadmap touched at iteration end); the rows land now and this handover is the iteration record.

## Carried forward

None.

## Acceptance criteria

- `grep "Roadmap decision-row format drift" devlog/roadmap.md` returns the T8 row.
- `grep "Bash as the implementation language" devlog/roadmap.md` returns the T8 framing row.
- `grep "\*\*Nushell rewrite evaluation\*\*" devlog/roadmap.md` returns nothing (the old task title is gone; the phrase survives only in the replacement row's lineage sentence); the T4 replacement row names nushell only as a nested candidate and retains the `docs/development/host_requirements.md` reference.
- The staged Markdown gate reports zero findings on `devlog/roadmap.md`.

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/roadmap.md`](devlog/roadmap.md) | gains the two T8 rows; the T4 nushell row is replaced |
| [`devlog/handovers/20260922-14-chore-roadmap_architecture_rows.md`](devlog/handovers/20260922-14-chore-roadmap_architecture_rows.md) | this handover, the iteration record |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Claim 1 from the architecture discussion (god entrypoints mirroring) is not written anywhere | reading the two entrypoints refuted it: zero shared functions, asymmetric lifecycle, logic already extracted to libs | retracted in chat during `20260922-14` |
| Claim 2 and the bash-language framing are written as T8 rows, not as M3.1 rows | the operator directed track 8, the Documentation track; the rows are context records for later dealing with the issues | roadmap T8 rows |
| The T4 row is replaced, not tagged `[SUPERSEDED]` | the row is open, not closed; direct rewrite is the right operation for an open task changed by direction | roadmap T4 row |

## Findings

- `docs/development/host_requirements.md` line 73 points at `devlog/roadmap.md`, `#### Not in scope`; no such section exists in the current roadmap. Flagged for the operator; not fixed in this iteration (out of scope)...

---
[CORRECTION -- 2026-09-24: the finding was resolved at iteration end. Commit `bd29209` removed the dangling pointer, so `docs/development/host_requirements.md` no longer references the nonexistent `#### Not in scope` section. Recorded as landed.]

---

## Completed

- [x] Added the two T8 rows in the M3.1 narrative format the operator asked to retain
- [x] Replaced the T4 nushell row with the bash architecture review; nushell demoted to a nested candidate
- [x] Markdown lint gate on `devlog/roadmap.md`: Clean

## Deferred items

None.

## What's Next

The T4 row `Bash "architecture" review (systems / language level)` is the scheduled actionable task; the two T8 rows are the context the review and the format-drift fix will draw on.
