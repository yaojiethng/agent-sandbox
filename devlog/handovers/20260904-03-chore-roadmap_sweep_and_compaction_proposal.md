# Agent Handover

**Date:** 2026-09-04
**Milestone:** M2.6 - Session Persistence
**Type:** Housekeeping
**Status:** Closed

## Objective

Sweep `devlog/roadmap.md` for tasks whose marker no longer matches reality, and compact the completed-task inventory per the operator's compaction discipline: bugfixes, completed chores, and superseded/undone changes fall off; completed items are described abstractly (contracts, interfaces, invariants); related points merge; reordering is allowed to consolidate; a checked task must never carry a partial-completion state tag - split the complete and incomplete portions instead, and never compromise the record of incomplete tasks.

## Scope

Roadmap maintenance on the M2.6 section only: (a) status sweep of every open item, verified against the tree; (b) compaction of the completed inventory (general cross-cutting track, M2.6.1-M2.6.5, M2.6.6); (c) open entries preserved verbatim; (d) mount-delivery entry split into a checked wiring entry + an open runnability entry (no partial-completion tag on `- [x]`); (e) handover renumbered to `20260904-03` (collision with the operator's `20260904-01-design`). No code or test changes.

## Carried forward

| Item | From handover |
|---|---|
| Seed transport fix (strip `.agent-sandbox-seed/` pollution) | `20260903-01` - **resolved on roadmap**: superseded by the helper-container seed redesign (`20260904-01-design`), tracked as the open "Seed transport redesign" entry |

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| AC1 | Sweep report: every open roadmap item verified against the tree; mislabels identified | accepted |
| AC2 | Completed inventory compacted per the operator discipline (bugfixes/chores/superseded removed; contracts, interfaces, invariants; related points merged; reordering used) | accepted |
| AC3 | No `- [x]` carries a partial-completion tag; partial work split into checked + open portions | accepted |
| AC4 | Open entries preserved byte-for-byte; no stale internal references; no code or test changes | accepted |
| AC5 | Handover renumbered to `20260904-03`; compaction-discipline Finding recorded | accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/roadmap.md`](../devlog/roadmap.md) | Sweep + compaction target |
| [`devlog/handovers/20260904-03-chore-roadmap_sweep_and_compaction_proposal.md`](../devlog/handovers/20260904-03-chore-roadmap_sweep_and_compaction_proposal.md) | This handover (renumbered) |

## Decisions

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| Compaction discipline (operator directive 2026-09-04): narrow what deserves a checked task - bugfixes fall off, completed chores fall off, superseded/undone changes fall off (only the final change is preserved); completed items are described at contract/interface/invariant level; related points merge; reordering is allowed to consolidate. A `- [x]` must never carry a partial-completion state tag - split into a checked complete portion + an open incomplete portion; the record of incomplete tasks is never compromised. Candidate follow-up: codify both rules in the `roadmap_policy.md` compaction section. | steering | current iteration + roadmap_policy follow-up |
| All 8 open items verified genuinely open. The probe-layer task is ~95% complete - the three named probes (`_env_field_probe`, `_template_version_probe`, `_wsl_path_probe`) are deleted and tests source the guarded scripts directly, but `template_version_probe_real()` in `tests/test_onboard.sh` remains a bounded sed-extraction probe (redundant since `onboard.sh` is sourced); open portion preserved, unchanged. | bug (stale marker) | next iteration (small impl) |
| `20260903-01-debug` handover still marked Open although superseded by `20260904-01-design`; `20260904-01-design` itself is marked Open in-file while `20260904-02` references it as Closed. **Operator resolved (2026-09-04): fixed manually by the operator - not touched by this iteration.** | contradiction | operator |
| The old `resume session surfaces` entry's stale "Remaining: D11 wizard" note (wizard delivered `20260821-06`) dropped during compaction. | scope change | current iteration |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../devlog/roadmap.md) | M2.6 completed inventory compacted from ~55 checklist entries to 15 `- [x]` (8 general-track contracts + 5 sub-milestone summaries + 2 M2.6.6 entries) + 1 decision line; 9 open entries (8 preserved verbatim + mount-delivery runnability split out); roadmap file 288 -> 166 lines |
| [`devlog/handovers/20260904-03-chore-roadmap_sweep_and_compaction_proposal.md`](../devlog/handovers/20260904-03-chore-roadmap_sweep_and_compaction_proposal.md) | Renumbered from `20260904-01-chore`; content rewritten for this iteration |

## Deferred items

None.

## What's Next

M2.6 - Session Persistence. Next per the open inventory: probe-layer residual deletion (`template_version_probe_real`), then the seed transport redesign impl.

**Conclusions from this iteration:** general-track ~30 completed entries -> 8 abstract contract-level entries; M2.6.1-2.6.5 condensed to one line each; M2.6.6 to 2 completed + 1 open. No mislabelled open items beyond the probe-layer near-done case; the open task record is uncompromised and verbatim.