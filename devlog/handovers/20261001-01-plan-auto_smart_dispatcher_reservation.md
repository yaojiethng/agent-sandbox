# Agent Handover

**Date:** 2026-10-01
**Milestone:** M3.2.3 - Dispatch Workflows as a Command Surface
**Type:** Plan
**Status:** Closed

## Objective

Change `/auto` from the sequential autopilot into a reserved smart dispatcher and seed the M3.2.3 sub-milestone that owns the dispatch shapes. Free the `/auto` keyword for the M4 smart dispatcher by renaming the sequential shape, create a fail-closed `/auto` stub, record the semantics in a design-settled record and the ADR, and scope the M4 `/auto` and `/goal` rows.

## Scope

- `devlog/roadmap.md` - seed M3.2.3; move the `/auto` primitive-generalization consideration into M3.2.3 as a resolved follow-on; rename live dispatch references.
- `devlog/roadmap_future.md` - M4.6 renamed to Background Work; add M4.7 `/auto` smart dispatcher and M4.8 `/goal`.
- `workflow/coding-agent/drafts/auto.md` - replaced by a reserved smart-dispatcher stub; the sequential content moved to `sequential-work.md`.
- `workflow/coding-agent/drafts/sequential-work.md` - the renamed sequential dispatch shape (was `auto.md`).
- `workflow/coding-agent/drafts/parallel-work.md` - the renamed concurrent-track shape (was `parallel-auto.md`).
- `docs/adr/coding_agent_loop_workflow.md` - 2026-10-01 decision entry; taxonomy table updated (`-work` family under M3.2.3; `/auto` and `/goal` under M4).
- `docs/concepts/autonomous_agent_loop.md`, `docs/operations/iteration_policy.md`, `docs/development/prompt-authoring-conventions.md`, `workflow/coding-agent/drafts/task-queue.md`, `workflow/coding-agent/prompts/wrapup.md`, `workflow/coding-agent/audits/surface-area-report.md`, `docs/adr/task_queue_primitive.md` - live reference propagation.
- `devlog/discussions/20261001-design-settled-auto_smart_dispatch.md` - the semantics record.
- `devlog/AGENT_FEEDBACK.md` - two entries: the roadmap-durable-record finding and the doc-wrap-gate recurrence.

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `/auto` becomes a smart dispatcher (Option A): resolve order, pick shape, orchestrate; reads a provided decomposition | the M4 dispatcher takes a roadmap task list and resolves its execution order and shape; it does not derive a decomposition from a loose goal | design record + ADR 2026-10-01 |
| The sequential autopilot is renamed `/sequential-work`; `/parallel-auto` becomes `/parallel-work`; the `-work` suffix is temporary, removed at M3.2.3 close | frees the `/auto` keyword; `-work` names the dispatch-command family the way `-run` names the one-shot operations; suffix marks pending-final-naming | ADR 2026-10-01 rejected alternatives |
| `/goal` (Option B, loose-goal decomposition) is M4's, reworked from the removed stale external extension | Option A and Option B are distinct; `/goal` decomposes a loose goal into units itself | roadmap_future M4.8 + design record |
| M3.2.3 owns the `/iter` work-loop expansions from hereon; the loop taxonomy proper stays M3.2.1's | the dispatch shapes leave M3.2.1; the four loops do not | M3.2.3 section + ADR |
| The `/auto` stub fails closed until M4 | no guessing a shape the dispatcher cannot yet handle; routes a single well-ordered list to `/sequential-work` | `auto.md` stub + design record |
| The roadmap's closed rows are not the durable record; the handover is. Closed rows may be swept / moved within the active milestone as the semantics shift | the changelog records what landed per milestone; rewriting live current-semantics references does not falsify history | AGENT_FEEDBACK `[O]` 2026-10-01 |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | M3.2.3 exists with a summary row and section; `/auto`-generalization consideration moved to it as a done follow-on | `grep -n` in `devlog/roadmap.md` | done |
| 2 | `auto.md` is a reserved smart-dispatcher stub; the sequential content is in `sequential-work.md`; `parallel-auto.md` is `parallel-work.md` | `ls workflow/coding-agent/prompts/` | done |
| 3 | M3.2.1/M3 closed rows are left where they are (not M3.2.3-scoped); their live file references updated | `grep -n "parallel-auto\|auto\.md"` over live surfaces | done |
| 4 | M4.7 `/auto` and M4.8 `/goal` rows exist in roadmap_future | `grep -n` in `devlog/roadmap_future.md` | done |
| 5 | ADR and design record fix the ownership split and the `/auto`/`/goal` M4 assignment | `grep -n` the ADR + design record | done |
| 6 | Markdown + shell lint gates clean | `scripts/lint.sh` | done |

## Completed

| File | Change | Status |
|---|---|---|
| `devlog/roadmap.md` | M3.2.3 seeded; consideration moved as resolved follow-on; live refs renamed | done |
| `devlog/roadmap_future.md` | M4.6 renaming; M4.7 `/auto`; M4.8 `/goal` | done |
| `workflow/coding-agent/drafts/auto.md` | reserved smart-dispatcher stub | done |
| `workflow/coding-agent/drafts/sequential-work.md` | renamed sequential dispatch shape | done |
| `workflow/coding-agent/drafts/parallel-work.md` | renamed concurrent-track shape | done |
| `docs/adr/coding_agent_loop_workflow.md` | 2026-10-01 decision + taxonomy table | done |
| `docs/adr/task_queue_primitive.md` | parallel-work naming in rationale | done |
| `docs/concepts/autonomous_agent_loop.md` | work-loop expansions; `/auto`,`/goal` to M4 | done |
| `docs/operations/iteration_policy.md` | links to sequential-work / parallel-work | done |
| `docs/development/prompt-authoring-conventions.md` | work-style family named | done |
| `workflow/coding-agent/drafts/task-queue.md` | sequential-work / parallel-work refs | done |
| `workflow/coding-agent/prompts/wrapup.md` | sequential-work / parallel-work | done |
| `workflow/coding-agent/audits/surface-area-report.md` | `/auto` row to `/sequential-work` | done |
| `devlog/discussions/20261001-design-settled-auto_smart_dispatch.md` | semantics record | done |
| `devlog/AGENT_FEEDBACK.md` | `[O]` roadmap-durable-record; `[A]` doc-wrap recurrence | done |

## Deferred items

- The M4 `/auto` smart-dispatcher implementation and the M4 `/goal` loose-goal decomposition (M4 rows).
- The M4.6 background-work prompt build.
- The `-work` suffix final-naming decision and removal (M3.2.3 close).
- The doc-wrap lint-gate gap: the rule is enabled but does not fire on hard-wrapped prose (AGENT_FEEDBACK `[A]` 2026-10-01).

## What's Next

M3.2.3 is now in progress with its first task landed. The remaining M3.2.3 work is the `-work` family refinement and the suffix-removal decision at close, which depends on the M4 `/auto` final naming. The historical M3.2.1/M3 closed rows that reference the old names were left in place per the operator's fallback; the live current-semantics surface is fully updated. The next relevant audit item is the doc-wrap gate gap surfaced in AGENT_FEEDBACK.

---

[CORRECTION -- 2026-10-03: the moved prompt paths in this record are re-pathed to `workflow/coding-agent/drafts/` (`auto.md`, `sequential-work.md`, `parallel-work.md`, `task-queue.md`). They were under `workflow/coding-agent/prompts/` and `src/reasoning/agent/prompts/` when the record closed, and became stale when the prompt draft gate moved them. No fact changes.]
