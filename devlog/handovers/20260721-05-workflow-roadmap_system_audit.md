# Agent Handover

**Session date:** 2026-07-21
**Milestone:** M2.6 — Session Resume and Mount Model Redesign
**Session type:** Workflow — Roadmap system audit and cleanup
**Status:** Closed

## Objective

Audit and reset the roadmap to a working baseline. Replace the ad-hoc phase system with a fractal sub-milestone numbering scheme. Retroactively renumber M2.6's phases as M2.6.1–M2.6.4 across all handovers. Patch `roadmap_policy.md` with post-close bookkeeping (replacing Trigger A/B), pre-session status promotion check, and fractal numbering rules. Add frontmatter to `roadmap.md`. Update `whats-next.md` to use reliable sources. Collapse the milestone summary table. Clean up stale Trigger A/B and Phase references across live docs.

## Scope

1. **Roadmap audit and cleanup** — aligned summary table, compacted completed M2.6.1 and M2.6.2, updated M2.6.3 remaining items.
2. **Fractal numbering retrofit M2.6** — Phase 1→M2.6.1, Phase 1.5→M2.6.2, Phase 1.6→M2.6.3, Phase 2→M2.6.4 in roadmap.md. 10 handover files renamed. All internal refs updated.
3. **roadmap_policy.md patches** — fractal numbering system, post-close bookkeeping (compaction cascading, summary table update, top-level milestone close), pre-session status promotion check.
4. **roadmap.md frontmatter** — `active-milestone` and `active-milestone-status` fields.
5. **Milestone summary table** — collapsed to nested indented format with changelog section anchors.
6. **whats-next.md update** — replaced `head -80` with frontmatter-aware grep.
7. **Trigger A/B → bookkeeping** — absorbed Trigger A into top-level milestone close; all references in iteration_policy, handover_policy, milestone_policy, agent_workflow, documentation_policy, wrapup.md, new-session.md, claude-ai AGENTS.md, eval tests updated.
8. **Stale naming cleanup** — Phase 1.5→M2.6.2 in sandbox_lifecycle.md, Phase 2→M2.6.4 in story_agent_state_persistence.md, security_delta_worktree_model.md, dry_run_capability.sh.
9. **Discussion doc renames** — 4 docs renamed to YYYYMMDD-type-status-description.md format per discussion_policy.md.
10. **Propagation discipline** — AGENTS.md updated with scope-expansion trigger.

## Completed this session

| File | Change |
|---|---|
| `devlog/roadmap.md` | Frontmatter, collapsed summary table, fractal renumbering M2.6.1–M2.6.4, compaction |
| `docs/operations/roadmap_policy.md` | Fractal numbering, post-close bookkeeping, top-level milestone close, pre-session promotion check |
| `docs/operations/iteration_policy.md` | Trigger A/B→bookkeeping, recovery check updated |
| `docs/operations/handover_policy.md` | Trigger B→bookkeeping in 3 locations |
| `docs/operations/milestone_policy.md` | Trigger A→top-level milestone close |
| `docs/operations/documentation_policy.md` | Trigger B cleanup→post-close bookkeeping cleanup |
| `docs/concepts/agent_workflow.md` | Trigger A/B→post-close bookkeeping |
| `docs/architecture/sandbox_lifecycle.md` | Phase 1.5→M2.6.2 |
| `docs/adr/sandbox_delivery_model.md` | Phase 1.5→M2.6.2 |
| `AGENTS.md` | Propagation discipline scope-expansion trigger added |
| `src/reasoning/agent/prompts/whats-next.md` | Replaced head -80 with frontmatter-aware active milestone grep |
| `src/reasoning/agent/prompts/new-session.md` | Trigger B→post-close bookkeeping |
| `src/reasoning/agent/prompts/wrapup.md` | Trigger B→post-close bookkeeping |
| `src/reasoning/agent/drafts/roadmap-management.skill.md` | Trigger A/B→sub-milestone/top-level close; removed stale combine constraint |
| `src/reasoning/providers/claude-ai/AGENTS.md` | Trigger B→post-close bookkeeping |
| `tests/eval/eval_new_session.sh` | Invariant checks updated to bookkeeping terminology |
| `tests/eval/eval_protocol.md` | Example invariant updated |
| `scripts/dry_run_capability.sh` | Phase 2→M2.6.4 in comment |
| `devlog/discussions/story_agent_state_persistence.md` | Renamed to 20260522-story-settled-agent_state_persistence.md |
| `devlog/discussions/20260622-study-settled-security_delta_worktree_model.md` | Renamed from security_delta_worktree_model.md; Phase 2→M2.6.4 |
| `devlog/discussions/20260522-story-active-prompt_eval_infrastructure.md` | Renamed from story_prompt_evals.md; Trigger B→bookkeeping |
| `devlog/discussions/20260428-story-active-sequencing_and_knowledge_persistence.md` | Renamed from story_sequencing_and_knowledge_persistence.md; Trigger B→bookkeeping |
| 10 handover files (M2.6 phase handovers) | Renamed to m2_6_1, m2_6_2, m2_6_3, m2_6_4 prefixes; internal refs updated |

## Deferred items

| Item | Destination |
|---|---|
| Policy file disambiguation pass (14 operation policy files) | M2.6.3 remaining task |
| Design policy extraction | M2.6.3 remaining task |

## Next session

**M2.6.4 — Mount Model Design and Implementation** is the next target. Requires a design session. Pre-design investigations needed: PROJECT_DIR mount wiring, make apply/draft unification. M2.6.3 still has two open items (policy disambiguation, design policy extraction) that could be picked up first if preferred.
