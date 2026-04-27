# Agent Handover

**Session date:** 2026-04-27
**Milestone:** M2.3 — Workflow Audit and Policy Refactor
**Session type:** Workflow
**Status:** Active

## Objective

Audit and refactor the policy document system: reduce context overhead at session boot, eliminate duplicate content, establish clean ownership boundaries between policy documents, skill files, and prompt templates, and introduce agent_workflow.md as the authoritative conceptual entry point and policy map.

## Scope

- new-session-v2.md prompt template: inline recovery checks, defer policy reads, use targeted grep
- iteration_policy.md: remove inner diagram, renumber steps, add explicit gates, collapse information gathering pass, restore patch cases
- handover_policy.md: update step number references throughout
- documentation_policy.md: add linking conventions, read pass economics, document depth rules, audit checks; trim Layer Model and Architecture Freeze Policy sections
- project_index.md: add Maintenance Rules section; trim Index Maintenance from iteration_policy and handover_policy
- agent_workflow.md: full rescope as conceptual entry point and policy map

## Carried forward

None.

## Acceptance criteria

Not yet defined.

## Hot files

| File | Why in scope |
|---|---|
| [`docs/operations/iteration_policy.md`](../operations/iteration_policy.md) | Step renumbering, gates, info gathering pass, patch case restoration |
| [`docs/operations/handover_policy.md`](../operations/handover_policy.md) | Step number reference updates |
| [`docs/operations/documentation_policy.md`](../operations/documentation_policy.md) | New conventions, audit checks, trim out-of-scope sections |
| [`docs/development/project_index.md`](../development/project_index.md) | New Maintenance Rules section; agent_workflow entry updated |
| [`docs/concepts/agent_workflow.md`](../concepts/agent_workflow.md) | Full rescope as policy map and conceptual entry point |
| [`docs/architecture/system_overview.md`](../architecture/system_overview.md) | Reference description updated |
| [`docs/architecture/security.md`](../architecture/security.md) | Reversed agent_workflow reference removed |
| [`docs/architecture/execution_model.md`](../architecture/execution_model.md) | agent_workflow reference removed |
| [`docs/architecture/sandbox_lifecycle.md`](../architecture/sandbox_lifecycle.md) | agent_workflow reference removed |
| [`docs/architecture/tool_interface.md`](../architecture/tool_interface.md) | agent_workflow references removed (opening paragraph and References table) |
| [`readme.md`](../../readme.md) | System Invariants links to security.md; agent_workflow.md added to Documentation Guide |
| [`contributors.md`](../../contributors.md) | agent_workflow description updated |
| [`docs/operations/project_onboarding_guide.md`](../operations/project_onboarding_guide.md) | agent_workflow replaced with quickstart.md |
| `docs/skills/user/new-session/new-session-v2.md` | Inlined recovery checks, deferred policy reads, targeted grep |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Inline recovery checks into new-session prompt | Eliminates full iteration_policy read at boot; check logic is self-contained | new-session-v2.md |
| Replace ASCII diagrams with linkable tables | Grants section-level anchor links; minor human readability tradeoff | iteration_policy.md |
| Collapse steps 3–6 into information gathering pass | Steps are a read pass, not confirmation-gated steps; lapses accumulated and surfaced together | iteration_policy.md |
| Add explicit gate rows to minor loop table | Gates were hidden in exit conditions; explicit rows make stopping criteria visible in sequence | iteration_policy.md |
| Renumber minor loop steps fully — no sub-steps | 1b and 7b were amendment artifacts; clean sequential numbering throughout | iteration_policy.md |
| Index Maintenance moves to project_index.md | project_index.md is the canonical owner; policy files link rather than restate | project_index.md |
| Layer Model and Architecture Freeze Policy removed from documentation_policy | System architecture descriptions belong in system_overview.md; documentation-facing freeze rule retained as one sentence | documentation_policy.md, system_overview.md |
| Policy documents vs skill files rules move to agent_workflow.md | Skill files and prompt templates are not documentation; agent_workflow.md owns the three-layer expression model | agent_workflow.md |
| agent_workflow.md rescoped as conceptual entry point and policy map | Document was citing invariants and pointers that lived elsewhere; now maps the full policy system with boundary notes | agent_workflow.md |
| Canonical overlap detection rule lives in documentation_policy; audit-facing version in Audit Checks | Intentional duplication across prescriptive and diagnostic registers; noted explicitly | documentation_policy.md |
| security.md is canonical home for system invariants | readme.md and system_overview.md should link to security.md, not define invariants independently | agent_workflow.md |

## Completed this session

| File | Change summary |
|---|---|
| `new-session-v2.md` | Recovery checks inlined; policy reads deferred and scoped to targeted grep; bold pseudo-headers replaced with `##` headings; step references updated to new numbering |
| `iteration_policy.md` | ASCII diagrams replaced with linkable tables; inner diagram removed; step tags inlined as one sentence; steps renumbered 1–9 with no sub-steps; gates added as explicit rows; steps 3–6 collapsed to information gathering pass with lapse-grouping rules; five patch cases restored; Index Maintenance trimmed to link handoff |
| `handover_policy.md` | All step number references updated (1b→2, 7b→7, Step 6 AC→Step 5, Step 7 impl→Step 6); session types table updated; Index Maintenance trimmed to link handoff |
| `project_index.md` | Maintenance Rules section added with update triggers and temperature table; opening paragraph links to new section; agent_workflow.md entry note updated |
| `documentation_policy.md` | Added: link anchors convention, read pass economics, document depth and verbosity, audit checks section; scope exclusion for skill files and prompt templates made explicit in opening; Layer Model and Architecture Freeze Policy sections removed; freeze rule retained as one sentence under Folder Structure; policy vs skill rules moved to agent_workflow.md |
| `agent_workflow.md` | Full rescope: Core Principles trimmed with links; Core Invariants links to security.md; How the Workflow is Expressed owns three-layer authority model with full rules; Policy Map table with eleven rows, boundary notes, and overlap detection handoff |
| `system_overview.md` | Detailed References agent_workflow description updated |
| `security.md` | Reversed agent_workflow reference removed from opening |
| `readme.md` | System Invariants links to security.md as canonical; agent_workflow.md added to Documentation Guide at step 4 |
| `contributors.md` | agent_workflow description updated to reflect policy map role |
| `execution_model.md` | agent_workflow reference removed from References table |
| `sandbox_lifecycle.md` | agent_workflow reference removed from References table |
| `tool_interface.md` | agent_workflow references removed from opening paragraph and References table |
| `system_overview.md` | Core Invariants links to security.md as canonical source |

## Deferred items

None.

## Next session

Not yet defined
