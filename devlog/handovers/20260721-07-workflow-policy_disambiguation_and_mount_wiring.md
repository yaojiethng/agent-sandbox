# Agent Handover

**Date:** 2026-07-21
**Milestone:** M2.6 — Session Resume and Mount Model Redesign
**Type:** Workflow — policy disambiguation, design policy extraction, mount wiring investigation
**Status:** Closed

## Objective

Close M2.6.3 remaining items (policy file disambiguation, design policy extraction decision) and complete the PROJECT_DIR mount wiring pre-design investigation for M2.6.4.

## Scope

Three units:

**Unit 1 — Policy file disambiguation pass**
- Identify and resolve content overlaps across the 14 files in `docs/operations/`
- Targeted edits to existing files — no restructure, no merges
- Focus areas: `documentation_policy.md` / `handover_policy.md` correction overlap, `iteration_policy.md` / `milestone_policy.md` major loop duplication, `iteration_policy.md` step detail duplication of child policy content

**Unit 2 — Design policy extraction decision**
- Assess whether a standalone design policy document is warranted
- Outcome: either extract a new `design_policy.md` or add a clear ownership anchor in `iteration_policy.md` Step 3

**Unit 3 — PROJECT_DIR mount wiring investigation**
- Trace how `PROJECT_DIR` flows through Makefile, compose template, `start_agent.sh`, config files
- Identify cross-platform path concerns (Linux/macOS/Windows)
- Document findings for the M2.6.4 design session

## Carried forward

| Item | From handover |
|---|---|
| Policy file disambiguation pass (14 operation policy files) — M2.6.3 remaining task | `20260721-06-impl-m2_6_4_apply_draft_unification.md` |
| Design policy extraction — M2.6.3 remaining task | `20260721-06-impl-m2_6_4_apply_draft_unification.md` |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | ADR written encoding declarative policy framing principles | `ls docs/adr/policy_declarative_framing.md` | ✅ Agent |
| 2 | `iteration_policy.md` major loop intro links to `milestone_policy.md` for readiness criteria | `grep -c milestone_policy.md docs/operations/iteration_policy.md` | ✅ Agent |
| 3 | `milestone_policy.md` Stories/Investigations/Roadmap Entry sections pruned to links | `grep -c "story_policy.md\|study_policy.md" docs/operations/milestone_policy.md` | ✅ Agent |
| 4 | `documentation_policy.md` corrections table is link-only, no amendment block format | `grep -c "Amendment block" docs/operations/documentation_policy.md` == 0 | ✅ Agent |
| 5 | `roadmap_policy.md` has a corrections section with `[SUPERSEDED]`/`[REMOVED]` tag rules | `grep -c "Corrections to Closed" docs/operations/roadmap_policy.md` | ✅ Agent |
| 6 | `audit_policy.md`, `bugfix_protocol.md`, `recovery_protocol.md` removed from `docs/operations/` | `ls docs/operations/audit_policy.md` fails | ✅ Agent |
| 7 | Corresponding skill files exist in `src/reasoning/agent/drafts/` | `ls src/reasoning/agent/drafts/audit.skill.md src/reasoning/agent/drafts/bugfix.skill.md src/reasoning/agent/drafts/recovery.skill.md` | ✅ Agent |
| 8 | No stale references to deleted files in live (non-handover) documents | `grep -rn "audit_policy\|bugfix_protocol\|recovery_protocol" . --include="*.md" 2>/dev/null \| grep -v "devlog/handovers/" \| wc -l` == 0 | ✅ Agent |
| 9 | `iteration_policy.md` compaction and carry-forward steps link to `roadmap_policy.md` | `grep -c "roadmap_policy.md" docs/operations/iteration_policy.md` | ✅ Agent |
| 10 | `roadmap_policy.md` "Session close" section stripped of procedural step list, keeps format rules | `grep -c "1. Apply approved" docs/operations/roadmap_policy.md` == 0 | ✅ Agent |
| 11 | `discussion_policy.md` draft status note removed, Designs section expanded with required sections and lifecycle | `grep -c "Status:.*draft" docs/operations/discussion_policy.md` == 0 | ✅ Agent |
| 12 | `iteration_policy.md` Step 1 links to `handover_policy.md` for format, keeps recovery check only | `grep -c "handover_policy.md" docs/operations/iteration_policy.md` >= 3 | ✅ Agent |
| 13 | `iteration_policy.md` Step 5 links to `handover_policy.md` for null marker and AC format | `grep -c "handover_policy.md#acceptance" docs/operations/iteration_policy.md` == 1 | ✅ Agent |
| 14 | `iteration_policy.md` Step 3 Design action links to `discussion_policy.md#designs` | `grep -c "discussion_policy.md#designs" docs/operations/iteration_policy.md` == 1 | ✅ Agent |
| 15 | `AGENTS.md` updated with handover-kept-current rule | `grep -c "Keep the handover current" AGENTS.md` == 1 | ✅ Agent |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/operations/documentation_policy.md`](../../docs/operations/documentation_policy.md) | Largest policy — overlap with handover/roadmap/study corrections; agent-facing docs listing |
| [`docs/operations/handover_policy.md`](../../docs/operations/handover_policy.md) | Correction procedure overlaps with documentation_policy; Related Skills section |
| [`docs/operations/iteration_policy.md`](../../docs/operations/iteration_policy.md) | Major loop duplication with milestone_policy; step detail duplicates child policies |
| [`docs/operations/milestone_policy.md`](../../docs/operations/milestone_policy.md) | Major loop purpose vs iteration_policy's procedural definition |
| [`docs/operations/roadmap_policy.md`](../../docs/operations/roadmap_policy.md) | Post-close bookkeeping described in both iteration_policy and roadmap_policy |
| [`docs/operations/study_policy.md`](../../docs/operations/study_policy.md) | Correction form overlaps with documentation_policy table |
| [`docs/operations/discussion_policy.md`](../../docs/operations/discussion_policy.md) | Deferred consolidation note (stale) |
| [`scripts/templates/Makefile.template`](../../scripts/templates/Makefile.template) | PROJECT_DIR mount wiring — how is PROJECT_DIR specified/used? |
| [`scripts/workflows/start_agent.sh`](../../scripts/workflows/start_agent.sh) | PROJECT_DIR mount wiring — entrypoint for agent startup |
| [`scripts/templates/docker-compose.yml.template`](../../scripts/templates/docker-compose.yml.template) | PROJECT_DIR mount wiring — where volumes and mounts are defined |
| [`scripts/agent-sandbox.sh`](../../scripts/agent-sandbox.sh) | CLI entrypoint — how PROJECT_DIR is accepted and forwarded |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Policy files state rules declaratively, not as design records | One rule one owner; rationale in ADR, not policies | `docs/adr/policy_declarative_framing.md` |
| Major loop purpose/readiness lives in `milestone_policy.md`, procedure in `iteration_policy.md` | Split clean — criteria vs workflow steps | applied in `milestone_policy.md`, `iteration_policy.md` |
| Correction form owned by type-specific policy, not `documentation_policy.md` | One rule one owner | applied in `documentation_policy.md`, `roadmap_policy.md` |
| Audit/bugfix/recovery procedures moved from policies to skill drafts | They self-identified as "not a policy"; pure execution guidance | `audit.skill.md`, `bugfix.skill.md`, `recovery.skill.md` |
| Compaction and escalation rules owned by `roadmap_policy.md`; `iteration_policy.md` links to them | Rule ownership vs procedural workflow | applied in `iteration_policy.md`, `roadmap_policy.md` |

## Mid-session findings

None.

## Completed this session

| File | Change |
|---|---|
| `docs/adr/policy_declarative_framing.md` | **New** — ADR encoding declarative policy framing principles |
| `docs/operations/iteration_policy.md` | Added major loop purpose one-liner linking to `milestone_policy.md`; compaction/carry-forward bullets replaced with links to `roadmap_policy.md`; references table updated for `audit.skill.md` |
| `docs/operations/milestone_policy.md` | Pruned Stories, Investigations, Roadmap Entry sections to links |
| `docs/operations/documentation_policy.md` | Corrections table shrunk to link-only; amendment block format section removed |
| `docs/operations/roadmap_policy.md` | Added "Corrections to Closed Roadmap and Changelog Entries" section; "Session close" stripped of procedural step list, keeps format rules only |
| `docs/operations/audit_policy.md` | **Deleted** — content moved to `audit.skill.md` |
| `docs/operations/bugfix_protocol.md` | **Deleted** — content moved to `bugfix.skill.md` |
| `docs/operations/recovery_protocol.md` | **Deleted** — content moved to `recovery.skill.md` |
| `src/reasoning/agent/drafts/audit.skill.md` | **New** — handover audit procedure |
| `src/reasoning/agent/drafts/bugfix.skill.md` | **New** — bug diagnosis procedure |
| `src/reasoning/agent/drafts/recovery.skill.md` | **New** — recovery workflow |
| `src/reasoning/agent/drafts/roadmap-audit.skill.md` | Updated stale references from `audit_policy.md` to `audit.skill.md` |
| `docs/operations/discussion_policy.md` | Removed draft status note; expanded Designs section with required sections and lifecycle |
| `docs/operations/iteration_policy.md` | Step 1 trimmed to link + recovery check; Step 5 linked to handover_policy.md for null markers; Step 3 Design action links to discussion_policy.md#designs |
| `AGENTS.md` | Added "Keep the handover current" rule under Collaboration Protocol |

## Deferred items

| Item | Reason | Destination |
|---|---|---|
| PROJECT_DIR mount wiring investigation (Unit 3) | Not yet addressed | Later this session or next session |

## Next session

**M2.6.4 — Mount Model Design and Implementation.** M2.6.3 is complete. The next session should be the M2.6.4 design session unless the operator prefers to complete the PROJECT_DIR mount wiring pre-design investigation first.

**Deferred from this session:** PROJECT_DIR mount wiring investigation — how the mount path is specified, cross-platform path correctness. Required pre-design investigation for M2.6.4.

**Conclusions from this session:** Policy files are declarative rules, not design records. Correction forms owned by type-specific policy. Design document format consolidated under `discussion_policy.md#designs`. Three procedural files migrated from `docs/operations/` to skill drafts. Step detail sections that duplicated child policies replaced with links.

**Conclusions from this session:** to be populated at close.
