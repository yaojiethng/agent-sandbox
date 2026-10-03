# Handover - The documentation-session runbook

**Date:** 2026-10-02
**Milestone:** M3.2.1 - Iteration loops and workflow
**Type:** Documentation
**Status:** Closed

> Backfilled handover. The iteration ran as worker unit `docC` in the first fan-out wave and landed without a record; this file is written during the history rescope from the session log and the worker's brief. Log span: entries 621, 667, and 674 to 707 of the session log (`2026-10-01T04-35-20-741Z`, main session file). Claims carry their entry numbers.

## Objective

Turn `workflow/coding-agent/prompts/document.md` from a braindump into a real runbook prompt for the documentation session.

## Why

Unit C of the operator's three-unit dispatch (entry 621). The `/document` prompt was a braindump; a real runbook is the precondition for the review campaign that followed (iteration `20261002-15`) and for the per-prompt quality pass the operator named as the human review gate.

## Decisions

- The runbook defers to the policy documents by link rather than restating them; where the braindump was vague, the runbook defers instead of inventing policy (worker brief, entry 667).
- Stated non-goal: this is not the runnable document-maintenance sweep, which does not exist yet and is a separate roadmap task (entry 667).
- The frontmatter description must parse: quoted when it contains a colon-space, a leading dash, or a trailing colon (entry 667).

## Changes

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/document.md` | rewritten in place as a runbook: frontmatter, purpose, when to run and when not, ordered procedure with completion criteria, output shape, non-goals, failure modes and invariants |

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | The prompt parses under the frontmatter gate | entries 680, 690: gate clean across 36 prompt and skill files | pass |
| 2 | Lint clean in the worker worktree after the brief was removed | entries 678-680 | pass |
| 3 | The runbook carries the braindump's real content, especially the acceptance-criteria treatment for documentation work and the per-prompt quality pass idea | worker commit `a8c9422`, 132 insertions | pass |

## Findings

- The review campaign's roadmap row for the per-prompt quality pass was initially missing; it was added in the second wave's close (entries 711-713, 725) rather than in this iteration.
- The primary's `.brief.md` file inside the worker worktree failed markdownlint (MD041) and briefly read as a worker defect; the brief was the cause (entries 678-680). The dispatch briefs are kept out of lint scope in later runs.

## Deferred

- The `/document` convergence runs, which became iteration `20261002-15`.
- The per-prompt quality pass for `/document`, a roadmap row pending the human review.
