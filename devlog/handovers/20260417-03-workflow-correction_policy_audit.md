# Agent Handover

**Session date:** 2026-04-17
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Workflow
**Status:** Closed

## Objective

Audit and update policy documents to address three workflow violations: process-narrating comments in code output, incorrect handling of bugs found in closed handovers, and missing `[SUPERSEDED]`/`[REMOVED]` tagging discipline for changelog and roadmap entries.

## Scope

Policy changes across five documents:

- `agent_context_brief.md` — ban on process-narrating code comments; closed document correction exception; missing document error rule
- `docs/operations/documentation_policy.md` — unified post-close correction principle and correction forms table
- `docs/operations/handover_policy.md` — corrections to closed handovers procedure
- `docs/development/roadmap_policy.md` — inline tag forms and mandatory Trigger B changelog audit
- `docs/discussions/investigation_policy.md` — corrections to closed investigations; operator deletion model

## Carried forward

None.

## Acceptance criteria

| # | Check | Result |
|---|-------|--------|
| AC-1 | `agent_context_brief.md` bans process-narrating comments in code output | ✅ Accepted |
| AC-2 | `agent_context_brief.md` Handover first principle permits in-place correction exception | ✅ Accepted |
| AC-3 | `agent_context_brief.md` missing document rule flags absent-without-`[REMOVED]` as error | ✅ Accepted |
| AC-4 | `documentation_policy.md` contains unified correction principle with per-document forms table | ✅ Accepted |
| AC-5 | `handover_policy.md` contains closed handover correction procedure | ✅ Accepted |
| AC-6 | `roadmap_policy.md` contains inline tag forms and mandatory Trigger B changelog audit | ✅ Accepted |
| AC-7 | `investigation_policy.md` contains both correction paths and operator deletion model | ✅ Accepted |

## Hot files

| File | Why in scope |
|------|--------------|
| [`agent_context_brief.md`](../../../agent_context_brief.md) | Code comment rule; closed document exception; missing document error rule |
| [`docs/operations/documentation_policy.md`](../../../docs/operations/documentation_policy.md) | Unified post-close correction principle |
| [`docs/operations/handover_policy.md`](../../../docs/operations/handover_policy.md) | Closed handover correction procedure |
| [`docs/development/roadmap_policy.md`](../../../docs/development/roadmap_policy.md) | Inline tag forms; Trigger B changelog audit obligation |
| [`docs/discussions/investigation_policy.md`](../../../docs/discussions/investigation_policy.md) | Investigation correction paths; operator deletion model |

## Decisions made this session

| Decision | Rationale | Where recorded |
|----------|-----------|----------------|
| Unified correction principle in `documentation_policy.md` with per-doc procedure sections | Prevents drift between per-document rules; single canonical source; each policy doc still carries actionable detail at point of use | `documentation_policy.md` |
| Agent never deletes documents; deletion is operator action | Agent marks `[SUPERSEDED]`; operator decides whether to delete and marks referencing links `[REMOVED]` | `investigation_policy.md`, `documentation_policy.md` |
| Absent document without `[REMOVED]` marker is an error, not a question | Ambiguity here is a source-of-truth risk; agent must halt and prompt, not assume | `agent_context_brief.md`, `documentation_policy.md`, `investigation_policy.md` |
| Trigger B now includes mandatory changelog audit | Closing milestone is the only point where the agent has full context to identify superseded claims; deferring creates silent conflicts | `roadmap_policy.md` |

## Completed this session

| File | Change |
|------|--------|
| `agent_context_brief.md` | Added code comment ban to Output Format; amended Handover first to permit correction exception; added Missing Documents section |
| `docs/operations/documentation_policy.md` | Added Post-Close Document Corrections section with unified principle, correction forms table, amendment block format, and missing document rule |
| `docs/operations/handover_policy.md` | Added Corrections to Closed Handovers section |
| `docs/development/roadmap_policy.md` | Added Corrections to Closed Roadmap and Changelog Entries section with inline tag forms and Trigger B obligation |
| `docs/discussions/investigation_policy.md` | Updated Closure section; added Corrections to Closed Investigations section |

## Deferred items

None.

## Next session

**Next sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline (continuing — Change 2)

Context handover: [`20260417-02-impl-worktree_namespaced_checkpoints.md`](20260417-02-impl-worktree_namespaced_checkpoints.md)

Change 2 scope is fully specified — no blocking design questions. Proceed directly to implementation after reading the context handover and confirming scope.

Watch-outs:
- `SESSION_NAME` must be exported to docker-compose for container injection — verify this is not already partially implemented before starting
- Change 2 context frozen in `20260412-02-m2_3_onhold.md`; cross-check against current spec in `design_git_workflow_improvements.md` before writing code
- Trigger B is not pending — milestone is mid-flight
