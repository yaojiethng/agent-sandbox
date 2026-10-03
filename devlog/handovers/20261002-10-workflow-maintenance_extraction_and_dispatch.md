# Handover - The maintenance extraction and dispatch run

**Date:** 2026-10-02
**Milestone:** M3.2.1 - Iteration loops and workflow
**Type:** Workflow
**Status:** Closed

> Backfilled handover. The iteration ran without a record and its number was consumed only as a citation; this file is written during the history rescope from the session log and the commits it cites. Log span: entries 621 to 731 of the session log (`2026-10-01T04-35-20-741Z`, main session file). Claims below carry their entry numbers; narrative-only claims are marked unverified.

## Objective

Extract the maintenance surfaces into runbooks and a dispatch prompt, run the extraction as autonomous worker units in their own worktrees with the primary reviewing and merging, and close the gaps the run surfaced.

## Why

The operator dispatched three units autonomously (entry 621): unit A, the maintenance runbooks and dispatch prompt, subsuming `workflow/coding-agent/audits/roadmap-audit.skill.md` and `handover-audit.skill.md`; unit B, the pi-bump extension follow-up items; unit C, the `/document` runbook draft. Units B and C landed as separate iterations (handovers `20261002-11` and `20261002-12`, recovered later); this iteration owns unit A and the dispatch machinery both waves used.

## Decisions

- Naming convention for the runbooks is `<subject>-maintenance`, so `audit` stays free for review-style payloads. The spelling is "maintenance", matching the 86 files already using it against zero with the misspelling (entries 656, 664-665, operator corrected an accidental misspelling).
- The superseded audit files keep their content and carry a line naming their replacement; removing them is a separate call (entry 707).
- The task-queue dispatch procedure is recorded as a roadmap finding rather than fixed in-flight, with the maintenance dispatch prompt as the interim owner (entry 654, operator direction).

## Changes

| File | Change |
|---|---|
| `workflow/coding-agent/skills/roadmap-maintenance.md` | new runbook subsuming `roadmap-audit.skill.md` |
| `workflow/coding-agent/skills/handover-maintenance.md` | new runbook subsuming both duplicate handover audits |
| `workflow/coding-agent/audits/*.skill.md` | each superseded file names its replacement |
| `workflow/coding-agent/drafts/maintenance.md` | new dispatch prompt; owns the worktree worker procedure as interim owner |
| `workflow/coding-agent/prompts/gm.md` | the survey delegates to the runbooks instead of inlining them |
| `workflow/coding-agent/prompts/wrapup.md` | steps B4 and B8 delegate to the runbooks |
| `scripts/lint/prompt-frontmatter.mjs` | the gate scans `workflow/coding-agent/skills/` |
| `devlog/roadmap.md` | the findings rows and the maintenance-runbook completion row |

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | The runbooks exist and subsume the audit family | entry 672, worker commit `487def3` | pass |
| 2 | The dispatch prompt exists and owns the worker procedure | entry 720, worker commit `4f0e593` | pass |
| 3 | `gm` and `wrapup` delegate instead of inlining | entry 759, worker commit `2f3bfc1` | pass |
| 4 | The frontmatter gate parses the new skills root | entry 690: clean across 36 prompt and skill files (was 34) | pass |
| 5 | Full suite and lint green at close | entries 702, 728: suite 1012 of 1012, lint clean across 4 gates, task-queue 270, model-refresh 157, compat probe clean | pass |

## Findings

- The frontmatter gate did not scan the new `workflow/coding-agent/skills/` root, so the two runbooks were never parsed (entry 673, flagged by the `maintA` worker). Fixed in the same iteration.
- The test-registration guard caught the new compat test file as unregistered in `tests/test_taskq.sh` (entries 692-698). Fixed in the same iteration.
- Three adjacent defects the extraction surfaced are raised, not fixed: the `wrapup.md` B7/B8 label mix, the `doc-wrap` rule never registered under the repository config, and the `gm.md` cosmetic-record rule duplicated (entry 725, from the `extractQ` worker). All three sit on the roadmap.
- The dispatch procedure for worktree workers was not firmed down when the run started; the queue was sound but the procedure was not documented. Recorded as a roadmap row (entry 703).

## Deferred

- Removing the superseded audit files.
- The `/document` convergence runs (unit C2), which became iteration `20261002-15`.

---

[CORRECTION -- 2026-10-03: `workflow/coding-agent/prompts/maintenance.md` is re-pathed to `workflow/coding-agent/drafts/maintenance.md`. The path was correct when the record closed and became stale when the prompt draft gate moved the prompt. No fact changes.]
