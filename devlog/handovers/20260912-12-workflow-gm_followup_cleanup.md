# Agent Handover

**Date:** 2026-09-12
**Milestone:** M2.6 - Session Persistence (general-track hygiene)
**Type:** Workflow
**Status:** Closed

## Objective

Apply the operator's five directed cleanups from the gm check-in follow-up: fix the stale gm template example, record that the SERVE_PORT value is arbitrary (withdraw the grep-pin idea permanently), defer SERVE mode indefinitely, consolidate the duplicated WORKTREE_DIR default, and correct the compaction-cascading trigger in roadmap_policy.md.

## Scope

- `workflow/coding-agent/prompts/gm.md` -- replace the stale concrete inventory example with an explicitly illustrative row.
- `scripts/run_agent.sh` -- add the SERVE_PORT arbitrary-selection comment; remove the redundant WORKTREE_DIR re-assignment.
- `docs/operations/roadmap_policy.md` -- broaden the compaction-cascading trigger from "completed in this iteration" to "all children complete", and flip the node heading status on compaction.
- `devlog/roadmap.md` -- move SERVE mode integration to the M2 `Not in scope` bucket; flip the M2.6.6 heading to Complete.
- `devlog/handovers/20260912-11-audit-env_dependence_sweep.md` -- correct the SERVE_PORT pin finding; resolve the WORKTREE_DIR duplication deferral.

## Carried forward

| Item | From handover |
|---|---|
| None. | |

## Acceptance criteria

1. `gm.md` inventory sample row is clearly illustrative, not a live item.
2. `run_agent.sh` SERVE_PORT comment records the arbitrary selection; the WORKTREE_DIR default has a single owner (`session_env.sh`).
3. `roadmap_policy.md` compaction trigger is "For each node whose direct children are all complete".
4. SERVE mode integration is under M2 `Not in scope`, not an open M2.6 item.
5. M2.6.6 heading reads Complete.
6. Test suite green.

## Hot files

| File | Why in scope |
|---|---|
| [`workflow/coding-agent/prompts/gm.md`](../../workflow/coding-agent/prompts/gm.md) | stale example corrected |
| [`scripts/run_agent.sh`](../../scripts/run_agent.sh) | SERVE_PORT comment; WORKTREE_DIR consolidation |
| [`docs/operations/roadmap_policy.md`](../../docs/operations/roadmap_policy.md) | compaction trigger correction |
| [`devlog/roadmap.md`](../roadmap.md) | SERVE deferral; M2.6.6 status flip |
| [`devlog/handovers/20260912-11-audit-env_dependence_sweep.md`](20260912-11-audit-env_dependence_sweep.md) | record corrections |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| SERVE_PORT grep-pin idea withdrawn permanently | the value is arbitrary; any host port works; the pin adds no contract meaning | run_agent.sh comment; handover `20260912-11` correction |
| SERVE mode integration deferred indefinitely | not in regular use; serve overlays untested; pi lacks server-mode support | roadmap M2 `Not in scope` |
| WORKTREE_DIR default consolidated to session_env | start_agent/resume set it before run_agent; the run_agent line was a dead re-assignment in production | run_agent.sh; handover `20260912-11` |
| Compaction trigger broadened to "all children complete" | the single-iteration wording let M2.6.6 stay active despite all rows done; "all complete" already covers close, supersede, and removal | roadmap_policy.md |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Compaction-cascading trigger was scoped to one iteration, so a submilestone whose rows close across iterations never compacts. | bug | roadmap |
| The "all completed in this iteration" and the audit skill's "all complete" triggers disagreed, so the audit (B1/B5) would have flagged what compaction let through. | contradiction | roadmap |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/gm.md` | replaced the stale concrete inventory example with an explicitly illustrative row |
| `scripts/run_agent.sh` | added the SERVE_PORT arbitrary-selection comment; removed the redundant WORKTREE_DIR re-assignment |
| `docs/operations/roadmap_policy.md` | broadened the compaction-cascading trigger to "all children complete"; added the heading-status flip to the compaction step |
| `devlog/roadmap.md` | moved SERVE integration to M2 `Not in scope`; flipped M2.6.6 heading to Complete |
| `devlog/handovers/20260912-11-audit-env_dependence_sweep.md` | corrected the 46553 pin finding to withdraw the grep-pin idea; resolved the WORKTREE_DIR consolidation deferral |

## Deferred items

- The broader "assertions irrelevant to both the precondition and the outcome" pass, named by the operator after this close (the single-iteration clause and the new-iteration recovery phrasing both carry such assertions). Escalated to a new iteration; not deferred here.

## What's Next

M2.6 - Session Persistence (general-track hygiene), next iteration: the "irrelevant assertions" cleanup pass named by the operator.

Blocking design questions the next agent must resolve before advancing:

- Which procedure assertions are irrelevant to both the precondition and the outcome, and can therefore be cut (the compaction trigger, the new-iteration recovery phrasing, and any others found).
- Whether the new-iteration recovery wording ("the prior iteration's close sequence did not complete") mis-stated the cause: M2.6.6's prior closes each completed; the compaction trigger was simply mis-scoped. The recovery text should describe the condition, not a false cause.

Post-close bookkeeping: pending for this iteration's roadmap touches.

**Conclusions from this iteration:** the compaction trigger mismatch was a contradiction between roadmap_policy.md and the roadmap-audit skill (B1/B5), with roadmap_policy the one that let the stale state through.
