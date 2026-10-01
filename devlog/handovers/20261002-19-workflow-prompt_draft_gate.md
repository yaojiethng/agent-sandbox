# Handover - The prompt draft gate and the switch-over runbook

**Date:** 2026-10-02
**Milestone:** M3.2.1 - Iteration loops and workflow
**Type:** Workflow
**Status:** Closed

## Objective

Gate prompts that are not operator-reviewed behind a drafts directory, so an unreviewed prompt is structurally unreachable by the dispatch paths that would trust it, and state the switch-over runbook that releases one.

## Problem

The `maintenance` dispatch prompt was written by an autonomous worker unit, landed with agent-only review (lint and worker self-report), and was immediately load-bearing in the session that wrote it; it carried the merge-back procedure that produced the seven `merge:` commits of the failed dispatch run. Nothing distinguished a vetted prompt from an unvetted one, and no procedure existed between writing a prompt and running live work through it. The switch-over to `maintenance.md` was premature (operator, 2026-10-02); it is tallied in the output mount for the rebase-and-fix pass.

## Decisions

1. The durable gate is the location: drafts live in `workflow/coding-agent/drafts/`, a root the prompt-frontmatter gate does not scan (deliberate omission, now commented in the gate script) and live dispatch does not read. The file carries `**Status:** draft` as the human-readable marker; the folder is the gate because include and exclude operate on whole folders.
2. Release from draft status only with explicit operator direction. The release is one commit that moves the file into its live root and runs a documentation pass over it at the same time; the move is the promotion, so no separate promotion step exists to forget.
3. The rule and the runbook are a section in `prompt-authoring-conventions.md`, not a standalone prompt: the runbook is three steps and lives beside the authoring bar it enforces.
4. The `taskq_list` and `taskq_cancel` tools, and the reviewer-counterparty counterpart sentence, ride the plan session's records (`20261002-17`) rather than new rows; the M4.7 tentative workshape definition lands in `roadmap_future.md` in the same commit.

## Changes

| File | Change |
|---|---|
| `workflow/coding-agent/drafts/` (new) | eleven prompts moved in: fanout-run, parallel-work, sequential-work, the five `-run` review templates, auto (the reserved M4 stub), task-queue, maintenance |
| `docs/development/prompt-authoring-conventions.md` | the draft-status and switch-over-gate section |
| `scripts/lint/prompt-frontmatter.mjs` | the drafts root's deliberate exclusion stated |
| eight consumer files | references re-pathed; ADR and iteration-policy mentions carry the draft qualification |
| `devlog/roadmap.md` | the remaining record rows from the plan close |
| `devlog/roadmap_future.md` | the tentative workshape definition under M4.7 |
| `devlog/AGENT_FEEDBACK.md` | the grill-me questioning-discipline recurrence recorded on the 2026-08-18 entry |

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | No unreviewed prompt is reachable from the live prompt roots | `ls workflow/coding-agent/prompts/` holds twelve, none drafted; the drafts folder holds eleven | pass |
| 2 | The frontmatter gate excludes the drafts root | gate scans 27 files (was 38) | pass |
| 3 | Zero stale references to the moved paths | repo-wide sweep of `prompts/<moved>.md` clean | pass |
| 4 | Suite and lint green | run at close: 1012 of 1012, lint clean across 4 gates | pass |

## Findings

- `parallel-work.md`, `sequential-work.md`, `adversarial-review-run.md` and `review-loop-run.md` already carried `Draft -` in their descriptions; `fanout-run.md` carried `**Status:** draft`. The move formalizes what those markers stated but did not enforce.
- `churn-analysis-run.md`, `read-through-run.md`, `review-pass-run.md` and `test-quality-campaign-run.md` carried no draft marker; they move by the operator's explicit list, which is the review the rule requires.
